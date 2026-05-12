//
//  ObsidianSettingsView.swift
//  Taskmato
//

import AppKit
import SwiftUI

/// Vault and file-pattern configuration rows for the Obsidian provider.
///
/// Rendered inside the Providers section of ``SettingsView`` only when the
/// Obsidian provider is enabled. Does not include a ``Section`` wrapper —
/// the caller is responsible for the surrounding context.
@MainActor
struct ObsidianSettingsView: View {

  var provider: ObsidianProvider

  @State private var patternText: String = ""
  @FocusState private var isPatternFocused: Bool

  var body: some View {
    Group {
      if provider.isConfigured {
        LabeledContent("Vault", value: provider.vaultName)

        Button("Change Vault…", action: selectVault)

        LabeledContent("File patterns") {
          VStack(alignment: .leading, spacing: 4) {
            TextField("e.g. **/*.md", text: $patternText)
              .focused($isPatternFocused)
              .onSubmit { commitPatterns() }
              .onChange(of: isPatternFocused) { _, focused in
                if !focused { commitPatterns() }
              }
            Text("Use {week}, {year}, {month}, {day} — e.g. W{week}.md → W18.md")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Button("Remove Vault", role: .destructive) {
          provider.clearVault()
        }
      } else {
        Text("No vault selected.")
          .foregroundStyle(.secondary)

        Button("Select Vault…", action: selectVault)
      }
    }
    .onAppear { patternText = provider.filePatterns.joined(separator: ", ") }
    .onChange(of: provider.vaultURL) { _, _ in
      patternText = provider.filePatterns.joined(separator: ", ")
    }
  }

  // MARK: - Actions

  private func selectVault() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.message = "Select your Obsidian vault folder"
    panel.prompt = "Select"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? provider.saveVaultBookmark(for: url)
    patternText = provider.filePatterns.joined(separator: ", ")
  }

  private func commitPatterns() {
    let patterns =
      patternText
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    provider.setFilePatterns(patterns)
    patternText = provider.filePatterns.joined(separator: ", ")
  }
}
