//
//  SettingsView.swift
//  Taskmato
//

import SwiftUI

/// The settings view, usable both as a navigation destination inside the popover
/// and as a standalone window opened via ⌘,.
struct SettingsView: View {

  @Bindable var settings: AppSettings
  var selectionStore: TaskSelectionStore
  var registry: TaskRegistry

  var body: some View {
    Form {
      Section("Durations") {
        DurationField("Focus", value: $settings.focusMinutes, range: 1...60)
        DurationField("Short Break", value: $settings.shortBreakMinutes, range: 1...30)
        DurationField("Long Break", value: $settings.longBreakMinutes, range: 1...60)
      }

      Section("Long Break") {
        DurationField(
          "After every", value: $settings.longBreakAfterSessions, range: 1...8, unit: "sessions")
      }

      Section("Behavior") {
        Toggle("Play sound on phase completion", isOn: $settings.soundEnabled)
        Toggle("Show notification on phase completion", isOn: $settings.notificationsEnabled)
        Toggle("Auto-start next phase", isOn: $settings.autoStartNextPhase)
        Toggle("Show Dock icon", isOn: $settings.showDockIcon)
        Text("Takes effect the next time \(Bundle.main.appName) is launched.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Tasks") {
        Picker(
          "Default writable provider",
          selection: Binding(
            get: { settings.defaultWritableProviderID ?? "" },
            set: { settings.defaultWritableProviderID = $0.isEmpty ? nil : $0 }
          )
        ) {
          Text("Automatic").tag("")
          ForEach(writableProviderEntries) { entry in
            Label(entry.displayName, systemImage: entry.icon).tag(entry.id)
          }
        }
        Text(
          "The provider used when creating ad-hoc tasks from the command line or the Add Task sheet."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .navigationTitle("\(Bundle.main.appName) Settings")
  }

  /// Registered providers that are currently enabled and conform to ``WritableTaskProvider``,
  /// formatted for display in the default-provider picker.
  private var writableProviderEntries: [ProviderEntry] {
    registry.providers.compactMap { provider in
      guard registry.isEnabled(provider.id),
        provider is (any WritableTaskProvider)
      else { return nil }
      return ProviderEntry(id: provider.id, displayName: provider.displayName, icon: provider.icon)
    }
  }
}

/// A lightweight display model for a writable provider in the settings picker.
private struct ProviderEntry: Identifiable {
  let id: String
  let displayName: String
  let icon: String
}

/// A labelled row combining a text field for direct input and a stepper for nudging.
private struct DurationField: View {

  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>
  let unit: String

  @State private var text: String = ""
  @FocusState private var isFocused: Bool

  init(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String = "min") {
    self.label = label
    self._value = value
    self.range = range
    self.unit = unit
    self._text = State(initialValue: "\(value.wrappedValue)")
  }

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      TextField("", text: $text)
        .multilineTextAlignment(.trailing)
        .frame(width: 36)
        .focused($isFocused)
        .onSubmit { commit() }
        .onChange(of: isFocused) { _, focused in
          if !focused { commit() }
        }
        .onChange(of: value) { _, new in
          if !isFocused { text = "\(new)" }
        }
      Text(unit)
        .foregroundStyle(.secondary)
      Stepper("", value: $value, in: range)
        .labelsHidden()
    }
  }

  /// Parses the text field input and updates `value` if valid, otherwise reverts the text.
  private func commit() {
    if let parsed = Int(text), range.contains(parsed) {
      value = parsed
    }
    text = "\(value)"
  }
}

#Preview {
  SettingsView(
    settings: AppSettings(),
    selectionStore: TaskSelectionStore(),
    registry: TaskRegistry()
  )
}
