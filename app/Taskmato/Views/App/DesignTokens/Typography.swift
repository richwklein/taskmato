//
//  Typography.swift
//  Taskmato
//

import SwiftUI

extension Font {

  /// Primary task title in list rows, cards, and the active-task label.
  static let taskTitle: Font = .callout

  /// Supporting metadata beneath a task title (due date, provider marks).
  static let taskMetadata: Font = .caption2

  /// Ancestor/lineage breadcrumb shown under a task; sits below metadata in emphasis.
  static let taskLineage: Font = .caption2

  /// Large monospaced countdown at the center of the timer ring.
  static let timerCountdown: Font = .system(size: 36, weight: .light, design: .monospaced)

  /// Phase label ("Focus", "Break") under the timer countdown.
  static let timerPhaseLabel: Font = .subheadline

  /// Prominent numeric value in a stat card; monospaced so digits don't jitter.
  static let statValue: Font = .title.monospacedDigit()

  /// Caption describing what a stat value represents.
  static let statLabel: Font = .caption

  /// Grouping header above a section of rows or cards.
  static let sectionHeader: Font = .subheadline.weight(.semibold)

  /// Title above a chart or stats visualization.
  static let chartTitle: Font = .headline

  /// Title at the top of a modal sheet.
  static let sheetTitle: Font = .title2.weight(.semibold)
}
