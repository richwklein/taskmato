//
//  AppDelegate.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit

/// Forwards URL scheme events directly to ``URLSchemeHandler`` and keeps the app alive when
/// the main window closes.
///
/// URL events are handled here rather than via `.onOpenURL` on SwiftUI views because
/// `MenuBarExtra` content is not in the main window responder chain and misses URL events
/// when the popover is collapsed.
///
/// URLs that arrive before the main window scene has mounted are held in `urlBuffer` and
/// drained by ``reportScenesReady()`` once the window reports it is ready.
final class AppDelegate: NSObject, NSApplicationDelegate {

  /// Injected by `TaskmatoApp.init()`. Called from `applicationWillFinishLaunching`,
  /// which fires before the system delivers any queued `taskmato://` Apple events —
  /// guaranteeing the handler is wired before the first URL arrives.
  var bootstrap: (() -> Void)?

  /// The URL handler wired by ``wire(urlHandler:)`` after composition completes.
  private(set) var urlHandler: URLSchemeHandler?

  /// URLs received before ``reportScenesReady()`` is called.
  private var urlBuffer: [URL] = []
  private var scenesReady = false

  func applicationWillFinishLaunching(_ notification: Notification) {
    bootstrap?()
  }

  /// Keeps the app running in the menu bar after its last window closes (design doc 0008, D6).
  ///
  /// The window-first shell treats window close as "hide", not "quit"; the Dock icon or the
  /// popover's "Open Taskmato" reopens it, and quit is ⌘Q.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    if scenesReady, let urlHandler {
      for url in urls {
        Task { @MainActor in await urlHandler.handle(url) }
      }
    } else {
      urlBuffer.append(contentsOf: urls)
    }
  }

  /// Called once when the main window scene first appears; drains any buffered URLs.
  ///
  /// Must be called from the main window's `onAppear`, after `bindOpenMainWindow` has been
  /// called on `MainNavigation`, so that URL handling can open the main window. Subsequent
  /// calls are no-ops.
  func reportScenesReady() {
    guard !scenesReady else { return }
    scenesReady = true
    let buffered = urlBuffer
    urlBuffer = []
    guard let urlHandler else { return }
    for url in buffered {
      Task { @MainActor in await urlHandler.handle(url) }
    }
  }

  /// Completes dependency injection by wiring the URL handler after composition.
  func wire(urlHandler: URLSchemeHandler) {
    self.urlHandler = urlHandler
  }
}
