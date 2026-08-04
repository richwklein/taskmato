//
//  ObsidianSetupSheet.swift
//  Taskmato
//

import AppKit
import SwiftUI

/// Configuration sheet displayed when the user enables or re-configures the Obsidian provider.
///
/// Owns the pending file-pattern text so Done can force a commit before dismissing —
/// see issue #509: clicking Done without first pressing Enter used to discard the typed
/// pattern.
struct ObsidianSetupSheet: View {

  var provider: ObsidianProvider
  @Environment(\.dismiss) private var dismiss

  @State private var patternText: String = ""
  @State private var hasValidatedPatternText = false
  @FocusState private var isPatternFocused: Bool

  private var expandedPatternSummary: String? {
    let patterns = PatternList.parse(patternText)
    let expanded = patterns.map { provider.expandTokens($0) }
    guard !patterns.isEmpty, expanded != patterns else { return nil }
    return expanded.joined(separator: ", ")
  }

  private var dateTokenValidationMessage: String? {
    var invalidTokens: [String] = []
    for pattern in PatternList.parse(patternText) {
      for token in ObsidianPatternTokens.invalidDateTokens(in: pattern)
      where !invalidTokens.contains(token) {
        invalidTokens.append(token)
      }
    }
    guard !invalidTokens.isEmpty else { return nil }

    let label = invalidTokens.count == 1 ? "token" : "tokens"
    return
      "Unsupported date \(label) \(invalidTokens.joined(separator: ", ")). "
      + "Use {year}, {YYYY}, {month}, {MM}, {week}, {ww}, {day}, or {DD}."
  }

  private var showsDateTokenValidation: Bool {
    hasValidatedPatternText && dateTokenValidationMessage != nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .sectionGap) {
      Text("Configure \(provider.displayName)")
        .font(.sheetTitle)

      if provider.isConfigured {
        SettingsFieldRow("Vault") {
          Text(provider.vaultName)
        }

        SettingsFieldRow("File patterns") {
          VStack(alignment: .leading, spacing: .iconLabel) {
            TextField("e.g. **/*.md", text: $patternText)
              .autocorrectionDisabled()
              .focused($isPatternFocused)
              .overlay {
                if showsDateTokenValidation {
                  RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.statusError, lineWidth: 1)
                }
              }
              .onSubmit { _ = commitPatterns(validate: true, refocusOnInvalid: true) }
              .onChange(of: patternText) { _, newValue in
                if isPatternFocused, PatternList.parse(newValue) != provider.filePatterns {
                  hasValidatedPatternText = false
                }
              }
              .onChange(of: isPatternFocused) { _, focused in
                if !focused {
                  _ = commitPatterns(validate: true)
                }
              }

            if showsDateTokenValidation, let dateTokenValidationMessage {
              Label(
                dateTokenValidationMessage,
                systemImage: "exclamationmark.triangle.fill"
              )
              .font(.caption)
              .foregroundStyle(Color.statusError)
            }

            if let expandedPatternSummary {
              Text("Preview: \(expandedPatternSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Current expansion of date tokens")
            }
          }
        }

        VStack(alignment: .leading, spacing: .rowVertical) {
          DisclosureGroup {
            VStack(alignment: .leading, spacing: .iconLabel) {
              Text(AppLabels.ObsidianTokens.intro)
                .foregroundStyle(.secondary)
                .font(.callout)
              BulletText(AppLabels.ObsidianTokens.yearToken)
              BulletText(AppLabels.ObsidianTokens.monthToken)
              BulletText(AppLabels.ObsidianTokens.weekToken)
              BulletText(AppLabels.ObsidianTokens.dayToken)
              Text(AppLabels.ObsidianTokens.example)
                .foregroundStyle(.secondary)
                .font(.callout)
            }
          } label: {
            Label(AppLabels.ObsidianTokens.disclosureLabel, systemImage: "info.circle")
              .foregroundStyle(.secondary)
          }
        }
        .padding(.leading, SettingsFieldRowMetrics.contentLeadingPadding)

        HStack {
          Button("Change Vault…", action: selectVault)
          Button("Remove Vault", role: .destructive) {
            provider.clearVault()
          }
        }
      } else {
        Text("No vault selected.")
          .foregroundStyle(.secondary)

        Button("Select Vault…", action: selectVault)
      }

      HStack {
        Spacer()
        Button("Done") {
          if commitPatterns(validate: true, refocusOnInvalid: true) {
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(.screenPadding)
    .frame(minWidth: 360)
    .onAppear {
      patternText = provider.filePatterns.joined(separator: ", ")
      hasValidatedPatternText = false
    }
    .onChange(of: provider.vaultURL) { _, _ in
      patternText = provider.filePatterns.joined(separator: ", ")
      hasValidatedPatternText = false
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
    hasValidatedPatternText = false
  }

  private func commitPatterns(
    validate: Bool = false,
    refocusOnInvalid: Bool = false
  ) -> Bool {
    if validate {
      hasValidatedPatternText = true
    }

    if dateTokenValidationMessage != nil {
      if refocusOnInvalid {
        isPatternFocused = true
      }
      return false
    }

    provider.setFilePatterns(PatternList.parse(patternText))
    patternText = provider.filePatterns.joined(separator: ", ")
    hasValidatedPatternText = validate
    return true
  }
}

private enum SettingsFieldRowMetrics {
  static let labelWidth: CGFloat = 92
  static let contentLeadingPadding: CGFloat = labelWidth + .contentGap
}

private struct SettingsFieldRow<Content: View>: View {
  let title: String
  let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .contentGap) {
      Text(title)
        .frame(width: SettingsFieldRowMetrics.labelWidth, alignment: .trailing)

      content
    }
  }
}
