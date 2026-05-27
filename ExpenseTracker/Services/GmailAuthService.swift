// GmailAuthService.swift
// Responsibility: Full Gmail OAuth 2.0 lifecycle — initial sign-in via
//                 ASWebAuthenticationSession, auth-code-for-token exchange,
//                 encrypted Keychain storage, and silent token refresh before
//                 every API call. The only class that ever touches raw tokens.
// Depends on: AuthenticationServices, KeychainHelper, Constants, Foundation
// Used by: ExpenseTrackerApp (launch auth check, inject as @StateObject),
//          GmailFetchService (calls validAccessToken() before each request),
//          SettingsView (reads connectedEmail, calls signOut())

import Foundation
import AuthenticationServices

@MainActor
class GmailAuthService: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var connectedEmail: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Held strongly so the session is not released while Safari is open.
    private var authSession: ASWebAuthenticationSession?

    // ISO 8601 formatter used to persist the token expiry Date as a Keychain string.
    // ISO8601DateFormatter is thread-safe per Apple docs.
    private static let isoFormatter = ISO8601DateFormatter()

    // MARK: - Public API

    // Called once from AppRootView.task on every launch.
    // Does NOT refresh the token — that happens lazily in validAccessToken() before
    // the first Gmail API call, avoiding a blocking network call at startup.
    func checkExistingAuth() {
        let hasAccess  = KeychainHelper.read(forKey: Constants.Keychain.accessTokenKey)  != nil
        let hasRefresh = KeychainHelper.read(forKey: Constants.Keychain.refreshTokenKey) != nil
        isAuthenticated = hasAccess && hasRefresh
        connectedEmail  = KeychainHelper.read(forKey: Constants.Keychain.emailKey)
    }

    // Opens Google's OAuth consent page in an in-app Safari sheet.
    // On success, exchanges the auth code for tokens and persists them to Keychain.
    func signIn() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Random state token prevents CSRF — verified when the callback URL arrives.
        let state = UUID().uuidString

        var components = URLComponents(string: Constants.Gmail.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id",      value: Constants.Gmail.clientID),
            URLQueryItem(name: "redirect_uri",   value: Constants.Gmail.redirectURI),
            URLQueryItem(name: "response_type",  value: "code"),
            URLQueryItem(name: "scope",          value: Constants.Gmail.scope),
            URLQueryItem(name: "access_type",    value: "offline"),
            // prompt=consent forces Google to return a refresh_token on every sign-in.
            URLQueryItem(name: "prompt",         value: "consent"),
            URLQueryItem(name: "state",          value: state),
        ]

        guard let authURL = components.url else { throw AuthError.invalidCallbackURL }

        // Bridge the callback-based ASWebAuthenticationSession to async/await.
        // defer cleans up the stored session reference after the continuation resumes.
        defer { authSession = nil }
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Constants.Gmail.redirectScheme
            ) { url, error in
                if let error { continuation.resume(throwing: error); return }
                guard let url else { continuation.resume(throwing: AuthError.invalidCallbackURL); return }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            // Ephemeral session means Safari won't pre-fill the Google account —
            // important for ensuring prompt=consent fires every time.
            session.prefersEphemeralWebBrowserSession = true
            authSession = session
            session.start()
        }

        // Validate the callback URL and extract the auth code.
        guard
            let cbComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let code          = cbComponents.queryItems?.first(where: { $0.name == "code"  })?.value,
            let returnedState = cbComponents.queryItems?.first(where: { $0.name == "state" })?.value
        else { throw AuthError.invalidCallbackURL }

        guard returnedState == state else { throw AuthError.stateMismatch }

        try await exchangeCodeForTokens(code: code)
    }

    // The single entry point that all API callers use to obtain a usable token.
    // Returns the cached access token if it has more than 60 s of remaining lifetime;
    // otherwise silently refreshes it first.
    func validAccessToken() async throws -> String {
        guard
            let token   = KeychainHelper.read(forKey: Constants.Keychain.accessTokenKey),
            KeychainHelper.read(forKey: Constants.Keychain.refreshTokenKey) != nil
        else { throw AuthError.notSignedIn }

        // Token is fresh enough — return it without a network call.
        if let expiryString = KeychainHelper.read(forKey: Constants.Keychain.tokenExpiryKey),
           let expiry = Self.isoFormatter.date(from: expiryString),
           expiry > Date.now.addingTimeInterval(60) {
            return token
        }

        try await refreshAccessToken()

        guard let freshToken = KeychainHelper.read(forKey: Constants.Keychain.accessTokenKey)
        else { throw AuthError.notSignedIn }
        return freshToken
    }

    // Removes all stored credentials and resets published state.
    // Called from SettingsView when the user taps "Disconnect Gmail".
    func signOut() {
        KeychainHelper.delete(forKey: Constants.Keychain.accessTokenKey)
        KeychainHelper.delete(forKey: Constants.Keychain.refreshTokenKey)
        KeychainHelper.delete(forKey: Constants.Keychain.tokenExpiryKey)
        KeychainHelper.delete(forKey: Constants.Keychain.emailKey)
        isAuthenticated = false
        connectedEmail  = nil
    }

    // MARK: - Private helpers

    // Exchanges an OAuth authorization code for an access + refresh token pair.
    private func exchangeCodeForTokens(code: String) async throws {
        let body = formEncode([
            "grant_type":   "authorization_code",
            "code":         code,
            "client_id":    Constants.Gmail.clientID,
            "redirect_uri": Constants.Gmail.redirectURI,
        ])

        let data = try await postForm(to: Constants.Gmail.tokenEndpoint, body: body)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        guard let refreshToken = response.refresh_token else {
            throw AuthError.tokenExchangeFailed(
                "No refresh_token in response — ensure prompt=consent is set in the auth URL"
            )
        }

        saveTokens(
            accessToken:  response.access_token,
            refreshToken: refreshToken,
            expiresIn:    response.expires_in
        )

        try await fetchUserEmail(accessToken: response.access_token)
        isAuthenticated = true
    }

    // Uses the stored refresh token to get a new access token without user interaction.
    // Only overwrites access_token and expiry — the refresh_token is left untouched.
    private func refreshAccessToken() async throws {
        guard let refreshToken = KeychainHelper.read(forKey: Constants.Keychain.refreshTokenKey)
        else { throw AuthError.notSignedIn }

        let body = formEncode([
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     Constants.Gmail.clientID,
        ])

        let data     = try await postForm(to: Constants.Gmail.tokenEndpoint, body: body)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        let expiry = Date.now.addingTimeInterval(TimeInterval(response.expires_in))
        KeychainHelper.save(response.access_token,              forKey: Constants.Keychain.accessTokenKey)
        KeychainHelper.save(Self.isoFormatter.string(from: expiry), forKey: Constants.Keychain.tokenExpiryKey)
    }

    // Fetches the Google account email via the Gmail profile endpoint.
    // Uses /gmail/v1/users/me/profile instead of the OAuth userinfo endpoint because
    // we only request gmail.readonly scope — userinfo requires an additional email scope.
    private func fetchUserEmail(accessToken: String) async throws {
        guard let url = URL(string: "\(Constants.Gmail.baseURL)/users/me/profile") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try assertHTTP2xx(response, data: data)

        struct GmailProfile: Decodable { let emailAddress: String }
        let profile = try JSONDecoder().decode(GmailProfile.self, from: data)

        KeychainHelper.save(profile.emailAddress, forKey: Constants.Keychain.emailKey)
        connectedEmail = profile.emailAddress
    }

    // Persists access token, refresh token, and computed expiry date to Keychain.
    private func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) {
        let expiry = Date.now.addingTimeInterval(TimeInterval(expiresIn))
        KeychainHelper.save(accessToken,                            forKey: Constants.Keychain.accessTokenKey)
        KeychainHelper.save(refreshToken,                           forKey: Constants.Keychain.refreshTokenKey)
        KeychainHelper.save(Self.isoFormatter.string(from: expiry), forKey: Constants.Keychain.tokenExpiryKey)
    }

    // POSTs a form-encoded body string and returns the response Data.
    // Throws on non-2xx status codes with a descriptive message.
    private func postForm(to urlString: String, body: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw AuthError.tokenExchangeFailed("Invalid URL: \(urlString)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try assertHTTP2xx(response, data: data)
        return data
    }

    // Percent-encodes a parameter dictionary using RFC 3986 unreserved characters.
    // Safe for both URL query strings and application/x-www-form-urlencoded bodies.
    private func formEncode(_ params: [String: String]) -> String {
        // RFC 3986 unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        return params
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed)   ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    // Throws a descriptive AuthError if the HTTP response status is outside 2xx.
    private func assertHTTP2xx(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable body)"
            throw AuthError.tokenExchangeFailed("HTTP \(http.statusCode): \(body)")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

// The class is @MainActor so this function inherits that isolation, giving it
// access to UIKit APIs without a nonisolated workaround.
extension GmailAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? UIWindow()
    }
}

// MARK: - Supporting types

// Decodes both the initial token exchange response and the refresh response.
// refresh_token is optional because refresh responses don't include it.
private struct TokenResponse: Decodable {
    let access_token:  String
    let refresh_token: String?
    let expires_in:    Int
}

enum AuthError: LocalizedError {
    case notSignedIn
    case invalidCallbackURL
    case tokenExchangeFailed(String)
    case stateMismatch

    var errorDescription: String? {
        switch self {
        case .notSignedIn:                  return "Not signed in to Gmail."
        case .invalidCallbackURL:           return "Invalid OAuth callback URL."
        case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
        case .stateMismatch:                return "OAuth state parameter mismatch — possible CSRF attempt."
        }
    }
}
