//
//  ProEntitlement.swift
//  Taskmato
//

import Foundation
import Observation

/// Observable holder for the Taskmato Pro entitlement state.
///
/// The MIT core reads this type directly; the StoreKit 2 purchase backend lives under
/// `app/Taskmato/Pro/` (ADR-0012) and drives it through ``update(isPro:)``, so no core
/// file references a restricted type.
///
/// Defaults to locked. A missing or not-yet-started purchase backend must fail closed.
@Observable
@MainActor
final class ProEntitlement {

  /// Whether the single non-consumable Pro product is currently entitled.
  private(set) var isPro: Bool

  /// - Parameter isPro: Initial state. Defaults to locked.
  init(isPro: Bool = false) { self.isPro = isPro }

  /// Applies a new entitlement state observed by the purchase backend.
  func update(isPro: Bool) { self.isPro = isPro }
}
