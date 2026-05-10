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
  let format: NoteFormat

  var body: some View {
    Group {
      switch format {
      case .plainText:
        Text(notes)
      case .markdown:
        Text(attributedNotes)
      }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var attributedNotes: AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: notes, options: options)) ?? AttributedString(notes)
  }
}
