import Foundation
import CloudKit

@MainActor
@Observable
public final class SyncEngine {

    public private(set) var activeSessionID: UUID?
    public private(set) var activeSource: String?
    public private(set) var lastHeartbeat: Date?
    public private(set) var isStale: Bool = false

    private let cloudKit: CloudKitManager
    private let source: String // "mac" or "ios"
    private var heartbeatTimer: Timer?

    public init(source: String) {
        self.cloudKit = CloudKitManager()
        self.source = source
    }

    // MARK: - Session Lifecycle

    public func publishSessionStart(_ session: Session) async {
        do {
            try await cloudKit.saveSession(session, source: source)
            try await cloudKit.updateActiveSession(session, source: source)
            activeSessionID = session.id
            activeSource = source
            startHeartbeat(session)
        } catch {
            print("SyncEngine: failed to publish session start: \(error)")
        }
    }

    public func publishSessionUpdate(_ session: Session) async {
        do {
            try await cloudKit.updateSession(session, source: source)
            try await cloudKit.updateActiveSession(session, source: source)
        } catch {
            print("SyncEngine: failed to publish session update: \(error)")
        }
    }

    public func publishSessionStop(_ session: Session) async {
        stopHeartbeat()
        do {
            try await cloudKit.updateSession(session, source: source)
            // Clear active session by deleting the "active" record
            let recordID = CKRecord.ID(recordName: "active")
            try await cloudKit.database.deleteRecord(withID: recordID)
            activeSessionID = nil
            activeSource = nil
        } catch {
            print("SyncEngine: failed to publish session stop: \(error)")
        }
    }

    // MARK: - Remote State

    public func fetchActiveState() async {
        do {
            if let session = try await cloudKit.fetchActiveSession() {
                activeSessionID = session.id
                activeSource = session.source
                // Use session start time as a rough heartbeat proxy;
                // the heartbeat timer continuously re-saves the active record.
                let heartbeat = session.endTime ?? session.startTime
                lastHeartbeat = heartbeat
                let staleness = Date().timeIntervalSince(heartbeat)
                isStale = staleness > 120
            } else {
                activeSessionID = nil
                activeSource = nil
                lastHeartbeat = nil
                isStale = false
            }
        } catch {
            print("SyncEngine: failed to fetch active state: \(error)")
        }
    }

    public func fetchSession(by id: UUID) async -> Session? {
        do {
            return try await cloudKit.fetchSession(id: id)
        } catch {
            print("SyncEngine: failed to fetch session: \(error)")
            return nil
        }
    }

    public func updateSession(_ session: Session) async {
        do {
            try await cloudKit.updateSession(session, source: source)
        } catch {
            print("SyncEngine: failed to update session: \(error)")
        }
    }

    public func deleteSession(id: UUID) async {
        do {
            try await cloudKit.deleteSession(id: id)
        } catch {
            print("SyncEngine: failed to delete session: \(error)")
        }
    }

    public func forceStopRemoteSession() async {
        stopHeartbeat()
        do {
            let recordID = CKRecord.ID(recordName: "active")
            try await cloudKit.database.deleteRecord(withID: recordID)
            activeSessionID = nil
            activeSource = nil
        } catch {
            print("SyncEngine: failed to force stop: \(error)")
        }
    }

    // MARK: - History

    public func fetchSessions(from start: Date, to end: Date) async -> [Session] {
        do {
            let predicate = NSPredicate(
                format: "startTime >= %@ AND startTime <= %@",
                start as NSDate,
                end as NSDate
            )
            return try await cloudKit.fetchSessions(predicate: predicate)
        } catch {
            print("SyncEngine: failed to fetch sessions: \(error)")
            return []
        }
    }

    // MARK: - Category Config Sync

    public func publishCategoryConfig(_ config: CategoryConfig) async {
        do {
            let data = try JSONEncoder().encode(config)
            try await cloudKit.saveCategoryConfig(data)
        } catch {
            print("SyncEngine: failed to publish config: \(error)")
        }
    }

    public func fetchCategoryConfig() async -> CategoryConfig? {
        do {
            guard let data = try await cloudKit.fetchCategoryConfig() else { return nil }
            return try JSONDecoder().decode(CategoryConfig.self, from: data)
        } catch {
            print("SyncEngine: failed to fetch config: \(error)")
            return nil
        }
    }

    // MARK: - Subscriptions

    public func setupSubscriptions() async {
        do {
            try await cloudKit.setupSubscriptions()
        } catch {
            print("SyncEngine: failed to setup subscriptions: \(error)")
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat(_ session: Session) {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.activeSessionID != nil else { return }
                try? await self.cloudKit.updateActiveSession(session, source: self.source)
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}
