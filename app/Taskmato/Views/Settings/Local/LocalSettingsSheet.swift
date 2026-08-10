//
//  LocalSettingsSheet.swift
//  Taskmato
//

import SwiftUI

/// Configuration sheet for the built-in Local provider.
struct LocalSettingsSheet: View {

  let provider: LocalProvider
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: .groupGap) {
      Text("Configure \(provider.displayName)")
        .font(.sheetTitle)

      Text("Local tasks are stored on this Mac.")
        .foregroundStyle(.secondary)

      ProviderDefaultListSettings(provider: provider)

      HStack {
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(.screenPadding)
    .frame(minWidth: 360)
  }
}
