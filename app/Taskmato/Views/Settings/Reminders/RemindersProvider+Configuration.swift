//
//  RemindersProvider+Configuration.swift
//  Taskmato
//

import SwiftUI

extension RemindersProvider: ConfigurableTaskProvider {
  var needsConfiguration: Bool { !isAuthorized }

  func configurationView() -> AnyView {
    AnyView(RemindersSetupSheet(provider: self))
  }
}
