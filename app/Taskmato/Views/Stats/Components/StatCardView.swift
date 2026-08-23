//
//  StatCardView.swift
//  Taskmato
//

import SwiftUI

/// A compact summary card showing a single metric with an icon, value, and label.
struct StatCardView: View {

  let icon: String
  let value: String
  let label: String
  /// Optional tooltip explaining the metric; `nil` renders no tooltip.
  var help: String?

  var body: some View {
    VStack(alignment: .leading, spacing: .rowVertical) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.statValue)
      Text(label)
        .font(.statLabel)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.cardPadding)
    .cardBackground()
    .help(help ?? "")
    .accessibilityHint(help ?? "")
  }
}
