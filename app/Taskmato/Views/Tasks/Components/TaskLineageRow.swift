//
//  TaskLineageRow.swift
//  Taskmato
//

import SwiftUI

/// The provenance breadcrumb shared by ``TaskRowView`` and ``TaskCardView``.
///
/// Shows the provider icon (when multiple providers are enabled) followed by the most specific
/// context label, separated by a chevron. Host views gate visibility on
/// ``TaskItemPresenter/displayLineage`` so this view always has something to show.
struct TaskLineageRow: View {

  let lineage: TaskLineage

  var body: some View {
    HStack(spacing: .iconLabel) {
      if let icon = lineage.providerIcon {
        Image(systemName: icon)
      }
      if let context = lineage.contextLabel {
        if lineage.providerIcon != nil {
          Image(systemName: "chevron.right")
        }
        Text(context)
      }
    }
    .font(.taskLineage)
    .foregroundStyle(.tertiary)
  }
}
