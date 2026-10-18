//
//  TaskNoteView.swift
//  Taskmato
//

import SwiftUI

/// Renders task notes using the format declared by the containing ``TaskItem``.
///
/// Markdown notes render as blocks — headings, lists, task checkboxes, quotes, code, and
/// rules — with raw HTML stripped and images shown as links. Plain-text notes render verbatim.
struct TaskNoteView: View {

  let notes: String
  let format: ContentFormat

  /// Set by `List` on an emphasized selected row, where an accent-tinted inline link would sit
  /// blue on blue.
  @Environment(\.backgroundProminence) private var prominence

  var body: some View {
    NoteBlocksView(blocks: NoteMarkdownParser.blocks(for: notes, format: format))
      .font(.caption)
      .foregroundStyle(.secondary)
      .tint(prominence.accent(.accentColor, increasedColor: .secondary))
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
