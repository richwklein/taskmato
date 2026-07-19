//
//  ObsidianProvider+Configuration.swift
//  Taskmato
//

import SwiftUI

extension ObsidianProvider: ConfigurableTaskProvider {
  func configurationView() -> AnyView {
    AnyView(ObsidianSetupSheet(provider: self))
  }
}
