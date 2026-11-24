//
//  NoteBlockSpacingTests.swift
//  TaskmatoTests
//

import SwiftUI
import Testing

@testable import Taskmato

@Suite("Note block spacing")
struct NoteBlockSpacingTests {

  /// The gaps between consecutive blocks of `markdown`.
  private func gaps(_ markdown: String) -> [CGFloat] {
    let blocks = NoteMarkdownParser.blocks(for: markdown, format: .markdown)
    return zip(blocks.dropFirst(), blocks).map { NoteBlocksView.spacing(before: $0, after: $1) }
  }

  @Test func paragraphsGetAParagraphGap() {
    #expect(gaps("one\n\ntwo") == [.contentGap])
  }

  @Test func extraBlankLinesCollapse() {
    #expect(gaps("one\n\n\n\ntwo") == [.contentGap])
  }

  @Test func headingGetsAWiderGapAboveAndATightOneBelow() {
    #expect(gaps("intro\n\n## Section\n\nbody") == [.groupGap, .rowVertical])
  }

  @Test func listItemsAndTheirContinuationsStayTight() {
    #expect(
      gaps("1. one\n\n   ```\n   code\n   ```\n\n2. two\n   - nested") == [
        .rowVertical, .rowVertical, .rowVertical,
      ])
  }

  @Test func blocksAroundAListGetAParagraphGap() {
    #expect(gaps("before\n\n- item\n\nafter") == [.contentGap, .contentGap])
  }

  @Test func tableRowsStayTight() {
    #expect(gaps("| A | B |\n| - | - |\n| 1 | 2 |\n\nafter") == [.rowVertical, .contentGap])
  }
}
