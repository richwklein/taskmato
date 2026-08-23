//
//  BackgroundProminence+Accent.swift
//  Taskmato
//

import SwiftUI

extension BackgroundProminence {

  /// `color` where the enclosing background allows it, or a semantic equivalent where a
  /// saturated fill would swallow it.
  ///
  /// `List` publishes `.increased` on an emphasized selected row. Semantic colors — `.primary`,
  /// `.secondary`, `.tertiary` — already invert there, but an explicit color does not: a red
  /// overdue date or an accent-blue state button stays its own hue on the accent fill and stops
  /// reading (issue #578). Falling back to `.primary` keeps such content at full strength while
  /// letting the platform pick the color that contrasts with its own selection background.
  ///
  /// Meaning does not depend on the hue: priority carries a distinct glyph per level, and
  /// urgency stays a brightness step, since a non-urgent date renders `.secondary` beside this.
  func accent(_ color: Color) -> Color {
    self == .increased ? .primary : color
  }
}
