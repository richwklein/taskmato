//
//  TaskMarkdownTitle.swift
//  Taskmato
//

import SwiftUI

/// Renders a task title with inline-only markdown when `format` is `.markdown`, or as plain text.
///
/// Used wherever a task title appears — paired with ``PriorityGlyph`` as a hanging leading
/// marker (``TaskRowView``, ``ActiveTaskView``). Pass `isCompleted` to switch
/// to secondary foreground color, `lineLimit` to cap truncation, and `font` to match the
/// surrounding surface (defaults to ``Font/taskTitle``).
struct TaskMarkdownTitle: View {

  let task: TaskItem
  var isCompleted: Bool = false
  var lineLimit: Int = 2
  var font: Font = .taskTitle
  /// When `true` the title greedily fills its container so trailing controls align to the far
  /// edge; when `false` it sizes to content (still truncating under pressure) so an adjacent
  /// element can sit snug against it, as the timer strip's inline countdown does.
  var fill: Bool = true

  /// Set by `List` on an emphasized selected row, where an accent-tinted inline link would sit
  /// blue on blue.
  @Environment(\.backgroundProminence) private var prominence

  /// The title with inline links underlined.
  ///
  /// Color alone cannot carry "this is a link": on a selected row the accent tint resolves to
  /// plain foreground so the link would read as ordinary text. The underline is unconditional
  /// so a link looks the same whether or not its row happens to be selected.
  private var title: AttributedString {
    var text = task.markdownTitle
    for range in text.runs.filter({ $0.link != nil }).map(\.range) {
      text[range].underlineStyle = .single
    }
    return text
  }

  var body: some View {
    Text(title)
      .font(font)
      .foregroundStyle(isCompleted ? .secondary : .primary)
      // Inline markdown links take the tint, not the foreground style, so they need their own
      // pass to stay legible on the selection fill.
      .tint(prominence.accent(.accentColor))
      .lineLimit(lineLimit)
      .frame(maxWidth: fill ? .infinity : nil, alignment: .leading)
      .help(task.title)
  }
}
