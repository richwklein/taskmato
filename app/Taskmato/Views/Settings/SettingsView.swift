//
//  SettingsView.swift
//  Taskmato
//

import AppKit
import SwiftUI
import UserNotifications

/// The settings view, usable both as a navigation destination inside the popover
/// and as a standalone window opened via ⌘,.
struct SettingsView: View {

  @Bindable var settings: AppSettings
  var selectionStore: TaskSelectionStore
  var registry: ProviderRegistry
  var notifications: NotificationService

  var body: some View {
    Form {
      Section("Durations") {
        FocusPresetsEditor(settings: settings)
        DurationField("Short Break", value: $settings.shortBreakMinutes, range: 1...30)
        DurationField("Long Break", value: $settings.longBreakMinutes, range: 1...60)
      }

      Section("Long Break") {
        DurationField(
          "After every", value: $settings.longBreakAfterSessions, range: 1...8, unit: "sessions")
      }

      Section("Phase-end Alerts") {
        Toggle("Enable alerts", isOn: $settings.notificationsEnabled)

        if settings.notificationsEnabled {
          if notifications.authStatus == .denied {
            HStack(spacing: .contentGap) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.statusError)
              VStack(alignment: .leading, spacing: .stackTight) {
                Text("Notifications are disabled in System Settings")
                  .foregroundStyle(Color.statusError)
                Button("Open Notification Settings…") {
                  openNotificationSettings()
                }
                .buttonStyle(.link)
              }
            }
            .padding(.leading)
          }

          Toggle("Play sound", isOn: $settings.soundEnabled)
            .padding(.leading)

          if settings.soundEnabled {
            Picker("Sound", selection: $settings.soundName) {
              ForEach(SystemSound.all) { sound in
                Text(sound.displayName).tag(sound.name)
              }
            }
            .padding(.leading)
          }

          DisclosureGroup {
            VStack(alignment: .leading, spacing: .iconLabel) {
              Text(
                "Taskmato's settings control which cues fire. "
                  + "System Settings → Notifications → Taskmato controls how they appear:"
              )
              .foregroundStyle(.secondary)
              .font(.callout)
              BulletText("Sound only, no banner — Alert style: None")
              BulletText("Banner without sound — turn off \"Play sound\" above")
              BulletText("Persistent alert — Alert style: Alerts")
              Text("Sound respects your Focus and Do Not Disturb settings.")
                .foregroundStyle(.secondary)
                .font(.callout)
              Button("Open Notification Settings…") {
                openNotificationSettings()
              }
              .buttonStyle(.link)
            }
          } label: {
            Text("ⓘ Customizing how alerts are delivered")
              .foregroundStyle(.secondary)
          }
          .padding(.leading)
        }
      }

      Section("Behavior") {
        Toggle("Auto-start next phase", isOn: $settings.autoStartNextPhase)
      }

