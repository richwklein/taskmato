//
//  RemindersSetupSheet.swift
//  Taskmato
//

import SwiftUI

/// Configuration sheet shown when the user enables Apple Reminders via the
/// sidebar's "Add Provider" menu, or via the "Configure Apple Reminders…"
/// context menu on the provider header.
struct RemindersSetupSheet: View {

  var provider: RemindersProvider
  @Environment(\.dismiss) private var dismiss

  @State private var error: RemindersProviderError?
  @State private var allCalendarTitles: [String] = []
  @State private var patternText: String = ""
  @FocusState private var isPatternFocused: Bool

  private var draftPatterns: [String] {
    PatternList.parse(patternText)
  }

  private var matchingCalendarCount: Int {
    guard !draftPatterns.isEmpty else { return allCalendarTitles.count }
    return allCalendarTitles.filter {
      provider.matchesAnyPattern(title: $0, patterns: draftPatterns)
    }.count
  }

  private var listSummaryText: String {
    let total = allCalendarTitles.count
    if draftPatterns.isEmpty {
      return "\(total) reminder list\(total == 1 ? "" : "s") available"
    }
    return "\(matchingCalendarCount) of \(total) lists match"
  }

  private var showsListPatternWarning: Bool {
    !draftPatterns.isEmpty && !allCalendarTitles.isEmpty && matchingCalendarCount == 0
  }

  private var doneKeyboardShortcut: KeyboardShortcut? {
    provider.isAuthorized || error == .accessRestricted ? .defaultAction : nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .sectionGap) {
      Text("Configure \(provider.displayName)")
        .font(.sheetTitle)

      content

      HStack {
        Spacer()
        Button("Done") {
          commitPatterns()
          dismiss()
        }
        .keyboardShortcut(doneKeyboardShortcut)
      }
    }
    .padding(.screenPadding)
    .frame(minWidth: 360)
    .alert(
      "Reminders Access Denied",
      isPresented: showDeniedAlert,
      actions: { deniedAlertActions },
      message: { deniedAlertMessage }
    )
  }

  // MARK: - Content states

  @ViewBuilder
  private var content: some View {
    if provider.isAuthorized {
      authorizedView
        .task { await loadAllCalendarTitles() }
        .onAppear { patternText = provider.listPatterns.joined(separator: ", ") }
    } else if error == .accessRestricted {
      restrictedView
    } else {
      grantAccessView
    }
  }

  @ViewBuilder
  private var authorizedView: some View {
    VStack(alignment: .leading, spacing: .sectionGap) {
      RemindersSettingsFieldRow("List patterns") {
        VStack(alignment: .leading, spacing: .iconLabel) {
          TextField("e.g. Work*, *Personal*", text: $patternText)
            .autocorrectionDisabled()
            .focused($isPatternFocused)
            .onSubmit { commitPatterns() }
            .onChange(of: isPatternFocused) { _, focused in
              if !focused { commitPatterns() }
            }

          if showsListPatternWarning {
            Label(
              "No reminder lists match this pattern.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(Color.statusWarning)
          } else {
            Text(listSummaryText)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }

      ProviderDefaultListSettings(provider: provider)
    }
  }

  private var grantAccessView: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text(
        "Taskmato needs access to your reminders so you can "
          + "select one as your focus task."
      )
      .foregroundStyle(.secondary)

      Button("Grant Access") {
        Task { await requestAccess() }
      }
      .keyboardShortcut(.defaultAction)
    }
  }

  private var restrictedView: some View {
    Text(
      "Reminders access is restricted on this device "
        + "(e.g. by MDM or parental controls)."
    )
    .foregroundStyle(.secondary)
  }

  // MARK: - Denied alert

  private var showDeniedAlert: Binding<Bool> {
    Binding(
      get: {
        error == .accessDenied || error == .fullAccessRequired
      },
      set: { showing in
        if !showing { error = nil }
      }
    )
  }

  @ViewBuilder
  private var deniedAlertActions: some View {
    Button("Open System Settings") {
      if let url = URL(
        string:
          "x-apple.systempreferences:"
          + "com.apple.preference.security"
          + "?Privacy_Reminders"
      ) {
        NSWorkspace.shared.open(url)
      }
    }
    Button("Cancel", role: .cancel) {}
  }

  private var deniedAlertMessage: some View {
    Text(
      "Grant full access in System Settings → "
        + "Privacy & Security → Reminders."
    )
  }

  // MARK: - Actions

  private func requestAccess() async {
    do {
      try await provider.authorize()
      await loadAllCalendarTitles()
    } catch let err as RemindersProviderError {
      error = err
    } catch {}
  }

  private func loadAllCalendarTitles() async {
    allCalendarTitles = provider.allCalendarTitles()
  }

  private func commitPatterns() {
    provider.setListPatterns(PatternList.parse(patternText))
    patternText = provider.listPatterns.joined(separator: ", ")
  }
}

private enum RemindersSettingsFieldRowMetrics {
  static let labelWidth: CGFloat = 92
}

private struct RemindersSettingsFieldRow<Content: View>: View {
  let title: String
  let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .contentGap) {
      Text(title)
        .frame(width: RemindersSettingsFieldRowMetrics.labelWidth, alignment: .trailing)

      content
    }
  }
}
