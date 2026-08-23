//
//  CardBackground.swift
//  Taskmato
//

import SwiftUI

extension View {

  /// Paints the canonical card surface: the appearance-adaptive fill plus its hairline border.
  ///
  /// Used by genuine card surfaces — stat cards — not by task rows, which are plain `List` rows
  /// and take their selection appearance from the platform.
  func cardBackground() -> some View {
    self
      .background(RoundedRectangle.card.fill(Color.cardSurface))
      .overlay(
        RoundedRectangle.card.strokeBorder(Color.cardBorder, lineWidth: .cardHairline)
      )
  }
}
