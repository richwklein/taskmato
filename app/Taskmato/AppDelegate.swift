//
//  AppDelegate.swift
//  Taskmato
//
//  Created by Richard Klein on 5/2/26.
//

import AppKit

/// Applies the dock icon activation policy once the application has fully launched,
/// and forwards URL scheme events directly to ``URLSchemeHandler``.
///
/// `NSApp.setActivationPolicy` must not be called during `App.init()` — the launch
/// sequence is incomplete at that point and the call traps on restart. Deferring to
/// `applicationDidFinishLaunching` is the documented safe window.
///
/// URL events are handled here rather than via `.onOpenURL` on SwiftUI views because
/// `MenuBarExtra` content is not in the main window responder chain and misses URL events
/// when the popover is collapsed.
///
/// URLs that arrive before the menu-bar scene has mounted are held in `urlBuffer` and
/// drained by ``reportScenesReady()`` once a scene reports it is ready.
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

  func applicationDidFinishLaunching(_ notification: Notification) {
    if UserDefaults.standard.bool(forKey: "showDockIcon") {
      NSApp.setActivationPolicy(.regular)
    }
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

  /// Called once when the menu-bar scene first appears; drains any buffered URLs.
  ///
  /// Must be called from the menu-bar popover's `onAppear`, after `bindOpenMainWindow`
  /// has been called on `MainNavigation`, so that URL handling can open the main window.
  /// Subsequent calls are no-ops.
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
