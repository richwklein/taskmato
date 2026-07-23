//
//  ProviderEntitlement.swift
//  Taskmato
//

import Foundation

/// Declares whether a task provider is available for free or requires a StoreKit purchase.
///
/// The full StoreKit 2 implementation lands in the Monetization track (P7).
/// This stub allows providers to declare their entitlement now so `ProviderRegistry`
/// can gate access consistently from the start.
enum ProviderEntitlement: Equatable, Sendable {

  /// Available to all users at no cost.
  case free

  /// Requires a one-time in-app purchase identified by `productID`.
  case paid(productID: String)
}
