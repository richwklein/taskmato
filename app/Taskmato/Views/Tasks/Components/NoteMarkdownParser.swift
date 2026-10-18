//
//  NoteMarkdownParser.swift
//  Taskmato
//

import SwiftUI

/// Converts a task note into displayable ``NoteBlock``s.
nonisolated enum NoteMarkdownParser {

  /// Parses `text` uncached into leaf blocks.
  fileprivate static func parse(_ text: String, format: ContentFormat) -> [NoteBlock] {
    let plain = text.isEmpty ? [] : [NoteBlock(content: .paragraph(AttributedString(text)))]
    guard format == .markdown else { return plain }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .full,
      failurePolicy: .returnPartiallyParsedIfPossible
    )
    guard let parsed = try? AttributedString(markdown: text, options: options) else { return plain }

    var walker = NoteBlockWalker()
    for (intent, range) in parsed.runs[\.presentationIntent] {
      if let intent {
        walker.visit(intent.components, parsed[range])
      } else {
        walker.visitBlockHTML(String(parsed[range].characters))
      }
    }
    return walker.finish()
  }
}

extension NoteMarkdownParser {

  /// Parses `text` per `format` into leaf blocks with their enclosing containers.
  ///
  /// Results are cached by format and text so list rendering does not re-parse on every `body`
  /// evaluation. A note with nothing visible, such as one made only of comments, yields `[]`.
  static func blocks(for text: String, format: ContentFormat) -> [NoteBlock] {
    let key = "\(format == .markdown ? "m" : "p"):\(text)" as NSString
    if let cached = cache.object(forKey: key) { return cached.blocks }
    let blocks = parse(text, format: format)
    cache.setObject(Box(blocks), forKey: key)
    return blocks
  }

  /// Boxes parsed blocks for storage in `NSCache`, which requires class-typed values.
  private final class Box {
    let blocks: [NoteBlock]
    init(_ blocks: [NoteBlock]) { self.blocks = blocks }
  }

  /// Thread-safe by construction (`NSCache`), so no additional isolation is needed here.
  private static let cache: NSCache<NSString, Box> = {
    let cache = NSCache<NSString, Box>()
    cache.countLimit = 200
    return cache
  }()
}

// MARK: - Inline normalization

