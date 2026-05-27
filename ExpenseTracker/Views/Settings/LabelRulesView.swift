// LabelRulesView.swift
// Note: Label rule management is now fully inline in SettingsView.
//       This file is kept as a stub; LabelRule and LabelRulesStore live in
//       Services/LabelRulesStore.swift.

import SwiftUI

struct LabelRulesView: View {
    var body: some View {
        Text("Label rules are managed in Settings.")
            .foregroundStyle(.secondary)
            .navigationTitle("Label Rules")
            .navigationBarTitleDisplayMode(.inline)
    }
}
