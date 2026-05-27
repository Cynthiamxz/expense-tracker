// ContentView.swift
// Responsibility: Root TabView — the permanent three-tab shell of the app.
//                 Owns tab selection state. Each tab hosts its own navigation stack.
// Depends on: SummaryView, TransactionsView, SettingsView
// Used by: AppRootView (ExpenseTrackerApp.swift) — this is the top-level view

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView()
                .tabItem { Label("Summary",      systemImage: "chart.pie.fill") }
                .tag(0)

            TransactionsView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings",     systemImage: "gearshape.fill") }
                .tag(2)
        }
        .onAppear { applyTabBarAppearance() }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environmentObject(GmailAuthService())
        .environmentObject(SyncService(
            fetcher:         GmailFetchService(auth: GmailAuthService()),
            parser:          EmailParserService(),
            modelContext:    try! ModelContext(ModelContainer(for: Transaction.self, Category.self)),
            labelRulesStore: LabelRulesStore()
        ))
        .environmentObject(LabelRulesStore())
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
