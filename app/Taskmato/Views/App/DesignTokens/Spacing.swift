//
//  Spacing.swift
//  Taskmato
//

import SwiftUI

extension CGFloat {

  /// Tight gap between a title and the metadata directly under it.
  static let stackTight: CGFloat = 2

  /// Vertical padding around a task row in a list.
  static let rowVertical: CGFloat = 4

  /// Gap between an icon and its adjacent label.
  static let iconLabel: CGFloat = 6

  /// Standard gap between sibling elements within a group.
  static let contentGap: CGFloat = 8

  /// Interior padding of a card.
  static let cardPadding: CGFloat = 10

  /// Gap between grouped items or grid cells; one step looser than `contentGap`.
  static let groupGap: CGFloat = 12

  /// Gap between distinct sections of content.
  static let sectionGap: CGFloat = 16

  /// Padding between content and the edge of a screen, sheet, or popover.
  static let screenPadding: CGFloat = 24

  /// Width of the accent ring around a selected card. Reminders measures 1.5pt; 2pt fills the
  /// slot ``TaskCardView`` already reserves, so selection does not shift layout.
  static let selectionRing: CGFloat = 2

  /// Width of a card's resting border.
  static let cardHairline: CGFloat = 1
}
