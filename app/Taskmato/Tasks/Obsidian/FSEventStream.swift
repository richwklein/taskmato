//
//  FSEventStream.swift
//  Taskmato
//

import CoreServices
import Foundation

/// Wraps a Swift handler closure for delivery via the FSEvents C callback.
private final class FSEventBox {
  let handler: () -> Void
  init(handler: @escaping () -> Void) { self.handler = handler }
}

/// A recursive file-system event stream backed by FSEvents.
///
/// Watches a directory and all its subdirectories. The `handler` fires on a background
/// utility queue after file-system events coalesce within the `latency` window.
/// Call `invalidate()` to stop the stream and release all resources.
final class FSEventStream {

  private var streamRef: FSEventStreamRef?

  /// Creates and starts a recursive FSEvents stream for `path`.
  ///
  /// - Parameters:
  ///   - path: Root directory to watch recursively.
  ///   - latency: Event coalescing window in seconds. Default `0.5`.
  ///   - handler: Called on a background utility queue when events arrive.
  init(path: String, latency: CFTimeInterval = 0.5, handler: @escaping () -> Void) {
    let box = FSEventBox(handler: handler)
    let retained = Unmanaged.passRetained(box)

    var context = FSEventStreamContext(
      version: 0,
      info: retained.toOpaque(),
      retain: nil,
      release: { ptr in
        guard let ptr else { return }
        Unmanaged<FSEventBox>.fromOpaque(ptr).release()
      },
      copyDescription: nil
    )

    let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
      guard let info else { return }
      Unmanaged<FSEventBox>.fromOpaque(info).takeUnretainedValue().handler()
    }

    guard
      let stream = FSEventStreamCreate(
        nil,
        callback,
        &context,
        [path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        latency,
        FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes)
      )
    else {
      retained.release()
      return
    }

    FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
    FSEventStreamStart(stream)
    streamRef = stream
  }

  /// Stops the stream, disassociates it from its dispatch queue, and releases all resources.
  func invalidate() {
    guard let stream = streamRef else { return }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    streamRef = nil
  }

  deinit { invalidate() }
}
