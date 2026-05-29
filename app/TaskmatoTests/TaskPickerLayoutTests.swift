//
//  TaskPickerLayoutTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

struct TaskPickerLayoutTests {

  private func makeSettings() -> AppSettings {
    AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
  }

  @Test func defaultLayoutIsGrid() {
    #expect(makeSettings().taskPickerLayout == .grid)
  }

  @Test func layoutPersistsAcrossInstances() {
    let suite = UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let writer = AppSettings(defaults: defaults)
    writer.taskPickerLayout = .list

    let reader = AppSettings(defaults: defaults)
    #expect(reader.taskPickerLayout == .list)
  }

  @Test func allRawValuesRoundTrip() {
    for layout in TaskPickerLayout.allCases {
      #expect(TaskPickerLayout(rawValue: layout.rawValue) == layout)
    }
  }
}
