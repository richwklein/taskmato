//
//  TimerSearchResultsPanel.swift
//  Taskmato
//

import SwiftUI

/// The floating panel of title-matching tasks shown under the Timer tab's toolbar search field.
///
/// Never hides the countdown ring beneath it — a transient overlay, not a settled card, so it
/// takes `.regularMaterial` rather than the opaque ``Color/cardSurface``. Every row is a `Button`
/// so VoiceOver and Full Keyboard Access can reach it; picking one calls the injected `onPick`
/// rather than `presenter.track(_:)` directly, so the host view can resign search focus at the
/// same moment (see `TimerTabView`).
struct TimerSearchResultsPanel: View {

  var presenter: TimerSearchPresenter
  /// Invoked with the picked task; the caller is responsible for tracking it and resigning
  /// search focus.
  var onPick: (TaskItem) -> Void

  private let panelWidth: CGFloat = 360
  private let maxListHeight: CGFloat = 220

  var body: some View {
    content
      .frame(width: panelWidth)
      .background(RoundedRectangle.card.fill(.regularMaterial))
      .overlay(RoundedRectangle.card.strokeBorder(Color.cardBorder, lineWidth: .cardHairline))
      .clipShape(RoundedRectangle.card)
      .shadow(radius: 8, y: 2)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(AppLabels.Accessibility.searchResults)
  }

  /// The three-state precedence: searching-with-nothing-yet, then results (stale rows stay
  /// visible during a refetch), then confirmed-empty. This order is load-bearing — reversing it
  /// flashes "No tasks match" on the first keystroke of every search, since results start empty.
  @ViewBuilder
  private var content: some View {
    if presenter.isSearching && presenter.results.isEmpty {
      statusRow(AppLabels.Search.searching, showsProgress: true)
    } else if !presenter.results.isEmpty {
      resultsList
    } else {
      statusRow(AppLabels.Search.noResults(query: presenter.query), showsProgress: false)
    }
  }

  private func statusRow(_ text: String, showsProgress: Bool) -> some View {
    HStack(spacing: .contentGap) {
      if showsProgress {
        ProgressView()
          .controlSize(.small)
      }
      Text(text)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.contentGap)
  }

  /// `LazyVStack` is load-bearing: `TaskItem.markdownTitle` re-parses on every body evaluation,
  /// so a bare `ForEach` would re-parse every match on every keystroke. The height cap sits on
  /// the `ScrollView`, not the stack, or the stack reports an unbounded ideal height and the
  /// laziness buys nothing.
  private var resultsList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(Array(presenter.results.enumerated()), id: \.element.id) { index, task in
          row(for: task, at: index)
        }
      }
    }
    .frame(maxHeight: maxListHeight)
  }

  private func row(for task: TaskItem, at index: Int) -> some View {
    Button {
      onPick(task)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: .iconLabel) {
        PriorityGlyph(priority: task.priority)
        VStack(alignment: .leading, spacing: .stackTight) {
          TaskMarkdownTitle(task: task, lineLimit: 1)
          if let lineage = presenter.lineage(for: task) {
            TaskLineageRow(lineage: lineage)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, .contentGap)
      .padding(.horizontal, .contentGap)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background(
      index == presenter.highlightedIndex
        ? RoundedRectangle(cornerRadius: .cardCornerRadius).fill(Color.accentColor.opacity(.muted))
        : nil
    )
    .onHover { isHovering in
      if isHovering { presenter.highlightedIndex = index }
    }
  }
}
