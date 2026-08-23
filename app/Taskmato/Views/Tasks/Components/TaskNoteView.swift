//
//  TaskNoteView.swift
//  Taskmato
//

import SwiftUI

/// Renders task notes using the format declared by the containing ``TaskItem``.
///
/// Markdown notes use `AttributedString(markdown:)` with inline-only interpretation —
/// bold, italic, code spans, and links render; headers and block-level constructs do not.
/// Falls back to plain text if markdown parsing fails.
struct TaskNoteView: View {

  let notes: String
  let format: ContentFormat

  /// Set by `List` on an emphasized selected row, where an accent-tinted inline link would sit
  /// blue on blue.
  @Environment(\.backgroundProminence) private var prominence

  /// The rendered notes with inline links underlined so their affordance survives selection.
  private var attributedNotes: AttributedString {
    var text = format.attributedString(for: notes)
    for range in text.runs.filter({ $0.link != nil }).map(\.range) {
      text[range].underlineStyle = .single
    }
    return text
  }

  var body: some View {
    Text(attributedNotes)
      .font(.caption)
      .foregroundStyle(.secondary)
      .tint(prominence.accent(.accentColor, increasedColor: .secondary))
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
