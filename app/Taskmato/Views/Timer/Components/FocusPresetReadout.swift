//
//  FocusPresetReadout.swift
//  Taskmato
//

import SwiftUI

/// The countdown readout, which doubles as a compact focus-preset menu whenever more than one
/// preset exists.
///
/// While more than one preset exists, the ``TimerReadout`` is wrapped in a borderless menu of
/// checkmarked presets (design doc 0009, D4) — the `25:00 ▾` affordance shared by the menu-bar
/// popover and the window's Timer surface. The menu stays mounted for the whole session
/// lifecycle so the countdown never shifts position as a session starts or stops; once the
/// engine leaves idle it becomes inert (`.allowsHitTesting(false)` for pointer/touch,
/// `.accessibilityRespondsToUserInteraction(false)` for VoiceOver/Switch Control/Voice Control)
/// rather than disabled, so the countdown text keeps its normal, undimmed style instead of
/// picking up SwiftUI's automatic disabled appearance. Selecting a preset routes through
/// `presenter.selectFocusPreset(_:)`, which is itself a no-op while running or paused.
struct FocusPresetReadout: View {

  /// The presenter supplying the readout text, preset list, current selection, and selection intent.
  var presenter: TimerPresenter

  /// When `true`, the readout is hidden from VoiceOver whenever it isn't interactive — the
  /// non-menu branch, or the menu branch once the engine leaves idle — because a surrounding
  /// element — the timer ring — already announces the time. The interactive menu stays reachable.
  var hidesPlainReadoutFromAccessibility: Bool = false

  var body: some View {
    if presenter.showsFocusPresetPicker {
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
        TimerReadout(label: presenter.label, phase: presenter.phaseName)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .allowsHitTesting(presenter.isIdle)
      .accessibilityRespondsToUserInteraction(presenter.isIdle)
      .accessibilityLabel(AppLabels.Accessibility.focusPresets)
      .accessibilityHidden(hidesPlainReadoutFromAccessibility && !presenter.isIdle)
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
