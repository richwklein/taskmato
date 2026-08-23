//
//  Palette.swift
//  Taskmato
//

import AppKit
import SwiftUI

extension Color {

  /// Due date that has reached or passed its urgency threshold.
  static let dueUrgent: Color = .red

  /// Accent tint for the single highest-priority level, distinct from the elevated band.
  static let priorityHighest: Color = .red

  /// Accent tint for elevated-priority tasks (medium and high).
  static let priorityHigh: Color = .orange

  /// Default tint for tasks without elevated priority.
  static let priorityNeutral: Color = .primary

  /// Unfilled portion of the circular timer ring.
  static let timerRingTrack: Color = .secondary.opacity(.muted)

  /// Fill behind a card surface to lift it off the background.
  ///
  /// Appearance-split: dark carries the boundary with the fill alone, light needs a heavier fill
  /// plus ``cardBorder`` because a faint dark wash on a near-white background is imperceptible.
  /// Increase Contrast deepens both.
  static let cardSurface = Color(
    nsColor: NSColor(name: "cardSurface") { appearance in
      switch appearance.paletteMatch {
      case .light: return NSColor.black.withAlphaComponent(0.08)
      case .lightHighContrast: return NSColor.black.withAlphaComponent(0.12)
      case .dark: return NSColor.white.withAlphaComponent(0.055)
      case .darkHighContrast: return NSColor.white.withAlphaComponent(0.10)
      }
    })

  /// Border drawn around a card surface, carrying the boundary where the fill cannot.
  ///
  /// Absent in dark at standard contrast, where the fill alone suffices. Increase Contrast raises
  /// both appearances past WCAG 1.4.11's 3:1 bar, which the standard values sit under by design.
  static let cardBorder = Color(
    nsColor: NSColor(name: "cardBorder") { appearance in
      switch appearance.paletteMatch {
      case .light: return .tertiaryLabelColor
      case .lightHighContrast: return NSColor.black.withAlphaComponent(0.45)
      case .dark: return .clear
      case .darkHighContrast: return NSColor.white.withAlphaComponent(0.35)
      }
    })

  /// Marker on the provider's default (favorite) list.
  static let favoriteStar: Color = .yellow

  /// Error indicator for permission failures and blocking validation.
  static let statusError: Color = .red

  /// Warning indicator for non-blocking conditions that may need attention.
  static let statusWarning: Color = .orange

  /// Success or authorized-state indicator.
  static let statusSuccess: Color = .green

  /// Ordered colors assigned to slices/series in stats charts.
  static let chartPalette: [Color] = [
    .blue, .green, .orange, .purple, .red, .teal, .indigo, .pink,
  ]
}

/// The quadrant a palette color resolves against: light or dark, at standard or Increase Contrast.
private enum PaletteMatch {

  /// Standard-contrast light appearance, including the vibrant variant.
  case light

  /// Light appearance with Increase Contrast enabled.
  case lightHighContrast

  /// Standard-contrast dark appearance, including the vibrant variant.
  case dark

  /// Dark appearance with Increase Contrast enabled.
  case darkHighContrast
}

extension NSAppearance {

  /// Resolves this appearance to the quadrant its palette values are defined for.
  fileprivate var paletteMatch: PaletteMatch {
    switch bestMatch(from: [
      .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
    ]) {
    case .darkAqua: return .dark
    case .accessibilityHighContrastAqua: return .lightHighContrast
    case .accessibilityHighContrastDarkAqua: return .darkHighContrast
    default: return .light
    }
  }
}
