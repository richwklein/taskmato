//
//  RemindersProvider+Configuration.swift
//  Taskmato
//

import SwiftUI

extension RemindersProvider: ConfigurableTaskProvider {
  func configurationView() -> AnyView {
    AnyView(RemindersSetupSheet(provider: self))
  }
}
