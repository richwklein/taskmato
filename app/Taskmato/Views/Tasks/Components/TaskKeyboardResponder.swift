//
//  TaskKeyboardResponder.swift
//  Taskmato
//

import AppKit
import SwiftUI

/// Invisible AppKit first-responder bridge for task selection keyboard and clipboard commands.
///
/// SwiftUI task content can lose explicit focus while preserving selection, so this zero-size view
/// receives Return, Delete, arrow, and pasteboard commands without drawing a focus ring.
struct TaskKeyboardResponder: NSViewRepresentable {

  /// Incrementing value that requests first-responder focus when it changes.
  let focusToken: Int
  /// Activates the selected task.
  var onReturn: () -> Void
  /// Requests deletion for the selected task.
  var onDelete: () -> Void
  /// Moves the task selection.
  var onMove: (MoveCommandDirection) -> Void
  /// Copies the selected task to the pasteboard.
  var onCopy: () -> Void
  /// Cuts the selected task to the pasteboard.
  var onCut: () -> Void
  /// Pastes the current pasteboard into the selected task scope.
  var onPaste: () -> Void
  /// Whether Copy is currently available.
  var canCopy: () -> Bool
  /// Whether Cut is currently available.
  var canCut: () -> Bool
  /// Whether Paste is currently available.
  var canPaste: () -> Bool
  /// Whether Delete is currently available.
  var canDelete: () -> Bool
  /// Reports whether the task content owns keyboard focus.
  var onFocusChange: (Bool) -> Void

  func makeNSView(context: Context) -> KeyboardView {
    KeyboardView()
  }

  func updateNSView(_ nsView: KeyboardView, context: Context) {
    nsView.onReturn = onReturn
    nsView.onDelete = onDelete
    nsView.onMove = onMove
    nsView.onCopy = onCopy
    nsView.onCut = onCut
    nsView.onPaste = onPaste
    nsView.canCopy = canCopy
    nsView.canCut = canCut
    nsView.canPaste = canPaste
    nsView.canDelete = canDelete
    nsView.onFocusChange = onFocusChange

    guard nsView.focusToken != focusToken else { return }
    nsView.focusToken = focusToken
    DispatchQueue.main.async {
      nsView.window?.makeFirstResponder(nsView)
    }
  }

  /// Cancels the pending focus reconciliation so it cannot outlive the view it reports for.
  static func dismantleNSView(_ nsView: KeyboardView, coordinator: ()) {
    nsView.cancelFocusReconciliation()
  }

  /// First-responder view that forwards task-scope commands into SwiftUI state.
  final class KeyboardView: NSView, NSUserInterfaceValidations {

    var focusToken = 0
    var onReturn: () -> Void = {}
    var onDelete: () -> Void = {}
    var onMove: (MoveCommandDirection) -> Void = { _ in }
    var onCopy: () -> Void = {}
    var onCut: () -> Void = {}
    var onPaste: () -> Void = {}
    var canCopy: () -> Bool = { false }
    var canCut: () -> Bool = { false }
    var canPaste: () -> Bool = { false }
    var canDelete: () -> Bool = { false }
    var onFocusChange: (Bool) -> Void = { _ in }

    override var acceptsFirstResponder: Bool { true }

    /// Pending reconciliation of a resign against where focus actually landed.
    private var focusReconciliation: Task<Void, Never>?

    override func becomeFirstResponder() -> Bool {
      cancelFocusReconciliation()
      onFocusChange(true)
      return true
    }

    /// Defers the focus report rather than announcing a loss outright.
    ///
    /// A mouse click in the list hands first responder to the `List`'s backing table on
    /// mouse-down and only returns it here on mouse-up, so reporting `false` immediately
    /// flashes the selection through its unfocused styling for the length of the click. The
    /// table is task content too, so this resolves on the next turn — once AppKit has installed
    /// the new responder — and reports a loss only when focus genuinely left the task content.
    override func resignFirstResponder() -> Bool {
      focusReconciliation?.cancel()
      focusReconciliation = Task { @MainActor [weak self] in
        await Task.yield()
        guard let self, !Task.isCancelled else { return }
        self.focusReconciliation = nil
        self.onFocusChange(self.focusRemainsInTaskContent)
      }
      return true
    }

    /// Drops any pending reconciliation, so a resolved or torn-down focus never reports late.
    func cancelFocusReconciliation() {
      focusReconciliation?.cancel()
      focusReconciliation = nil
    }

    /// Whether the window's current first responder still sits inside the task content.
    ///
    /// Walks a bounded stretch of ancestors rather than testing one fixed container, because the
    /// depth between this overlay and the sibling subtree holding the list is a SwiftUI
    /// implementation detail. The walk stops short of the window's content view so that focus
    /// moving to the sidebar — which shares only that top-level ancestor — still reads as a loss.
    private var focusRemainsInTaskContent: Bool {
      guard let responder = window?.firstResponder as? NSView else { return false }
      guard responder !== self else { return true }
      var ancestor = superview
      var depth = 0
      while let current = ancestor, depth < 4, current !== window?.contentView {
        if responder.isDescendant(of: current) { return true }
        ancestor = current.superview
        depth += 1
      }
      return false
    }

    override func keyDown(with event: NSEvent) {
      let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      if flags == .command {
        switch event.charactersIgnoringModifiers {
        case "c" where canCopy():
          onCopy()
        case "x" where canCut():
          onCut()
        case "v" where canPaste():
          onPaste()
        default:
          handleNonClipboardKey(event)
        }
      } else {
        handleNonClipboardKey(event)
      }
    }

    @objc func copy(_ sender: Any?) {
      guard canCopy() else { return }
      onCopy()
    }

    @objc func cut(_ sender: Any?) {
      guard canCut() else { return }
      onCut()
    }

    @objc func paste(_ sender: Any?) {
      guard canPaste() else { return }
      onPaste()
    }

    @objc func delete(_ sender: Any?) {
      guard canDelete() else { return }
      onDelete()
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
      switch item.action {
      case #selector(copy(_:)):
        canCopy()
      case #selector(cut(_:)):
        canCut()
      case #selector(paste(_:)):
        canPaste()
      case #selector(delete(_:)):
        canDelete()
      default:
        true
      }
    }

    private func handleNonClipboardKey(_ event: NSEvent) {
      switch event.keyCode {
      case 36:
        onReturn()
      case 51, 117:
        if canDelete() { onDelete() }
      case 123, 126:
        onMove(.left)
      case 124, 125:
        onMove(.right)
      default:
        super.keyDown(with: event)
      }
    }
  }
}
