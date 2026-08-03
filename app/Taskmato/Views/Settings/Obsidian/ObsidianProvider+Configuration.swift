//
//  ObsidianProvider+Configuration.swift
//  Taskmato
//

import SwiftUI

extension ObsidianProvider: ConfigurableTaskProvider {
  var needsConfiguration: Bool { !isConfigured }

  func configurationView() -> AnyView {
    AnyView(ObsidianSetupSheet(provider: self))
  }
}
