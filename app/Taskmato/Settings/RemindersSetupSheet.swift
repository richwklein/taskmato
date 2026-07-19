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

  private var listSummaryText: String {
    let total = allCalendarTitles.count
    if provider.listPatterns.isEmpty {
      return "\(total) reminder list\(total == 1 ? "" : "s") available"
    }
    let matched = allCalendarTitles.filter {
      provider.matchesAnyPattern(title: $0, patterns: provider.listPatterns)
    }.count
    return "\(matched) of \(total) lists match"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Apple Reminders")
        .font(.title2)
        .fontWeight(.semibold)

      content

      HStack {
        Spacer()
        Button("Done") {
          commitPatterns()
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
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
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .imageScale(.large)
      Text(listSummaryText)
    }

    LabeledContent("List patterns") {
      TextField("e.g. Work*, *Personal*", text: $patternText)
        .autocorrectionDisabled()
        .focused($isPatternFocused)
        .onSubmit { commitPatterns() }
        .onChange(of: isPatternFocused) { _, focused in
          if !focused { commitPatterns() }
        }
    }
  }

  private var grantAccessView: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(
        "Taskmato needs access to your reminders so you can "
          + "select one as your focus task."
      )
      .foregroundStyle(.secondary)

      Button("Grant Access") {
        Task { await requestAccess() }
      }
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
    let patterns =
      patternText
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    provider.setListPatterns(patterns)
    patternText = provider.listPatterns.joined(separator: ", ")
  }
}
