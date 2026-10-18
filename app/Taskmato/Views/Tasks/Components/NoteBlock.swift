//
//  NoteBlock.swift
//  Taskmato
//

import Foundation

/// A single leaf block of a task note together with the containers that enclose it.
nonisolated struct NoteBlock: Equatable, Sendable {

  /// What the block displays.
  var content: NoteBlockContent

  /// Enclosing quotes and list items, outermost first.
  var containers: [NoteContainer] = []
}

/// The displayable content of a ``NoteBlock``.
nonisolated enum NoteBlockContent: Equatable, Sendable {

  /// A heading at the given level (1–6).
  case heading(level: Int, text: AttributedString)

  /// A run of inline text.
  case paragraph(AttributedString)

  /// Preformatted text shown verbatim.
  case code(String)

  /// One flattened table row.
  case tableRow(cells: [AttributedString], isHeader: Bool)

  /// A horizontal rule.
  case rule
}

/// A structure that encloses a ``NoteBlock``.
nonisolated enum NoteContainer: Equatable, Sendable {

  /// A list item, carrying the marker drawn beside the block.
  case listItem(NoteListMarker)

  /// A block quote.
  case quote
}

/// The marker column content for a list item.
nonisolated enum NoteListMarker: Equatable, Sendable {

  /// An unordered list bullet.
  case bullet

  /// The 1-based position within an ordered list.
  case ordinal(Int)

  /// A task-list checkbox.
  case task(isChecked: Bool)

  /// A later block inside an item whose marker was already drawn.
  case continuation
}

extension NoteBlock {

  /// The number of list items enclosing this block.
  var listDepth: Int {
    containers.filter { if case .listItem = $0 { true } else { false } }.count
  }

  /// `true` when the block is a heading.
  var isHeading: Bool {
    if case .heading = content { true } else { false }
  }

  /// `true` when the block is a table row.
  var isTableRow: Bool {
    if case .tableRow = content { true } else { false }
  }
}
