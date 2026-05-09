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
}
