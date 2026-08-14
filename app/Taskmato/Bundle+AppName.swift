//
//  Bundle+AppName.swift
//  Taskmato
//

import Foundation

extension Bundle {
  /// The user-facing application name, read from the bundle's info dictionary.
  ///
  /// Prefers `CFBundleDisplayName` (localizable, can differ from the binary name),
  /// falls back to `CFBundleName`, then to an empty string if neither is present.
  var appName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? ""
  }

  /// The user-facing version number, read from `CFBundleShortVersionString`.
  ///
  /// Falls back to an empty string if the key is missing.
  var appVersion: String {
    object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }

  /// The build number, read from `CFBundleVersion`.
  ///
  /// Falls back to an empty string if the key is missing.
  var buildNumber: String {
    object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
  }
}
