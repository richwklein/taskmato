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

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title)
        .fontWeight(.semibold)
        .monospacedDigit()
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background.secondary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
