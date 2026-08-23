//
//  BackgroundProminence+Accent.swift
//  Taskmato
//

import SwiftUI

extension BackgroundProminence {

  /// `color` where the enclosing background allows it, or `increasedColor` where a saturated
  /// fill would swallow it.
  ///
  /// `List` publishes `.increased` on an emphasized selected row. Semantic colors — `.primary`,
  /// `.secondary`, `.tertiary` — already invert there, but an explicit color does not: a red
  /// overdue date or an accent-blue state button stays its own hue on the accent fill and stops
  /// reading (issue #578). Falling back to a semantic color lets the platform pick the value
  /// that contrasts with its own selection background; `.primary` is the default for full-strength
  /// accents, while secondary content can explicitly preserve its hierarchy.
  ///
  /// Meaning does not depend on the hue: priority carries a distinct glyph per level, and
  /// urgency stays a brightness step, since a non-urgent date renders `.secondary` beside this.
  /// - Parameters:
  ///   - color: The explicit color to use on a standard background.
  ///   - increasedColor: The semantic color to use on an increased-prominence background.
  func accent(_ color: Color, increasedColor: Color = .primary) -> Color {
    self == .increased ? increasedColor : color
  }
}
