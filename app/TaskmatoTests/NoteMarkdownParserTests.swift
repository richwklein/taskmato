//
//  NoteMarkdownParserTests.swift
//  TaskmatoTests
//

import Foundation
import SwiftUI
import Testing

@testable import Taskmato

@Suite("NoteMarkdownParser")
struct NoteMarkdownParserTests {

  // MARK: - Helpers

  private func parse(_ markdown: String) -> [NoteBlock] {
    NoteMarkdownParser.blocks(for: markdown, format: .markdown)
  }

  private func text(_ block: NoteBlock) -> String {
    switch block.content {
    case .heading(_, let text), .paragraph(let text): String(text.characters)
    case .code(let code): code
    case .tableRow(let cells, _): cells.map { String($0.characters) }.joined(separator: "|")
    case .rule: ""
    }
  }

  private func texts(_ blocks: [NoteBlock]) -> [String] { blocks.map(text) }

  private func signature(_ block: NoteBlock) -> String {
    let containers = block.containers.map { container -> String in
      switch container {
      case .quote: ">"
      case .listItem(.bullet): "•"
      case .listItem(.ordinal(let number)): "\(number)."
      case .listItem(.task(let isChecked)): isChecked ? "[x]" : "[ ]"
      case .listItem(.continuation): "…"
      }
    }
    let kind: String =
      switch block.content {
      case .heading(let level, _): "h\(level)"
      case .paragraph: "p"
      case .code: "code"
      case .tableRow(_, let isHeader): isHeader ? "th" : "tr"
      case .rule: "rule"
      }
    return (containers + [kind]).joined(separator: " ")
  }

  private func signatures(_ blocks: [NoteBlock]) -> [String] { blocks.map(signature) }

  private func paragraph(_ block: NoteBlock) -> AttributedString {
    guard case .paragraph(let text) = block.content else {
      Issue.record("expected paragraph, got \(block.content)")
      return AttributedString()
    }
    return text
  }

  private func linkRuns(_ text: AttributedString) -> [(String, URL)] {
    text.runs.compactMap { run in
      run.link.map { (String(text[run.range].characters), $0) }
    }
  }

  // MARK: - Basics

  @Test func plainTextStaysVerbatim() {
    let blocks = NoteMarkdownParser.blocks(for: "# not a heading\n- not a list", format: .plainText)
    #expect(texts(blocks) == ["# not a heading\n- not a list"])
    #expect(signatures(blocks) == ["p"])
  }

  @Test func headingsKeepTheirLevel() {
    let blocks = parse("## Two\n\n### Three")
    #expect(signatures(blocks) == ["h2", "h3"])
    #expect(texts(blocks) == ["Two", "Three"])
  }

  @Test func paragraphsSeparate() {
    let blocks = parse("one\n\ntwo")
    #expect(texts(blocks) == ["one", "two"])
  }

  @Test func orderedListOrdinals() {
    let blocks = parse("1. a\n2. b\n3. c")
    #expect(signatures(blocks) == ["1. p", "2. p", "3. p"])
  }

  @Test func nestedListHasDepthTwo() {
    let blocks = parse("- a\n  - b\n- c")
    #expect(signatures(blocks) == ["• p", "… • p", "• p"])
    #expect(blocks[1].listDepth == 2)
  }

  @Test func continuationParagraphGetsContinuationMarker() {
    let blocks = parse("- first\n\n  second")
    #expect(signatures(blocks) == ["• p", "… p"])
  }

  @Test func codeBlockIsVerbatim() {
    let blocks = parse("```\nlet x: Array<T> = **y**\n```")
    #expect(signatures(blocks) == ["code"])
    #expect(texts(blocks) == ["let x: Array<T> = **y**"])
  }

  @Test func blockQuote() {
    let blocks = parse("> quoted")
    #expect(signatures(blocks) == ["> p"])
  }

  @Test func thematicBreakBecomesRule() {
    let blocks = parse("above\n\n---\n\nbelow")
    #expect(signatures(blocks) == ["p", "rule", "p"])
  }

