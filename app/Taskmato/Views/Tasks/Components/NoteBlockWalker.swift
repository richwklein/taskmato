//
//  NoteBlockWalker.swift
//  Taskmato
//

import Foundation

/// Accumulates ``NoteBlock``s from parsed leaf runs, tracking list items already drawn and a
/// table row in progress.
nonisolated struct NoteBlockWalker {

  typealias Components = [PresentationIntent.IntentType]

  /// A table row collecting cells until a different row or block begins.
  private struct PendingRow {
    let identity: Int
    let isHeader: Bool
    let components: Components
    var cells: [AttributedString]
  }

  private var blocks: [NoteBlock] = []
  private var seenItems: Set<Int> = []
  private var row: PendingRow?

  /// Flushes any table row in progress and returns the accumulated blocks.
  mutating func finish() -> [NoteBlock] {
    flushRow()
    return blocks
  }

  /// Adds the leaf block described by `components` whose text is `slice`.
  mutating func visit(_ components: Components, _ slice: AttributedSubstring) {
    guard let leaf = components.first else { return }
    let text = NoteInline.normalized(AttributedString(slice))

    if case .tableCell = leaf.kind {
      addCell(text, components)
      return
    }
    flushRow()

    switch leaf.kind {
    case .header(let level):
      guard !text.isBlank else { return }
      append(.heading(level: level, text: text), components)
    case .codeBlock:
      var code = String(slice.characters)
      if code.hasSuffix("\n") { code.removeLast() }
      guard !code.isEmpty else { return }
      append(.code(code), components)
    case .thematicBreak:
      append(.rule, components)
    default:
      guard !text.isBlank else { return }
      append(.paragraph(text), components, detectsTask: true)
    }
  }

  /// Adds a block-level HTML fragment, which carries no presentation intent.
  mutating func visitBlockHTML(_ html: String) {
    flushRow()
    var pending = ""
    func flushText(into blocks: inout [NoteBlock]) {
      let trimmed = pending.trimmingCharacters(in: .whitespacesAndNewlines)
      pending = ""
      if !trimmed.isEmpty {
        blocks.append(NoteBlock(content: .paragraph(AttributedString(trimmed))))
      }
    }
    for token in HTMLToken.tokens(in: html) {
      switch token {
      case .text(let string):
        pending += string
      case .comment:
        break
      case .tag(let tag):
        if tag.name == "br" {
          pending += "\n"
        } else if tag.name == "img", !tag.isClosing {
          flushText(into: &blocks)
          if let link = tag.imageLink() {
            blocks.append(NoteBlock(content: .paragraph(link.underliningLinks())))
          }
        }
      }
    }
    flushText(into: &blocks)
  }

  private mutating func addCell(_ text: AttributedString, _ components: Components) {
    let rowComponent = components.dropFirst().first
    let identity = rowComponent?.identity ?? 0
    if row?.identity != identity {
      flushRow()
      var isHeader = false
      if case .tableHeaderRow? = rowComponent?.kind { isHeader = true }
      row = PendingRow(identity: identity, isHeader: isHeader, components: components, cells: [])
    }
    row?.cells.append(text)
  }

  private mutating func flushRow() {
    guard let pending = row else { return }
    row = nil
    guard pending.cells.contains(where: { !$0.isBlank }) else { return }
    let (containers, _) = resolveContainers(pending.components)
    blocks.append(
      NoteBlock(
        content: .tableRow(cells: pending.cells, isHeader: pending.isHeader),
        containers: containers))
  }

  private mutating func append(
    _ content: NoteBlockContent,
    _ components: Components,
    detectsTask: Bool = false
  ) {
    var content = content
    var (containers, newItem) = resolveContainers(components)
    if detectsTask, let newItem, let task = convertToTask(&content) {
      containers[newItem] = .listItem(.task(isChecked: task))
    }
    blocks.append(NoteBlock(content: content, containers: containers))
  }

  /// Strips a leading `[ ] `/`[x] ` from a paragraph, returning whether it was checked.
  private func convertToTask(_ content: inout NoteBlockContent) -> Bool? {
    guard case .paragraph(var text) = content else { return nil }
    let isChecked: Bool
    switch String(text.characters.prefix(4)) {
    case "[ ] ": isChecked = false
    case "[x] ", "[X] ": isChecked = true
    default: return nil
    }
    text.removeSubrange(text.startIndex..<text.characters.index(text.startIndex, offsetBy: 4))
    content = .paragraph(text)
    return isChecked
  }

  /// Maps the component chain outward-first to containers, returning the index of the
  /// innermost list item drawn for the first time, which is the only one that can be a task.
  private mutating func resolveContainers(_ components: Components) -> ([NoteContainer], Int?) {
    var containers: [NoteContainer] = []
    var newItem: Int?
    for index in components.indices.reversed() {
      let component = components[index]
      switch component.kind {
      case .blockQuote:
        containers.append(.quote)
      case .listItem(let ordinal):
        if seenItems.contains(component.identity) {
          containers.append(.listItem(.continuation))
          continue
        }
        seenItems.insert(component.identity)
        var isOrdered = false
        if index + 1 < components.count, case .orderedList = components[index + 1].kind {
          isOrdered = true
        }
        newItem = containers.count
        containers.append(.listItem(isOrdered ? .ordinal(ordinal) : .bullet))
      default:
        break
      }
    }
    return (containers, newItem)
  }
}
