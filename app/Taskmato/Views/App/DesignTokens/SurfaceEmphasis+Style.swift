//
//  SurfaceEmphasis+Style.swift
//  Taskmato
//

import SwiftUI

extension SurfaceEmphasis {

  /// The band drawn behind a selected list row, or `.clear` when nothing is indicated.
  var bandFill: Color { showsSelection ? .selectionBand : .clear }

  /// The border drawn around a card: the accent ring when selected, else the resting border.
  var cardStroke: Color { showsSelection ? .accentColor : .cardBorder }

  /// The card border's width — the ring reads heavier than the resting hairline.
  var cardStrokeWidth: CGFloat { showsSelection ? .selectionRing : .cardHairline }
}

extension View {

  /// Paints the canonical card surface: resting fill plus the border or selection ring.
  func cardBackground(_ emphasis: SurfaceEmphasis = .normal) -> some View {
    self
      .background(RoundedRectangle.card.fill(Color.cardSurface))
      .overlay(
        RoundedRectangle.card.strokeBorder(emphasis.cardStroke, lineWidth: emphasis.cardStrokeWidth)
      )
  }
}