  @Test func tableFlattensToRows() {
    let blocks = parse("| A | B |\n| - | - |\n| 1 | 2 |\n| 3 | 4 |")
    #expect(signatures(blocks) == ["th", "tr", "tr"])
    #expect(texts(blocks) == ["A|B", "1|2", "3|4"])
  }

  @Test func inlineLinkIsLinkedAndUnderlined() throws {
    let blocks = parse("see [docs](https://example.com/docs) now")
    let text = paragraph(try #require(blocks.first))
    let run = try #require(text.runs.first { $0.link != nil })
    #expect(run.link == URL(string: "https://example.com/docs"))
    #expect(run.underlineStyle == .single)
    #expect(String(text.characters) == "see docs now")
  }

  @Test func commentOnlyBodyIsEmpty() {
    #expect(parse("<!-- nothing to see -->").isEmpty)
    #expect(parse("<!-- a -->\n\n<!-- b\nmultiline -->").isEmpty)
  }

  // MARK: - Nesting

  @Test func codeInOrderedItemIsContinuation() {
    let blocks = parse("1. one\n\n   ```\n   code\n   ```\n\n2. two")
    #expect(signatures(blocks) == ["1. p", "… code", "2. p"])
  }

  @Test func listInQuote() {
    let blocks = parse("> - item")
    #expect(signatures(blocks) == ["> • p"])
  }

  @Test func quoteInItem() {
    let blocks = parse("- item\n\n  > quoted")
    #expect(signatures(blocks) == ["• p", "… > p"])
  }

  @Test func headingInQuote() {
    let blocks = parse("> ## Title")
    #expect(signatures(blocks) == ["> h2"])
  }

  @Test func tableInItem() {
    let blocks = parse("- item\n\n  | A | B |\n  | - | - |\n  | 1 | 2 |")
    #expect(signatures(blocks) == ["• p", "… th", "… tr"])
  }

  @Test func nestedTaskChild() {
    let blocks = parse("- parent\n  - [x] child")
    #expect(signatures(blocks) == ["• p", "… [x] p"])
  }

  // MARK: - Tasks

  @Test func taskItemsStripTheirPrefix() {
    let blocks = parse("- [ ] open\n- [x] done")
    #expect(signatures(blocks) == ["[ ] p", "[x] p"])
    #expect(texts(blocks) == ["open", "done"])
  }

  @Test func orderedTaskItem() {
    let blocks = parse("1. [ ] step")
    #expect(signatures(blocks) == ["[ ] p"])
    #expect(texts(blocks) == ["step"])
  }

  @Test func markerWithoutSpaceIsNotATask() {
    let blocks = parse("- [x]done")
    #expect(signatures(blocks) == ["• p"])
    #expect(texts(blocks) == ["[x]done"])
  }

  @Test func continuationStartingWithMarkerIsNotATask() {
    let blocks = parse("- item\n\n  [x] later")
    #expect(signatures(blocks) == ["• p", "… p"])
    #expect(texts(blocks) == ["item", "[x] later"])
  }

  // MARK: - Images and HTML

  @Test(arguments: [
    "![Image](https://example.com/a.png)",
    "![image](https://example.com/a.png)",
    "![](https://example.com/a.png)",
  ])
  func genericAltReadsViewImage(markdown: String) throws {
    let text = paragraph(try #require(parse(markdown).first))
    #expect(String(text.characters) == "View Image")
    #expect(linkRuns(text).map(\.1) == [URL(string: "https://example.com/a.png")])
  }

  @Test func meaningfulAltStaysLinkedInline() {
    let text = paragraph(parse("See ![flow diagram](https://example.com/a.png) here.")[0])
    #expect(String(text.characters) == "See flow diagram here.")
    #expect(linkRuns(text).map(\.0) == ["flow diagram"])
  }

  @Test func relativeImageSourceIsPlainText() {
    let text = paragraph(parse("![diagram](images/a.png)")[0])
    #expect(String(text.characters) == "diagram")
    #expect(linkRuns(text).isEmpty)
  }

  @Test func imageInsideLinkKeepsLinkTarget() {
    let text = paragraph(parse("[![CI](badge.svg)](https://ci.example.com)")[0])
    #expect(String(text.characters) == "CI")
    #expect(linkRuns(text).map(\.1) == [URL(string: "https://ci.example.com")])
  }

  @Test func inlineImageOnNextLineJoinsParagraph() {
    let blocks = parse("Here is the bug:\n<img alt=\"Image\" src=\"https://example.com/a.png\"/>")
    #expect(blocks.count == 1)
    #expect(texts(blocks) == ["Here is the bug:\nView Image"])
    #expect(linkRuns(paragraph(blocks[0])).map(\.0) == ["View Image"])
  }

  @Test func blockImageAfterHeadingBecomesLinkParagraph() {
    let blocks = parse("### Evidence\n<img alt=\"Image\" src=\"https://example.com/a.png\" />")
    #expect(signatures(blocks) == ["h3", "p"])
    #expect(texts(blocks) == ["Evidence", "View Image"])
    #expect(linkRuns(paragraph(blocks[1])).count == 1)
    #expect(paragraph(blocks[1]).runs.allSatisfy { $0.link == nil || $0.underlineStyle == .single })
  }

  @Test func imageWithoutSourceIsDropped() {
    let blocks = parse("### Evidence\n<img alt=\"Image\" />")
    #expect(signatures(blocks) == ["h3"])
  }

  @Test func detailsTagsAreStrippedToText() {
    let blocks = parse("<details><summary>Logs</summary>\n\nbody\n\n</details>")
    #expect(texts(blocks).contains("Logs"))
    #expect(texts(blocks).contains("body"))
    #expect(!texts(blocks).contains { $0.contains("<") })
  }

  @Test func uppercaseTagAndSingleQuotesAreHandled() {
    let blocks = parse("### Evidence\n<IMG SRC='https://example.com/a.png'>")
    #expect(texts(blocks) == ["Evidence", "View Image"])
    #expect(linkRuns(paragraph(blocks[1])).map(\.1) == [URL(string: "https://example.com/a.png")])
  }

  // MARK: - Observed Foundation behavior

  @Test func softBreakBecomesNewline() {
    #expect(texts(parse("line one\nline two")) == ["line one\nline two"])
  }

  @Test func mergedInlineTagsAreSplit() {
    #expect(texts(parse("a<br><b>bold</b> c")) == ["a\nbold c"])
  }

  @Test func emptyAltImageReadsViewImage() {
    let text = paragraph(parse("![](https://example.com/a.png)")[0])
    #expect(String(text.characters) == "View Image")
    #expect(!String(text.characters).contains("\u{FFFC}"))
  }

  @Test func taskMarkerTextBecomesCheckbox() {
    #expect(signatures(parse("- [x] done")) == ["[x] p"])
    #expect(texts(parse("- [x] done")) == ["done"])
  }

  @Test func escapedTaskMarkerIsKnownFalsePositive() {
    #expect(signatures(parse("- \\[x] literal")) == ["[x] p"])
  }

  // MARK: - Fixtures

  private func fixture(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/\(name).md")
    return try String(contentsOf: url, encoding: .utf8)
  }

  @Test func feedlyBugIssueBody() throws {
    let blocks = parse(try fixture("issue-957-feedly-bug"))
    #expect(
      signatures(blocks)
        == ["h3", "p", "h3", "p", "h3", "p", "h3", "p", "h3", "p"])
    #expect(texts(blocks).last == "View Image")
  }

  @Test func articleSeriesIssueBody() throws {
    let blocks = parse(try fixture("issue-574-article-series"))
    let bullets = { (count: Int) in Array(repeating: "• p", count: count) }
    let expected: [String] =
      ["h2", "p", "p"]
      + ["h2", "p", "p"]
      + ["h2", "p", "p", "p"] + bullets(3) + ["p", "p"]
      + ["h2"] + bullets(7)
      + ["h2"] + bullets(6)
      + ["h2"] + Array(repeating: "[ ] p", count: 7)
      + ["h2"] + bullets(1)
    #expect(signatures(blocks) == expected)
    #expect(
      texts(blocks).last
        == "https://shivjm.blog/colophon/how-i-create-an-article-series-in-eleventy/")
  }
}
