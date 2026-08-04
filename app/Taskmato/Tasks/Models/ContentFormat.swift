//
//  ContentFormat.swift
//  Taskmato
//

import Foundation

/// Declares how a task's `title` and `notes` strings should be interpreted for display.
nonisolated enum ContentFormat: Codable, Sendable {

  /// Plain text — rendered verbatim, no markdown interpretation.
  case plainText

  /// Markdown — rendered via `AttributedString(markdown:)` where supported.
  case markdown
}

extension ContentFormat {

  /// Renders `text` per this format: verbatim for `.plainText`, inline-Markdown-parsed for
  /// `.markdown` (falling back to plain text on parse failure). Parsed results are cached so
  /// dense list/grid rendering does not re-parse identical strings on every `body` evaluation.
  func attributedString(for text: String) -> AttributedString {
    guard self == .markdown else { return AttributedString(text) }
    let key = text as NSString
    if let cached = Self.parseCache.object(forKey: key) { return cached.value }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    let parsed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    Self.parseCache.setObject(Box(parsed), forKey: key)
    return parsed
  }

  /// Boxes an `AttributedString` for storage in `NSCache`, which requires class-typed values.
  private final class Box {
    let value: AttributedString
    init(_ value: AttributedString) { self.value = value }
  }

  /// Thread-safe by construction (`NSCache`), so no additional isolation is needed here.
  private static let parseCache: NSCache<NSString, Box> = {
    let cache = NSCache<NSString, Box>()
    cache.countLimit = 500
    return cache
  }()
}
