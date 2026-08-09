//
//  ObsidianProvider+Errors.swift
//  Taskmato
//

import Foundation

/// Validates Obsidian file-pattern date tokens before they are expanded.
enum ObsidianPatternTokens {

  /// Returns date-like brace tokens that won't be expanded by ``ObsidianProvider/expandTokens(_:now:)``.
  static func invalidDateTokens(in pattern: String) -> [String] {
    let supportedDateTokens = [
      "{year}",
      "{yyyy}",
      "{month}",
      "{mm}",
      "{week}",
      "{ww}",
      "{day}",
      "{dd}",
    ]
    let tokenPattern = /\{[^{}]*[A-Za-z][^{}]*\}/
    var invalidTokens: [String] = []

    for match in pattern.matches(of: tokenPattern) {
      let token = String(match.output)
      guard !supportedDateTokens.contains(token.lowercased()), !invalidTokens.contains(token)
      else { continue }
      invalidTokens.append(token)
    }

    return invalidTokens
  }
}

/// Errors thrown by ``ObsidianProvider`` operations.
enum ObsidianProviderError: LocalizedError {
  /// The vault directory has not been configured by the user.
  case vaultNotConfigured
  /// The `TaskRef.nativeID` does not follow the expected `path#fp=fingerprint` format.
  case invalidNativeID(String)
  /// No matching task line was found in the vault file.
  case taskNotFound(String)
  /// More than one task line matched the content fingerprint.
  case ambiguousTaskRef(String)
  /// No file matches the given vault-relative list ID.
  case listNotFound(String)
  /// No heading matching the given section text was found in the target file.
  case sectionNotFound(list: String, section: String)

  var errorDescription: String? {
    switch self {
    case .vaultNotConfigured:
      return "No Obsidian vault has been selected."
    case .invalidNativeID(let id):
      return "Invalid task reference: \"\(id)\"."
    case .taskNotFound(let id):
      return "Could not locate task \"\(id)\" in the vault."
    case .ambiguousTaskRef(let id):
      return "Could not uniquely locate task \"\(id)\" in the vault."
    case .listNotFound(let id):
      return "Could not locate list \"\(id)\" in the vault."
    case .sectionNotFound(let list, let section):
      return "Could not locate section \"\(section)\" in \"\(list)\"."
    }
  }
}
