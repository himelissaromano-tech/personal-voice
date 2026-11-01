import Foundation
import OSLog

/// Correlates metadata and timing for one recording attempt. It never records
/// transcript text or PCM content.
final class RecordingDiagnostics: @unchecked Sendable {
    static let shared = RecordingDiagnostics()

    private struct Trace {
        let id: String
        let startedAtNanoseconds: UInt64
        var sequence: UInt64
    }

    private let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "RecordingDiagnostics"
    )
    private let lock = NSLock()
    private var trace: Trace?

    private init() {}

    var currentID: String? {
        lock.withLock { trace?.id }
    }

    @discardableResult
    func begin(trigger: String, details: String = "") -> String {
        let now = DispatchTime.now().uptimeNanoseconds
        let id = String(UUID().uuidString.prefix(12))
        let replacedID = lock.withLock { () -> String? in
            let previous = trace?.id
            trace = Trace(id: id, startedAtNanoseconds: now, sequence: 1)
            return previous
        }

        if let replacedID {
            logger.warning(
                "DIAG id=\(replacedID, privacy: .public) event=trace-replaced reason=new-recording-trigger"
            )
        }
        logger.notice(
            "DIAG id=\(id, privacy: .public) seq=1 elapsedMs=0.000 event=recording-trigger trigger=\(trigger, privacy: .public) details=\(details, privacy: .public)"
        )
        return id
    }

    @discardableResult
    func beginIfNeeded(trigger: String, details: String = "") -> String {
        if let currentID {
            mark("additional-start-entry", details: "trigger=\(trigger) \(details)")
            return currentID
        }
        return begin(trigger: trigger, details: details)
    }

    func mark(_ event: String, details: String = "") {
        let now = DispatchTime.now().uptimeNanoseconds
        let snapshot = lock.withLock { () -> (id: String, sequence: UInt64, startedAt: UInt64)? in
            guard var current = trace else { return nil }
            current.sequence += 1
            trace = current
            return (current.id, current.sequence, current.startedAtNanoseconds)
        }

        guard let snapshot else { return }
        let elapsedMs = Double(now - snapshot.startedAt) / 1_000_000.0
        logger.notice(
            "DIAG id=\(snapshot.id, privacy: .public) seq=\(snapshot.sequence, privacy: .public) elapsedMs=\(elapsedMs, format: .fixed(precision: 3), privacy: .public) event=\(event, privacy: .public) details=\(details, privacy: .public)"
        )
    }

    func end(expectedID: String? = nil, outcome: String, details: String = "") {
        let now = DispatchTime.now().uptimeNanoseconds
        let result = lock.withLock {
            () -> (snapshot: (id: String, sequence: UInt64, startedAt: UInt64)?, mismatch: String?) in
            guard var current = trace else { return (nil, nil) }
            if let expectedID, expectedID != current.id {
                return (nil, current.id)
            }
            current.sequence += 1
            trace = nil
            return ((current.id, current.sequence, current.startedAtNanoseconds), nil)
        }

        if let expectedID, let currentID = result.mismatch {
            logger.warning(
                "DIAG event=stale-end-ignored expectedID=\(expectedID, privacy: .public) currentID=\(currentID, privacy: .public) outcome=\(outcome, privacy: .public)"
            )
        }
        guard let snapshot = result.snapshot else { return }
        let elapsedMs = Double(now - snapshot.startedAt) / 1_000_000.0
        logger.notice(
            "DIAG id=\(snapshot.id, privacy: .public) seq=\(snapshot.sequence, privacy: .public) elapsedMs=\(elapsedMs, format: .fixed(precision: 3), privacy: .public) event=recording-diagnostic-end outcome=\(outcome, privacy: .public) details=\(details, privacy: .public)"
        )
    }
}
