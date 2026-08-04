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

  var body: some View {
    Text(format.attributedString(for: notes))
      .font(.caption)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
