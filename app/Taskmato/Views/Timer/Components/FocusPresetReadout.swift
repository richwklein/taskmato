//
//  FocusPresetReadout.swift
//  Taskmato
//

import SwiftUI

/// The countdown readout, which becomes a compact focus-preset menu ahead of a focus session.
///
/// While focus is the next phase to start and more than one preset exists, ``TimerCountdownText``
/// alone is wrapped in a borderless menu of checkmarked presets (design doc 0009, D4) — the
/// `25:00 ▾` affordance shared by the menu-bar popover and the window's Timer surface — with the
/// phase name rendered as a sibling below it, outside the menu. Only the countdown wraps: macOS
/// collapses a stacked countdown-plus-phase-name menu label to one text run, silently dropping
/// the phase name, which made "Ready to focus" unreachable on screen before this split. Otherwise
/// it renders the plain readout, so the countdown never shifts position as a session starts or
/// stops, and a queued break renders exactly as mid-session (issue #580). Selecting a preset
/// routes through `presenter.selectFocusPreset(_:)`.
struct FocusPresetReadout: View {

  /// The presenter supplying the readout text, preset list, current selection, and selection intent.
  var presenter: TimerPresenter

  /// When `true`, the plain (non-menu) readout is hidden from VoiceOver because a surrounding
  /// element — the timer ring — already announces the time. The interactive menu stays reachable.
  var hidesPlainReadoutFromAccessibility: Bool = false

  var body: some View {
    if presenter.showsFocusPresetPicker {
      VStack(spacing: .rowVertical) {
        Menu {
          ForEach(presenter.focusPresets, id: \.self) { minutes in
            Button {
              presenter.selectFocusPreset(minutes)
            } label: {
              if minutes == presenter.selectedFocusMinutes {
                Label("\(minutes) min", systemImage: "checkmark")
              } else {
                Text("\(minutes) min")
              }
            }
          }
        } label: {
          TimerCountdownText(label: presenter.label)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(AppLabels.Accessibility.focusPresets)

        Text(presenter.phaseName)
          .font(.timerPhaseLabel)
          .foregroundStyle(.secondary)
      }
    } else {
      TimerReadout(label: presenter.label, phase: presenter.phaseName)
        .accessibilityHidden(hidesPlainReadoutFromAccessibility)
    }
  }
}

#if DEBUG
  #Preview {
    let engine = SessionEngine()
    let settings = AppSettings()
    settings.focusPresets = [15, 25, 45, 60]
    return FocusPresetReadout(presenter: TimerPresenter(engine: engine, settings: settings))
      .padding()
  }
#endif
