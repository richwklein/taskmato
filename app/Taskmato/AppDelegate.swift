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
final class AppDelegate: NSObject, NSApplicationDelegate {

  /// Injected by `TaskmatoApp.init()`. Called from `applicationWillFinishLaunching`,
  /// which fires before the system delivers any queued `taskmato://` Apple events —
  /// guaranteeing the handler is wired before the first URL arrives.
  var bootstrap: (() -> Void)?

  /// The URL handler wired by ``wire(urlHandler:)`` after composition completes.
  private(set) var urlHandler: URLSchemeHandler?

  func applicationWillFinishLaunching(_ notification: Notification) {
    bootstrap?()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if UserDefaults.standard.bool(forKey: "showDockIcon") {
      NSApp.setActivationPolicy(.regular)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    guard let urlHandler else { return }
    for url in urls {
      Task { @MainActor in
        await urlHandler.handle(url)
      }
    }
  }

  /// Completes dependency injection by wiring the URL handler after composition.
  func wire(urlHandler: URLSchemeHandler) {
    self.urlHandler = urlHandler
  }
}
