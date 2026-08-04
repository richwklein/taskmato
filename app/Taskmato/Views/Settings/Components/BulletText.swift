//
//  BulletText.swift
//  Taskmato
//

import SwiftUI

/// A simple bullet-point text row for use inside settings disclosure groups.
struct BulletText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    HStack(alignment: .top, spacing: .rowVertical) {
      Text("•").foregroundStyle(.secondary)
      Text(text).foregroundStyle(.secondary)
    }
    .font(.callout)
  }
}
