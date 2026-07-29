//
//  Shape.swift
//  Taskmato
//

import SwiftUI

extension CGFloat {

  /// Corner radius for card surfaces (task cards, stat cards).
  nonisolated static let cardCornerRadius: CGFloat = 8

  /// Corner radius for chart bars and legend swatches.
  nonisolated static let barCornerRadius: CGFloat = 2
}

extension RoundedRectangle {

  /// Rounded rectangle used as the canonical card surface and clip shape.
  static var card: RoundedRectangle {
    RoundedRectangle(cornerRadius: .cardCornerRadius)
  }
}
