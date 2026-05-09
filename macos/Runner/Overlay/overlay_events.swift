import Foundation
import FlutterMacOS

final class OverlayEvents {
  init(binaryMessenger: FlutterBinaryMessenger) {
    api = OverlayFlutterApi(binaryMessenger: binaryMessenger)
  }

  private let api: OverlayFlutterApi

  func publishShown(session: OverlaySessionDto) {
    api.onOverlayShown(session: session) { result in
      Self.logIfNeeded(result)
    }
  }

  func publishDismissed(event: OverlayDismissedDto) {
    api.onOverlayDismissed(event: event) { result in
      Self.logIfNeeded(result)
    }
  }

  func publishFailed(code: String, message: String) {
    api.onOverlayFailed(error: OverlayErrorDto(code: code, message: message)) { result in
      Self.logIfNeeded(result)
    }
  }

  func publishDisplayTopologyChanged(displays: [DisplayTargetDto]) {
    api.onDisplayTopologyChanged(
      topology: DisplayTopologyDto(
        displays: displays,
        changedAtEpochMillis: Self.nowMillis()
      )
    ) { result in
      Self.logIfNeeded(result)
    }
  }

  private static func logIfNeeded(_ result: Result<Void, PigeonError>) {
    if case let .failure(error) = result {
      AppLogger.error("OverlayEvents", error.localizedDescription)
    }
  }

  private static func nowMillis() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }
}