/// Rewrites parsed inline content into what notes display.
nonisolated enum NoteInline {

  /// Applies soft-break, image, and inline-HTML normalization, then underlines links.
  ///
  /// Each pass collects ranges first and replaces in reverse so earlier indices stay valid.
  static func normalized(_ input: AttributedString) -> AttributedString {
    var text = input

    let softBreaks = text.runs.filter { $0.inlinePresentationIntent?.contains(.softBreak) == true }
    for run in softBreaks.reversed() {
      text.replaceSubrange(run.range, with: AttributedString("\n"))
    }

    let images = text.runs.filter { $0.imageURL != nil }
    for run in images.reversed() {
      if run.link != nil {
        text[run.range].imageURL = nil
      } else {
        let alt = String(text[run.range].characters)
        text.replaceSubrange(
          run.range, with: imageLink(alt: alt, source: run.imageURL) ?? AttributedString())
      }
    }

    let html = text.runs.filter { $0.inlinePresentationIntent?.contains(.inlineHTML) == true }
    for run in html.reversed() {
      var replacement = AttributedString()
      for token in HTMLToken.tokens(in: String(text[run.range].characters)) {
        switch token {
        case .text(let string): replacement.append(AttributedString(string))
        case .comment: break
        case .tag(let tag):
          if tag.name == "br" {
            replacement.append(AttributedString("\n"))
          } else if tag.name == "img", !tag.isClosing, let link = tag.imageLink() {
            replacement.append(link)
          }
        }
      }
      text.replaceSubrange(run.range, with: replacement)
    }

    return text.underliningLinks()
  }

  /// Builds the link (or plain text) that stands in for an image.
  ///
  /// Only `http`/`https` sources link. A missing or generic alt reads ``AppLabels/Notes/viewImage``
  /// when linked and yields `nil` otherwise.
  static func imageLink(alt: String?, source: URL?) -> AttributedString? {
    let cleaned = (alt ?? "")
      .replacingOccurrences(of: "\u{FFFC}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let isGeneric = cleaned.isEmpty || cleaned.lowercased() == "image"
    let scheme = source?.scheme?.lowercased()
    guard let source, scheme == "http" || scheme == "https" else {
      return isGeneric ? nil : AttributedString(cleaned)
    }
    var link = AttributedString(isGeneric ? AppLabels.Notes.viewImage : cleaned)
    link.link = source
    return link
  }
}

extension AttributedString {

  /// A copy with every link run underlined, so the affordance survives a selection fill that
  /// resolves the accent tint to plain foreground.
  nonisolated func underliningLinks() -> AttributedString {
    var text = self
    for range in text.runs.filter({ $0.link != nil }).map(\.range) {
      text[range].underlineStyle = .single
    }
    return text
  }

  /// `true` when the text is empty or only whitespace.
  nonisolated var isBlank: Bool {
    characters.allSatisfy(\.isWhitespace)
  }
}

// MARK: - HTML tokenizing

/// A fragment of raw HTML: text, a tag, or a dropped comment.
nonisolated enum HTMLToken {
  case text(String)
  case tag(HTMLTag)
  case comment

  /// Splits `html` into tokens; a `<` not starting a tag or comment stays text.
  static func tokens(in html: String) -> [HTMLToken] {
    var tokens: [HTMLToken] = []
    var rest = html[...]
    var text = ""
    func flushText() {
      if !text.isEmpty { tokens.append(.text(text)) }
      text = ""
    }
    while let open = rest.firstIndex(of: "<") {
      text += rest[..<open]
      let tail = rest[open...]
      if tail.hasPrefix("<!--") {
        flushText()
        if let close = tail.range(of: "-->") {
          rest = tail[close.upperBound...]
        } else {
          rest = ""
        }
        tokens.append(.comment)
        continue
      }
      let next = tail.dropFirst().first
      guard let next, next.isLetter || next == "/",
        let close = tail.firstIndex(of: ">")
      else {
        text += "<"
        rest = tail.dropFirst()
        continue
      }
      flushText()
      tokens.append(.tag(HTMLTag(String(tail[...close]))))
      rest = tail[tail.index(after: close)...]
    }
    text += rest
    flushText()
    return tokens
  }
}

/// A single HTML tag with just enough parsing to find its name and image attributes.
nonisolated struct HTMLTag {

  /// The full tag text including angle brackets.
  let source: String

  init(_ source: String) { self.source = source }

  /// `true` for `</name>`.
  var isClosing: Bool { source.hasPrefix("</") }

  /// The lowercased tag name.
  var name: String {
    String(
      source.drop(while: { $0 == "<" || $0 == "/" })
        .prefix(while: { $0.isLetter || $0.isNumber })
    ).lowercased()
  }

  /// The value of attribute `attribute` in either quote style, if present.
  func attribute(_ attribute: String) -> String? {
    let pattern = "(?<![\\w-])\(attribute)\\s*=\\s*(\"[^\"]*\"|'[^']*')"
    guard let match = source.range(of: pattern, options: [.regularExpression, .caseInsensitive])
    else { return nil }
    let value = source[match].drop(while: { $0 != "=" }).dropFirst()
      .trimmingCharacters(in: .whitespaces)
    return String(value.dropFirst().dropLast())
  }

  /// The stand-in link for an `<img>` tag, or `nil` when it has nothing to show.
  func imageLink() -> AttributedString? {
    let url = attribute("src").flatMap { URL(string: $0) }
    return NoteInline.imageLink(alt: attribute("alt"), source: url)
  }
}
