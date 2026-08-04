//
//  FocusPresetReadout.swift
//  Taskmato
//

import SwiftUI

/// The countdown readout, which becomes a compact focus-preset menu while idle.
///
/// While the engine is idle and more than one preset exists, the ``TimerReadout`` is wrapped in a
/// borderless menu of checkmarked presets (design doc 0009, D4) — the `25:00 ▾` affordance shared
/// by the menu-bar popover and the window's Timer surface. Once the engine leaves idle, the menu
/// disappears (rather than staying mounted-but-inert — that read as a live control even when
/// non-interactive) and the trailing space it occupied — roughly the system chevron's width — is
/// reserved with ``chevronReserve`` so the countdown doesn't shift horizontally when the
/// affordance appears or disappears. Selecting a preset routes through
/// `presenter.selectFocusPreset(_:)`.
struct FocusPresetReadout: View {

  /// The estimated width of the system-drawn menu chevron plus its leading gap, reserved next to
  /// the plain readout while idle-with-a-picker isn't true, so the countdown's horizontal
  /// position matches where it sits inside the menu.
  private static let chevronReserve: CGFloat = 16

  /// The presenter supplying the readout text, preset list, current selection, and selection intent.
  var presenter: TimerPresenter

  /// When `true`, the plain (non-menu) readout is hidden from VoiceOver because a surrounding
  /// element — the timer ring — already announces the time. The interactive menu stays reachable.
  var hidesPlainReadoutFromAccessibility: Bool = false

  var body: some View {
    if presenter.isIdle && presenter.showsFocusPresetPicker {
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
      .accessibilityLabel(AppLabels.Accessibility.focusPresets)
    } else if presenter.showsFocusPresetPicker {
      HStack(spacing: 0) {
        TimerReadout(label: presenter.label, phase: presenter.phaseName)
        Color.clear.frame(width: Self.chevronReserve, height: 0)
      }
      .fixedSize()
      .accessibilityHidden(hidesPlainReadoutFromAccessibility)
    } else {
      TimerReadout(label: presenter.label, phase: presenter.phaseName)
        .accessibilityHidden(hidesPlainReadoutFromAccessibility)
    }
  }
}

#if DEBUG
  #Preview("Idle") {
    let engine = SessionEngine()
    let settings = AppSettings()
    settings.focusPresets = [15, 25, 45, 60]
    return FocusPresetReadout(presenter: TimerPresenter(engine: engine, settings: settings))
      .padding()
  }

  #Preview("Running") {
    let engine = SessionEngine()
    let settings = AppSettings()
    settings.focusPresets = [15, 25, 45, 60]
    engine.start()
    return FocusPresetReadout(presenter: TimerPresenter(engine: engine, settings: settings))
      .padding()
  }
#endif
