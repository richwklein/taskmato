//
//  DoubleClickCatcher.swift
//  Taskmato
//

import AppKit
import ObjectiveC
import SwiftUI

extension View {

  /// Wires the enclosing `NSTableView`'s native double-click to `action`, letting double-click
  /// activation coexist with `List(selection:)`'s single-click selection.
  ///
  /// Issue #546 (design 0012, D3/Q1): a SwiftUI `TapGesture(count: 2)` on a `List` row competes
  /// with `NSTableView`'s own click handling and makes single-click selection unreliable, and a
  /// `.background` gesture view never receives the clicks the table consumes. Using the table's
  /// native `doubleAction` sidesteps both. `action` runs against the current selection, since the
  /// first click of the double-click has already selected the row natively.
  func onTableDoubleClick(perform action: @escaping () -> Void) -> some View {
    background(TableDoubleClickInstaller(action: action))
  }
}

/// Transparent backing view that reaches up to the `List`'s `NSTableView` and installs a
/// double-click handler.
private struct TableDoubleClickInstaller: NSViewRepresentable {

  let action: () -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.attach(startingFrom: view)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.action = action
    context.coordinator.attach(startingFrom: nsView)
  }

  func makeCoordinator() -> Coordinator { Coordinator(action: action) }

  /// Long-lived double-click target; retained on the table so it survives row recycling.
  final class Coordinator: NSObject {

    var action: () -> Void

    init(action: @escaping () -> Void) { self.action = action }

    /// Walks up from `view` to the backing `NSTableView` and wires its double-click action.
    func attach(startingFrom view: NSView) {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        var candidate: NSView? = view
        while let current = candidate, !(current is NSTableView) {
          candidate = current.superview
        }
        guard let table = candidate as? NSTableView else { return }
        // `NSControl.target` is weak, so retain this coordinator on the table to outlive the
        // SwiftUI row whose background view triggered the walk-up.
        objc_setAssociatedObject(
          table, &Self.retainKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        table.target = self
        table.doubleAction = #selector(fire)
      }
    }

    @objc private func fire() { action() }

    private static var retainKey: UInt8 = 0
  }
}
