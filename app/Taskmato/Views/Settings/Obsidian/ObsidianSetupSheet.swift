//
//  ObsidianSetupSheet.swift
//  Taskmato
//

import SwiftUI

/// Configuration sheet displayed when the user enables or re-configures the Obsidian provider.
struct ObsidianSetupSheet: View {

  var provider: ObsidianProvider
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: .sectionGap) {
      Text("Configure \(provider.displayName)")
        .font(.sheetTitle)

      ObsidianSettingsView(provider: provider)

      HStack {
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(.screenPadding)
    .frame(minWidth: 360)
  }
}