      Section("Tasks") {
        Picker("Default writable provider", selection: $settings.defaultWritableProviderID) {
          Text("Automatic").tag(ProviderID?.none)
          ForEach(writableProviderEntries) { entry in
            Label(entry.displayName, systemImage: entry.icon).tag(ProviderID?.some(entry.id))
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

  private func openNotificationSettings() {
    guard let bundleID = Bundle.main.bundleIdentifier,
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleID)"
      )
    else { return }
    NSWorkspace.shared.open(url)
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

// MARK: - Supporting types

/// One of the five built-in system sounds available for phase-end alerts.
private struct SystemSound: Identifiable {
  let name: String
  let displayName: String

  var id: String { name }

  /// All available sound options, with Hero first as the default.
  static let all: [SystemSound] = [
    SystemSound(name: "Hero", displayName: "Hero"),
    SystemSound(name: "Glass", displayName: "Glass"),
    SystemSound(name: "Tink", displayName: "Tink"),
    SystemSound(name: "Sosumi", displayName: "Sosumi"),
    SystemSound(name: "Ping", displayName: "Ping"),
  ]
}

/// A lightweight display model for a writable provider in the settings picker.
private struct ProviderEntry: Identifiable {
  let id: ProviderID
  let displayName: String
  let icon: String
}

/// A simple bullet-point text row for use inside the notification settings disclosure.
private struct BulletText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    HStack(alignment: .top, spacing: .rowVertical) {
      Text("•").foregroundStyle(.secondary)
      Text(text).foregroundStyle(.secondary)
    }
    .font(.callout)
  }
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

/// The **Focus presets** editor (design doc 0009, D5): a static label row per preset, each
/// removable, plus an "Add Duration" affordance that reveals an inline ``DurationField``.
///
/// Every add/remove routes through ``AppSettings/setFocusPresets(_:)`` — this view never
/// assigns `settings.focusPresets` directly, so it can't produce an invalid list.
private struct FocusPresetsEditor: View {

  /// The valid range for a single preset, matching the range the old Focus stepper enforced.
  private static let range = 1...60
  /// The maximum number of presets, mirroring `AppSettings`'s cap.
  private static let maxPresets = 5
  /// The default seed offered when "Add Duration" is first tapped.
  private static let defaultSeed = 30

  let settings: AppSettings

  @State private var isAdding = false
  @State private var newValue = FocusPresetsEditor.defaultSeed

  var body: some View {
    VStack(alignment: .leading, spacing: .contentGap) {
      Text(AppLabels.FocusPreset.sectionTitle)
        .foregroundStyle(.secondary)

      ForEach(settings.focusPresets, id: \.self) { minutes in
        presetRow(minutes)
      }

      if isAdding {
        addField
      } else {
        addButton
      }
    }
  }

  private func presetRow(_ minutes: Int) -> some View {
    HStack {
      Text(label(for: minutes))
      Spacer()
      Button {
        settings.setFocusPresets(settings.focusPresets.filter { $0 != minutes })
      } label: {
        Image(systemName: AppLabels.FocusPreset.remove.systemImage)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .disabled(settings.focusPresets.count <= 1)
      .help(AppLabels.FocusPreset.remove.title)
      .accessibilityLabel("\(AppLabels.FocusPreset.remove.title) \(label(for: minutes))")
    }
  }

  private var addButton: some View {
    let atMax = settings.focusPresets.count >= Self.maxPresets
    return Button {
      newValue = seedValue()
      isAdding = true
    } label: {
      Label(AppLabels.FocusPreset.add.title, systemImage: AppLabels.FocusPreset.add.systemImage)
    }
    .buttonStyle(.plain)
    .foregroundStyle(atMax ? Color.secondary : Color.accentColor)
    .disabled(atMax)
    .help(atMax ? AppLabels.Tooltip.maxFocusPresetsReached : "")
  }

  private var addField: some View {
    HStack {
      DurationField(AppLabels.FocusPreset.add.title, value: $newValue, range: Self.range)
      Button {
        settings.setFocusPresets(settings.focusPresets + [newValue])
        isAdding = false
      } label: {
        Image(systemName: "checkmark.circle.fill")
      }
      .buttonStyle(.plain)
      Button {
        isAdding = false
      } label: {
        Image(systemName: "xmark.circle")
      }
      .buttonStyle(.plain)
      .help(AppLabels.Tooltip.cancel)
    }
  }

  /// The row label for `minutes`, marking the one matching `focusMinutes` as current.
  private func label(for minutes: Int) -> String {
    minutes == settings.focusMinutes
      ? "\(minutes) min · \(AppLabels.FocusPreset.current)"
      : "\(minutes) min"
  }

  /// 30 minutes if unused, otherwise the nearest value in `1...60` not already a preset
  /// (design doc plan, "Add-stepper seed").
  private func seedValue() -> Int {
    let used = Set(settings.focusPresets)
    guard used.contains(Self.defaultSeed) else { return Self.defaultSeed }
    for offset in 1...(Self.range.upperBound - Self.range.lowerBound) {
      let lower = Self.defaultSeed - offset
      if lower >= Self.range.lowerBound, !used.contains(lower) { return lower }
      let upper = Self.defaultSeed + offset
      if upper <= Self.range.upperBound, !used.contains(upper) { return upper }
    }
    return Self.defaultSeed
  }
}

#if DEBUG
  #Preview {
    SettingsView(
      settings: AppSettings(),
      selectionStore: TaskSelectionStore(),
      registry: ProviderRegistry(),
      notifications: NotificationService(settings: AppSettings())
    )
  }
#endif
