//
//  AppLinks.swift
//  Taskmato
//

import Foundation

/// Canonical URLs for the app's public-facing marketing site pages.
///
/// Used by Settings and the Help menu to open the same pages App Store Connect's
/// metadata points at, satisfying Guideline 5.1.1(i)'s in-app link requirement.
enum AppLinks {
  /// The public privacy policy, linked from Settings → About and Help → Privacy Policy.
  static let privacyPolicy = URL(string: "https://taskmato.com/privacy")!

  /// The public support page, linked from Settings → About and Help → Taskmato Support.
  static let support = URL(string: "https://taskmato.com/support")!
}
