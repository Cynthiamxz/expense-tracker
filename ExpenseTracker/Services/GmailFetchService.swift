// GmailFetchService.swift
// Responsibility: All Gmail REST API network calls — listing message IDs by label,
//                 batch-fetching full message bodies, and returning raw email data
//                 for the parser. Never modifies or sends email.
// Depends on: Foundation (URLSession), GmailAuthService (valid token), Constants
// Used by: SyncService (calls fetchNewMessages(existingIds:) during each sync cycle)

import Foundation

class GmailFetchService {
    private let auth: GmailAuthService

    init(auth: GmailAuthService) {
        self.auth = auth
    }

    // MARK: - Public API

    // Returns all Gmail message IDs carrying the given label.
    // Follows nextPageToken until the full list is exhausted.
    func listMessageIds(label: String = Constants.Labels.defaultLabel) async throws -> [String] {
        let token = try await auth.validAccessToken()
        var ids: [String] = []
        var pageToken: String? = nil

        repeat {
            var components = URLComponents(string: "\(Constants.Gmail.baseURL)/users/me/messages")!
            var items: [URLQueryItem] = [URLQueryItem(name: "q", value: "label:\(label)")]
            if let pt = pageToken {
                items.append(URLQueryItem(name: "pageToken", value: pt))
            }
            components.queryItems = items

            guard let url = components.url else { break }

            let (data, response) = try await URLSession.shared.data(for: buildRequest(url: url, token: token))
            try assertHTTP2xx(response, data: data)

            let page = try JSONDecoder().decode(MessageListResponse.self, from: data)
            ids.append(contentsOf: page.messages?.map(\.id) ?? [])
            pageToken = page.nextPageToken

        } while pageToken != nil

        return ids
    }

    // Fetches a full message payload (format=full) and returns raw JSON Data.
    // The EmailParserService handles all JSON decoding so this stays transport-only.
    func fetchMessage(id: String) async throws -> Data {
        let token = try await auth.validAccessToken()
        guard let url = URL(string: "\(Constants.Gmail.baseURL)/users/me/messages/\(id)?format=full") else {
            throw FetchError.badURL(id)
        }
        let (data, response) = try await URLSession.shared.data(for: buildRequest(url: url, token: token))
        try assertHTTP2xx(response, data: data)
        return data
    }

    // Main entry point for SyncService.
    // Queries every enabled label, deduplicates IDs across labels, then fetches
    // bodies for IDs not already in SwiftData. Sequential fetch keeps rate low.
    func fetchNewMessages(existingIds: Set<String>, labels: [String]) async throws -> [(id: String, data: Data)] {
        var seen = Set<String>()
        var newIds: [String] = []

        for label in labels {
            for id in try await listMessageIds(label: label) {
                if !existingIds.contains(id) && seen.insert(id).inserted {
                    newIds.append(id)
                }
            }
        }

        var results: [(id: String, data: Data)] = []
        results.reserveCapacity(newIds.count)
        for id in newIds {
            let data = try await fetchMessage(id: id)
            results.append((id: id, data: data))
        }
        return results
    }

    // MARK: - Private helpers

    private func buildRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func assertHTTP2xx(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse,
              !(200..<300).contains(http.statusCode) else { return }
        let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
        throw FetchError.httpError(http.statusCode, body)
    }
}

// MARK: - Supporting types

private struct MessageListResponse: Decodable {
    let messages: [MessageRef]?
    let nextPageToken: String?
    // resultSizeEstimate is present in the API response but unused here.
}

private struct MessageRef: Decodable {
    let id: String
}

enum FetchError: LocalizedError {
    case badURL(String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL(let id):         return "Could not build URL for message \(id)."
        case .httpError(let code, let body): return "Gmail API error \(code): \(body)"
        }
    }
}
