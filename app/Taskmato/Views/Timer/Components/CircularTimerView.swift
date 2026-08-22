//
//  CircularTimerView.swift
//  Taskmato
//

import SwiftUI

/// A circular progress ring with the countdown readout centered inside, plus the staged
/// "next focus" length beneath it.
///
/// The readout is a ``FocusPresetReadout``, so while focus is the next phase to start and more
/// than one preset exists it doubles as the compact focus-duration menu. The ring carries the
/// informational VoiceOver announcement as its own element, leaving the menu independently
/// reachable. ``NextUpReadout`` renders below, outside that grouping, so it stays independently
/// reachable too; it collapses entirely when nothing is staged (design doc "stage the next
/// focus", D-d).
struct CircularTimerView: View {

  /// The presenter supplying progress, the readout, and the ring's accessibility value.
  var presenter: TimerPresenter
  /// The presenter supplying the staged-task readout beneath the ring. Built in `AppComposition`
  /// on the same `TimerPresenter` instance as `presenter`, so the two readouts cannot disagree.
  var nextUpPresenter: NextUpPresenter

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    VStack(spacing: .rowVertical) {
      ZStack {
        TimerRing(progress: presenter.progress, diameter: ringDiameter, strokeWidth: strokeWidth)
          .accessibilityElement()
          .accessibilityLabel(AppLabels.Accessibility.timer)
          .accessibilityValue(presenter.accessibilityValue)
        FocusPresetReadout(presenter: presenter, hidesPlainReadoutFromAccessibility: true)
      }
      .accessibilityElement(children: .contain)

      NextUpReadout(nextUpPresenter: nextUpPresenter)
    }
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
  }
}
