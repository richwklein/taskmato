//
//  TaskSourceBadge.swift
//  Taskmato
//

import SwiftUI

/// A compact, tappable source tag linking a task back to the app it came from.
///
/// Renders the provider's glyph, its name, and a trailing "opens away" arrow as a subtle
/// rounded chip wrapping a ``Link`` to the task's source URL. Shown only for tasks that carry a
/// `sourceURL` (Obsidian, Apple Reminders); ad-hoc and Local tasks omit it. The label reads as
/// provenance ("Obsidian ↗") rather than a command; the full "Open in …" phrasing lives in the
/// tooltip and VoiceOver label.
struct TaskSourceBadge: View {

  /// The provider deep link the badge opens.
  let url: URL
  /// The provider's display name shown in the chip.
  let name: String
  /// The provider's SF Symbol icon.
  let icon: String

  /// Tracks pointer hover so the chip can brighten as it's targeted.
  @State private var isHovered = false

  var body: some View {
    Link(destination: url) {
      HStack(spacing: .stackTight) {
        Image(systemName: icon)
        Text(name)
        Image(systemName: "arrow.up.forward")
          .foregroundStyle(.tertiary)
      }
      .font(.taskMetadata)
      .foregroundStyle(isHovered ? .primary : .secondary)
      .padding(.horizontal, .iconLabel)
      .padding(.vertical, .stackTight)
      .background(Color.secondary.opacity(.subtle), in: RoundedRectangle.card)
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help("Open in \(name)")
    .accessibilityLabel("Open in \(name)")
  }
}

#if DEBUG
  #Preview {
    VStack(alignment: .leading, spacing: .sectionGap) {
      TaskSourceBadge(
        url: URL(string: "obsidian://open")!, name: "Obsidian", icon: "book.closed")
      TaskSourceBadge(
        url: URL(string: "x-apple-reminderkit://")!, name: "Apple Reminders", icon: "checklist")
    }
    .padding()
    .frame(width: 360, alignment: .leading)
  }
#endif
