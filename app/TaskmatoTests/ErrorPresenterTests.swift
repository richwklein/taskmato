//
//  ErrorPresenterTests.swift
//  TaskmatoTests
//

import Foundation
import Testing

@testable import Taskmato

@MainActor
struct ErrorPresenterTests {

  /// Builds a presenter whose auto-dismiss sleep returns instantly, so timing is driven by
  /// awaiting ``ErrorPresenter/dismissTask`` rather than the wall clock. Because the type is
  /// `@MainActor`, a scheduled dismiss cannot preempt a test until it awaits.
  private func makePresenter() -> ErrorPresenter {
    ErrorPresenter(autoDismiss: .zero, sleep: { _ in })
  }

  private func error(_ title: String) -> TransientError {
    TransientError(title: title)
  }

  /// A `LocalizedError` with a fixed description for the mapping test.
  private struct SampleError: LocalizedError {
    let errorDescription: String? = "The store is unavailable."
  }

  /// A sleep primitive that returns instantly for its first `immediate` calls, then suspends
  /// indefinitely — so a chained auto-dismiss can be observed before the next one fires.
  ///
  /// The presenter invokes this from its `@MainActor` dismiss task, so the counter is only ever
  /// touched on the main actor and needs no additional synchronization.
  @MainActor
  private final class SleepController {
    private var count = 0
    let immediate: Int

    init(immediate: Int) { self.immediate = immediate }

    func sleep() async {
      count += 1
      if count > immediate { try? await Task.sleep(for: .seconds(3600)) }
    }
  }

  // MARK: - Queueing

  @Test func presentSurfacesTheError() {
    let presenter = makePresenter()
    let err = error("First")
    presenter.present(err)
    #expect(presenter.current == err)
    #expect(presenter.queue.count == 1)
  }

  @Test func secondPresentKeepsTheFirstAsCurrent() {
    let presenter = makePresenter()
    let first = error("First")
    let second = error("Second")
    presenter.present(first)
    presenter.present(second)
    #expect(presenter.current == first)
    #expect(presenter.queue.count == 2)
  }

  @Test func presentMapsCaughtErrorIntoDetail() {
    let presenter = makePresenter()
    presenter.present(title: "Couldn't save", error: SampleError())
    #expect(presenter.current?.title == "Couldn't save")
    #expect(presenter.current?.detail == "The store is unavailable.")
    #expect(presenter.current?.severity == .error)
  }

  // MARK: - Manual dismissal

  @Test func dismissAdvancesToTheNextError() {
    let presenter = makePresenter()
    let first = error("First")
    let second = error("Second")
    presenter.present(first)
    presenter.present(second)
    presenter.dismiss()
    #expect(presenter.current == second)
    #expect(presenter.queue.count == 1)
  }

  @Test func dismissOnEmptyQueueIsANoop() {
    let presenter = makePresenter()
    presenter.dismiss()
    #expect(presenter.current == nil)
    #expect(presenter.queue.isEmpty)
  }

  // MARK: - Auto-dismiss

  @Test func autoDismissClearsTheCurrentError() async {
    let presenter = makePresenter()
    presenter.present(error("First"))
    await presenter.dismissTask?.value
    #expect(presenter.current == nil)
    #expect(presenter.queue.isEmpty)
  }

  @Test func autoDismissAdvancesToTheNextError() async {
    // Only the first dismissal fires; the second stays parked so the advance is observable.
    let controller = SleepController(immediate: 1)
    let presenter = ErrorPresenter(autoDismiss: .zero, sleep: { _ in await controller.sleep() })
    let first = error("First")
    let second = error("Second")
    presenter.present(first)
    presenter.present(second)
    await presenter.dismissTask?.value
    #expect(presenter.current == second)
    #expect(presenter.queue.count == 1)
  }

  // MARK: - attempt

  @Test func attemptReturnsTrueOnSuccessWithoutQueueingAnError() async {
    let presenter = makePresenter()
    let succeeded = await presenter.attempt("Couldn't save") {}
    #expect(succeeded)
    #expect(presenter.queue.isEmpty)
  }

  @Test func attemptReturnsFalseAndQueuesAnErrorOnThrow() async {
    let presenter = makePresenter()
    let succeeded = await presenter.attempt("Couldn't save") { throw SampleError() }
    #expect(!succeeded)
    #expect(presenter.current?.title == "Couldn't save")
    #expect(presenter.current?.detail == "The store is unavailable.")
  }
}
