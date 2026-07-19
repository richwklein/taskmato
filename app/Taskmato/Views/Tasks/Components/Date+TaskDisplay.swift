//
//  Date+TaskDisplay.swift
//  Taskmato
//

import Foundation

extension Date {

  /// `true` when the date falls on today or is already past due.
  var isUrgentDueDate: Bool {
    Calendar.current.isDateInToday(self) || self < .now
  }
}
