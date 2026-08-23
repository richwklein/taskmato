//
//  CircularTimerView.swift
//  Taskmato
//

import SwiftUI

/// A circular progress ring with the countdown readout centered inside, and the staged
/// "next focus" length stacked under the phase name.
///
/// The readout is a ``FocusPresetReadout``, so while focus is the next phase to start and more
/// than one preset exists it doubles as the compact focus-duration menu. The ring carries the
/// informational VoiceOver announcement as its own element, leaving the menu independently
/// reachable. ``NextUpReadout`` sits inside the ring as the third line, below the phase name,
/// and collapses entirely when nothing is staged (design doc "stage the next focus", D-d) — so
/// the countdown shifts up by half a line when it appears rather than reserving blank space.
struct CircularTimerView: View {

  /// The presenter supplying progress, the readout, and the ring's accessibility value.
  var presenter: TimerPresenter
  /// The presenter supplying the staged-focus line inside the ring. Built in `AppComposition`
  /// on the same `TimerPresenter` instance as `presenter`, so the two readouts cannot disagree.
  var nextUpPresenter: NextUpPresenter

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    ZStack {
      TimerRing(progress: presenter.progress, diameter: ringDiameter, strokeWidth: strokeWidth)
        .accessibilityElement()
        .accessibilityLabel(AppLabels.Accessibility.timer)
        .accessibilityValue(presenter.accessibilityValue)

      VStack(spacing: .rowVertical) {
        FocusPresetReadout(presenter: presenter, hidesPlainReadoutFromAccessibility: true)
        NextUpReadout(nextUpPresenter: nextUpPresenter)
      }
      // Keeps the staged line from pushing against the ring's inner edge on the widest
      // "Next focus: 60 min" wording at large Dynamic Type sizes.
      .padding(.horizontal, .contentGap)
    }
    .accessibilityElement(children: .contain)
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
  }
}
