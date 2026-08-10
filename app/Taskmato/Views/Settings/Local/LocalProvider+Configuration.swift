//
//  LocalProvider+Configuration.swift
//  Taskmato
//

import SwiftUI

extension LocalProvider: ConfigurableTaskProvider {
  var needsConfiguration: Bool { false }

  func configurationView() -> AnyView {
    AnyView(LocalSettingsSheet(provider: self))
  }
}
