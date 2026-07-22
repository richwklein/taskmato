//
//  Palette.swift
//  Taskmato
//

import SwiftUI

extension Color {

  /// Due date that has reached or passed its urgency threshold.
  static let dueUrgent: Color = .red

  /// Accent tint for elevated-priority tasks (medium and above).
  static let priorityHigh: Color = .orange

  /// Default tint for tasks without elevated priority.
  static let priorityNeutral: Color = .primary

  /// Unfilled portion of the circular timer ring.
  static let timerRingTrack: Color = .secondary.opacity(.muted)

  /// Fill behind a card surface to lift it off the background.
  static let cardSurface: Color = .secondary.opacity(.subtle)

  /// Marker on the provider's default (favorite) list.
  static let favoriteStar: Color = .yellow

  /// Error or warning indicator (permission failure, validation).
  static let statusError: Color = .red

  /// Success or authorized-state indicator.
  static let statusSuccess: Color = .green

  /// Ordered colors assigned to slices/series in stats charts.
  static let chartPalette: [Color] = [
    .blue, .green, .orange, .purple, .red, .teal, .indigo, .pink,
  ]
}
