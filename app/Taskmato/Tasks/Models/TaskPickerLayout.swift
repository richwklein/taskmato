//
//  TaskPickerLayout.swift
//  Taskmato
//

/// The display mode for the task picker.
enum TaskPickerLayout: String, CaseIterable, Sendable {

  /// Tasks displayed as a single-column scrolling list.
  case list

  /// Tasks displayed as an adaptive multi-column card grid.
  case grid
}
