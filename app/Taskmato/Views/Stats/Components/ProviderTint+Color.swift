//
//  ProviderTint+Color.swift
//  Taskmato
//

import SwiftUI

extension Color {

  /// Maps a provider's semantic ``ProviderTint`` to a concrete color.
  ///
  /// The single place `ProviderTint` becomes a SwiftUI `Color`, keeping the `Tasks`
  /// layer free of SwiftUI.
  init(_ tint: ProviderTint) {
    switch tint {
    case .blue: self = .blue
    case .green: self = .green
    case .orange: self = .orange
    case .purple: self = .purple
    case .gray: self = .gray
    }
  }
}
