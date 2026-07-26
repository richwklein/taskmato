//
//  ErrorBannerView.swift
//  Taskmato
//

import SwiftUI

/// A top banner that surfaces the ``ErrorPresenter``'s current transient error.
///
/// Rendered at the window root above the detail column so failures from any destination —
/// task, timer, or sidebar — appear in one place. Shows nothing when the queue is empty.
struct ErrorBannerView: View {

  var presenter: ErrorPresenter

  var body: some View {
    if let error = presenter.current {
      HStack(alignment: .top, spacing: .iconLabel) {
        Image(systemName: error.severity.systemImage)
          .foregroundStyle(error.severity.tint)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: .stackTight) {
          Text(error.title)
            .font(.callout.weight(.semibold))
          if let detail = error.detail {
            Text(detail)
              .font(.taskMetadata)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: .contentGap)
        Button {
          presenter.dismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Dismiss")
        .accessibilityLabel("Dismiss")
      }
      .padding(.horizontal, .cardPadding)
      .padding(.vertical, .contentGap)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(error.severity.tint.opacity(.subtle))
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }
}

extension ErrorSeverity {

  /// The SF Symbol paired with the severity in the banner.
  fileprivate var systemImage: String {
    switch self {
    case .warning: return "exclamationmark.triangle.fill"
    case .error: return "exclamationmark.octagon.fill"
    }
  }

  /// The tint applied to the severity icon and banner background.
  fileprivate var tint: Color {
    switch self {
    case .warning: return .priorityHigh
    case .error: return .statusError
    }
  }
}

#Preview {
  let presenter = ErrorPresenter()
  presenter.present(
    TransientError(
      title: "Couldn't complete task",
      detail: "Reminders access has been revoked in System Settings.",
      severity: .error))
  return ErrorBannerView(presenter: presenter)
    .frame(width: 420)
}
