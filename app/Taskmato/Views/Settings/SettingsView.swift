//
//  SettingsView.swift
//  Taskmato
//

import AppKit
import SwiftUI
import UserNotifications

/// The settings view, presented as a standalone window opened via ⌘,.
struct SettingsView: View {

  @Bindable var settings: AppSettings
  var activeTaskStore: ActiveTaskStore
  var registry: ProviderRegistry
  var notifications: NotificationService

  var body: some View {
    Form {
      Section("Focus") {
        FocusPresetsEditor(settings: settings)
      }

      Section("Breaks") {
        DurationStepperRow(label: "Short Break", value: $settings.shortBreakMinutes)
        LongBreakStepperRow(
          duration: $settings.longBreakMinutes,
          afterSessions: $settings.longBreakAfterSessions
        )
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
            Label("Customizing how alerts are delivered", systemImage: "info.circle")
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
          Label("Automatic", systemImage: "wand.and.stars").tag(ProviderID?.none)
          ForEach(writableProviderEntries) { entry in
            Label(entry.displayName, systemImage: entry.icon).tag(ProviderID?.some(entry.id))
          }
        }
        Text(
          "Used when the current sidebar context has no writable provider, and by URL or CLI "
            + "creation when no provider is specified."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("About") {
        Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
          .textSelection(.enabled)
          .foregroundStyle(.secondary)
        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        Link("Support", destination: AppLinks.support)
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

/// A labelled row that uses a native stepper for bounded numeric settings.
private struct DurationStepperRow: View {

  let label: String
  @Binding var value: Int
  var range: ClosedRange<Int> = 1...180
  var unit: String = "min"

  var body: some View {
    HStack {
      Text(label)
      Spacer()
      DurationStepperControl(label: label, value: $value, range: range, unit: unit)
    }
  }
}

/// A compact trailing value plus native stepper control.
private struct DurationStepperControl: View {

  let label: String
  @Binding var value: Int
  let range: ClosedRange<Int>
  let unit: String

  var body: some View {
    HStack(spacing: .contentGap) {
      Text("\(clamp(value)) \(unit)")
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(minWidth: valueWidth, alignment: .trailing)
        .accessibilityHidden(true)

      Stepper(label, value: clampedValue, in: range)
        .labelsHidden()
        .accessibilityValue("\(clamp(value)) \(unit)")
    }
  }

  private var valueWidth: CGFloat {
    unit == "min" ? 54 : 72
  }

  private var clampedValue: Binding<Int> {
    Binding(
      get: { clamp(value) },
      set: { value = clamp($0) }
    )
  }

  private func clamp(_ candidate: Int) -> Int {
    min(max(candidate, range.lowerBound), range.upperBound)
  }
}

/// A two-line long-break control that keeps duration and cadence visually tied.
private struct LongBreakStepperRow: View {

  @Binding var duration: Int
  @Binding var afterSessions: Int

  var body: some View {
    VStack(spacing: .contentGap) {
      HStack {
        Text("Long Break")
        Spacer()
        DurationStepperControl(label: "Long Break", value: $duration, range: 1...180, unit: "min")
      }

      HStack(spacing: 6) {
        Spacer()
        Text("After")
          .foregroundStyle(.secondary)
        DurationStepperControl(
          label: "Long break after", value: $afterSessions, range: 1...8, unit: "sessions")
      }
      .font(.callout)
    }
  }
}

/// A compact focus-preset row with a remove action and optional current-value badge.
private struct FocusPresetRow: View {

  let minutes: Int
  let isCurrent: Bool
  let canRemove: Bool
  let remove: () -> Void

  var body: some View {
    HStack(spacing: .contentGap) {
      Text(label)

      if isCurrent {
        Text(AppLabels.FocusPreset.current)
          .font(.caption2)
          .padding(.horizontal, .iconLabel)
          .padding(.vertical, 2)
          .foregroundStyle(Color.statusSuccess)
          .background(
            Capsule()
              .stroke(Color.statusSuccess.opacity(0.55), lineWidth: 1)
          )
      }

      Spacer()

      Button {
        remove()
      } label: {
        Image(systemName: AppLabels.FocusPreset.remove.systemImage)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .disabled(!canRemove)
      .help(AppLabels.FocusPreset.remove.title)
      .accessibilityLabel("\(AppLabels.FocusPreset.remove.title) \(label)")
    }
  }

  private var label: String {
    "\(minutes) min"
  }
}

/// The **Focus presets** editor (design doc 0009, D5): a static label row per preset, each
/// removable, plus an "Add Duration" affordance that reveals an inline ``DurationField``.
///
/// Every add/remove routes through ``AppSettings/setFocusPresets(_:)`` — this view never
/// assigns `settings.focusPresets` directly, so it can't produce an invalid list.
private struct FocusPresetsEditor: View {

  /// The valid range for a single preset, matching the range the old Focus stepper enforced.
  private static let range = 1...180
  /// The maximum number of presets, mirroring `AppSettings`'s cap.
  private static let maxPresets = 5
  /// The default seed offered when "Add Duration" is first tapped.
  private static let defaultSeed = 30

  let settings: AppSettings

  @State private var isAdding = false
  @State private var newValue = FocusPresetsEditor.defaultSeed

  var body: some View {
    VStack(alignment: .leading, spacing: .contentGap) {
      ForEach(settings.focusPresets, id: \.self) { minutes in
        FocusPresetRow(
          minutes: minutes,
          isCurrent: minutes == settings.focusMinutes,
          canRemove: settings.focusPresets.count > 1
        ) {
          settings.setFocusPresets(settings.focusPresets.filter { $0 != minutes })
        }
      }

      if isAdding {
        addField
      } else {
        addButton
      }
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
    .buttonStyle(.bordered)
    .disabled(atMax)
    .help(atMax ? AppLabels.Tooltip.maxFocusPresetsReached : "")
  }

  private var addField: some View {
    let isDuplicate = settings.focusPresets.contains(newValue)
    return HStack(spacing: .sectionGap) {
      DurationStepperRow(
        label: AppLabels.FocusPreset.add.title, value: $newValue, range: Self.range)
      HStack(spacing: .iconLabel) {
        Button {
          settings.setFocusPresets(settings.focusPresets + [newValue])
          isAdding = false
        } label: {
          Image(systemName: "checkmark.circle.fill")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.statusSuccess)
        .disabled(isDuplicate)
        .help(isDuplicate ? "Focus preset already exists" : "Add focus preset")
        .accessibilityLabel("Add focus preset")

        Button {
          isAdding = false
        } label: {
          Image(systemName: "xmark.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(AppLabels.Tooltip.cancel)
        .accessibilityLabel(AppLabels.Tooltip.cancel)
      }
    }
  }

  /// 30 minutes if unused, otherwise the nearest value in `1...180` not already a preset
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
      activeTaskStore: ActiveTaskStore(),
      registry: ProviderRegistry(),
      notifications: NotificationService(settings: AppSettings())
    )
  }
#endif
