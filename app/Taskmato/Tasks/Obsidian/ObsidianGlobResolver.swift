//
//  ObsidianGlobResolver.swift
//  Taskmato
//

import Foundation

/// Expands date-template variables in a glob pattern using a reference date.
///
/// Supported variables (all zero-padded to fixed width):
/// - `{week}`  — ISO week number, 2 digits (e.g. `"08"`, `"18"`)
/// - `{year}`  — ISO week-based year, 4 digits (e.g. `"2026"`)
/// - `{month}` — calendar month, 2 digits (e.g. `"05"`)
/// - `{day}`   — calendar day of month, 2 digits (e.g. `"12"`)
///
/// Patterns without template variables are returned unchanged.
struct ObsidianGlobResolver {

  /// Returns `pattern` with all template variables replaced using `date`.
  ///
  /// - Parameters:
  ///   - pattern: A glob pattern string optionally containing `{week}`, `{year}`,
  ///     `{month}`, or `{day}` placeholders.
  ///   - date: The date to evaluate variables against. Defaults to the current date.
  func resolve(_ pattern: String, date: Date = Date()) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let comps = calendar.dateComponents(
      [.weekOfYear, .yearForWeekOfYear, .month, .day], from: date)

    let week = String(format: "%02d", comps.weekOfYear ?? 0)
    let year = String(format: "%04d", comps.yearForWeekOfYear ?? 0)
    let month = String(format: "%02d", comps.month ?? 0)
    let day = String(format: "%02d", comps.day ?? 0)

    return
      pattern
      .replacingOccurrences(of: "{week}", with: week)
      .replacingOccurrences(of: "{year}", with: year)
      .replacingOccurrences(of: "{month}", with: month)
      .replacingOccurrences(of: "{day}", with: day)
  }
}
