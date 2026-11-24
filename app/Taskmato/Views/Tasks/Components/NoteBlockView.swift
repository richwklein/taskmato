//
//  NoteBlockView.swift
//  Taskmato
//

import SwiftUI

/// Lays out parsed note blocks as a vertical stack spaced by ``spacing(before:after:)``; font
/// and color come from the caller.
struct NoteBlocksView: View {

  let blocks: [NoteBlock]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(blocks.enumerated()), id: \.offset) { offset, block in
        NoteContainedBlock(content: block.content, containers: block.containers[...])
          .padding(.top, offset > 0 ? Self.spacing(before: block, after: blocks[offset - 1]) : 0)
      }
    }
  }

  /// The gap above `block`: tight under a heading and within a list or table, wider before a
  /// heading, and a paragraph gap otherwise. Extra blank lines in the source add no space.
  static func spacing(before block: NoteBlock, after previous: NoteBlock) -> CGFloat {
    if previous.isHeading { return .rowVertical }
    if block.isHeading { return .groupGap }
    if block.listDepth > 0, previous.listDepth > 0 { return .rowVertical }
    if block.isTableRow, previous.isTableRow { return .rowVertical }
    return .contentGap
  }
}

/// Wraps a leaf block in its remaining containers, peeling the outermost one per level.
struct NoteContainedBlock: View {

  let content: NoteBlockContent
  let containers: ArraySlice<NoteContainer>

  var body: some View {
    if let outer = containers.first {
      let inner = NoteContainedBlock(content: content, containers: containers.dropFirst())
      switch outer {
      case .quote:
        inner
          .padding(.leading, .quoteRule + .iconLabel)
          .overlay(alignment: .leading) {
            Rectangle()
              .fill(Color(nsColor: .separatorColor))
              .frame(width: .quoteRule)
          }
      case .listItem(let marker):
        HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
          NoteMarkerView(marker: marker)
          inner
        }
      }
    } else {
      NoteLeafView(content: content)
    }
  }
}

/// The marker column beside a list item's first block.
private struct NoteMarkerView: View {

  let marker: NoteListMarker

  private static let width: CGFloat = 12

  var body: some View {
    switch marker {
    case .bullet:
      Text(verbatim: "•").frame(minWidth: Self.width, alignment: .leading).fixedSize()
    case .ordinal(let number):
      Text(verbatim: "\(number).").frame(minWidth: Self.width, alignment: .leading).fixedSize()
    case .task(let isChecked):
      Text(Image(systemName: isChecked ? "checkmark.square" : "square"))
        .frame(minWidth: Self.width, alignment: .leading)
        .fixedSize()
        .accessibilityLabel(
          isChecked ? AppLabels.Notes.taskCompleted : AppLabels.Notes.taskNotCompleted)
    case .continuation:
      Color.clear.frame(width: Self.width, height: 1)
    }
  }
}

/// Renders a single block's content at the caller's font and foreground style.
private struct NoteLeafView: View {

  let content: NoteBlockContent

  var body: some View {
    switch content {
    case .heading(_, let text):
      Text(text).bold().frame(maxWidth: .infinity, alignment: .leading)
    case .paragraph(let text):
      Text(text).frame(maxWidth: .infinity, alignment: .leading)
    case .code(let code):
      Text(verbatim: code).monospaced().frame(maxWidth: .infinity, alignment: .leading)
    case .tableRow(let cells, let isHeader):
      Text(joined(cells)).bold(isHeader).frame(maxWidth: .infinity, alignment: .leading)
    case .rule:
      Divider()
    }
  }

  private func joined(_ cells: [AttributedString]) -> AttributedString {
    var result = AttributedString()
    for (index, cell) in cells.enumerated() {
      if index > 0 { result.append(AttributedString(" · ")) }
      result.append(cell)
    }
    return result
  }
}
