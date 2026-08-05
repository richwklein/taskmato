//
//  JSONLocalTaskRepository.swift
//  Taskmato
//

import Foundation

/// A ``LocalTaskRepository`` backed by a JSON file in Application Support.
///
/// Actor isolation serializes reads and writes off the main actor. The production file is
/// `~/Library/Application Support/Taskmato/local-tasks.json`. Failures are thrown rather than
/// logged here; ``LocalProvider`` is the sole place that logs, so a failure is reported once.
actor JSONLocalTaskRepository: LocalTaskRepository {

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// Creates a repository backed by a specific file URL. Pass a temporary path in tests.
  init(fileURL: URL) {
    self.fileURL = fileURL
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.encoder = encoder
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  /// Reads and decodes the JSON file, returning an empty store if none has been saved yet.
  /// - Throws: If the file exists but cannot be read or decoded.
  func loadAll() throws -> LocalStore {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return LocalStore(lists: [], tasks: [], defaultListID: nil)
    }
    let data = try Data(contentsOf: fileURL)
    return try decoder.decode(LocalStore.self, from: data)
  }

  /// Encodes `store` and writes it to the JSON file, overwriting any existing content.
  func save(_ store: LocalStore) throws {
    let data = try encoder.encode(store)
    try data.write(to: fileURL, options: [])
  }
}

extension JSONLocalTaskRepository {

  /// File name of the production JSON store.
  static let fileName = "local-tasks.json"

  /// The default production file URL, creating the containing directory if needed.
  static func defaultFileURL() -> URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let dir = appSupport.appendingPathComponent("Taskmato", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent(fileName)
  }
}
