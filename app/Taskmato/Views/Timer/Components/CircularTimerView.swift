//
//  CircularTimerView.swift
//  Taskmato
//

import SwiftUI

/// A circular progress ring with the countdown readout centered inside.
///
/// The readout is a ``FocusPresetReadout``, so while focus is the next phase to start and more
/// than one preset exists it doubles as the compact focus-duration menu. The ring carries the
/// informational VoiceOver announcement as its own element, leaving the menu independently
/// reachable.
struct CircularTimerView: View {

  /// The presenter supplying progress, the readout, and the ring's accessibility value.
  var presenter: TimerPresenter

  private let ringDiameter: CGFloat = 180
  private let strokeWidth: CGFloat = 10

  var body: some View {
    ZStack {
      TimerRing(progress: presenter.progress, diameter: ringDiameter, strokeWidth: strokeWidth)
        .accessibilityElement()
        .accessibilityLabel(AppLabels.Accessibility.timer)
        .accessibilityValue(presenter.accessibilityValue)
      FocusPresetReadout(presenter: presenter, hidesPlainReadoutFromAccessibility: true)
    }
    .accessibilityElement(children: .contain)
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
  }
}
