//
//  SurfaceEmphasis+Style.swift
//  Taskmato
//

import SwiftUI

extension SurfaceEmphasis {

  /// The band drawn behind a selected list row, or `.clear` when nothing is indicated.
  var bandFill: Color { showsSelection ? .selectionBand : .clear }
}

extension View {

  /// Paints the canonical card surface: resting fill plus its border.
  func cardBackground() -> some View {
    self
      .background(RoundedRectangle.card.fill(Color.cardSurface))
      .overlay(RoundedRectangle.card.strokeBorder(Color.cardBorder, lineWidth: .cardHairline))
  }
}
