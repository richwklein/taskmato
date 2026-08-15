//
//  FocusDurationTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@Suite("FocusDuration")
struct FocusDurationTests {

  /// Table-driven over the floor boundaries; `1_499`/`1_500` guards the stopped-vs-completed
  /// distinction — a phase stopped one second short of 25:00 must never read as `"25m"`.
  @Test(
    arguments: [
      (0.0, "0m"),
      (1.0, "1s"),
      (45.0, "45s"),
      (59.6, "59s"),
      (60.0, "1m"),
      (119.0, "1m"),
      (1_499.0, "24m"),
      (1_500.0, "25m"),
      (3_600.0, "1h"),
      (3_660.0, "1h 1m"),
      (5_400.0, "1h 30m"),
    ]
  )
  func labelFloorsAtEveryBoundary(seconds: TimeInterval, expected: String) {
    #expect(FocusDuration.label(seconds: seconds) == expected)
  }
}
