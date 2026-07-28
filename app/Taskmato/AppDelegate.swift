//
//  AppDelegate.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit
import os

/// Forwards URL scheme events directly to ``URLSchemeHandler`` and keeps the app alive when
/// the main window closes.
///
/// URL events are handled here rather than via `.onOpenURL` on SwiftUI views because
/// `MenuBarExtra` content is not in the main window responder chain and misses URL events
/// when the popover is collapsed.
///
/// URLs are handled immediately on arrival. `bootstrap` wires the handler from
/// `applicationWillFinishLaunching`, which the system runs before it delivers any queued
/// `taskmato://` Apple event, so the handler is always ready by the time the first URL
/// arrives — no buffering or scene-ready gating is required (design doc 0008, D5).
final class AppDelegate: NSObject, NSApplicationDelegate {

  /// Traces the `taskmato://` entry path so a dropped invocation can be localised via
  /// `log show --predicate 'subsystem == "com.taskmato"'` (issue #460).
  private let logger = Logger(subsystem: "com.taskmato", category: "URLScheme")

  /// Injected by `TaskmatoApp.init()`. Called from `applicationWillFinishLaunching`,
  /// which fires before the system delivers any queued `taskmato://` Apple events —
  /// guaranteeing the handler is wired before the first URL arrives.
  var bootstrap: (() -> Void)?

  /// The URL handler wired by ``wire(urlHandler:)`` after composition completes.
  private(set) var urlHandler: URLSchemeHandler?

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
    guard let urlHandler else {
      logger.error(
        "open: urlHandler not wired; \(urls.count, privacy: .public) url(s) dropped")
      return
    }
    for url in urls {
      logger.log("open: handling \(url.absoluteString, privacy: .public)")
      Task { @MainActor in await urlHandler.handle(url) }
    }
  }

  /// Completes dependency injection by wiring the URL handler after composition.
  func wire(urlHandler: URLSchemeHandler) {
    self.urlHandler = urlHandler
  }
}
