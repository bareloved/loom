import Foundation
import CloudKit

public final class CloudKitManager: Sendable {

    // MARK: - Record Type Constants

    public static let sessionRecordType = "CKSession"
    public static let distractionRecordType = "CKDistraction"
    public static let categoryConfigRecordType = "CKCategoryConfig"
    public static let activeSessionRecordType = "CKActiveSession"

    // MARK: - Instance Properties

    public let container: CKContainer
    public let database: CKDatabase

    // MARK: - Init

    public init(containerIdentifier: String = "iCloud.com.bareloved.Loom") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = container.privateCloudDatabase
    }

    // MARK: - Static Conversion: Session

    public static func sessionToFields(_ session: Session, source: String) -> [String: Any] {
        var fields: [String: Any] = [
            "category": session.category,
            "startTime": session.startTime,
            "source": source
        ]
        // CloudKit rejects empty arrays for new fields — only include if non-empty
        if !session.appsUsed.isEmpty {
            // New JSON format for full AppUsage (name + duration)
            if let data = try? JSONEncoder().encode(session.appsUsed) {
                fields["appsUsedData"] = data
            }
            // Legacy [String] field for backward compat with older clients
            fields["appsUsed"] = session.appNames
        }
        if let endTime = session.endTime {
            fields["endTime"] = endTime
        }
        if let intention = session.intention {
            fields["intention"] = intention
        }
        if let trackingSpanId = session.trackingSpanId {
            fields["trackingSpanId"] = trackingSpanId.uuidString
        }
        if let eventIdentifier = session.eventIdentifier {
            fields["eventIdentifier"] = eventIdentifier
        }
        return fields
    }

    public static func sessionFromFields(id: UUID, fields: [String: Any]) -> Session {
        let category = fields["category"] as? String ?? ""
        let startTime = fields["startTime"] as? Date ?? Date()
        let endTime = fields["endTime"] as? Date
        // Try new JSON format first, fall back to legacy [String]
        let appsUsed: [AppUsage]
        if let data = fields["appsUsedData"] as? Data,
           let decoded = try? JSONDecoder().decode([AppUsage].self, from: data) {
            appsUsed = decoded
        } else if let legacyApps = fields["appsUsed"] as? [String] {
            appsUsed = legacyApps.map { AppUsage(appName: $0, duration: 0) }
        } else {
            appsUsed = []
        }
        let intention = fields["intention"] as? String
        let trackingSpanIdString = fields["trackingSpanId"] as? String
        let trackingSpanId = trackingSpanIdString.flatMap { UUID(uuidString: $0) }
        let eventIdentifier = fields["eventIdentifier"] as? String
        let source = fields["source"] as? String

        return Session(
            id: id,
            category: category,
            startTime: startTime,
            endTime: endTime,
            appsUsed: appsUsed,
            intention: intention,
            trackingSpanId: trackingSpanId,
            eventIdentifier: eventIdentifier,
            source: source
        )
    }

    // MARK: - Static Conversion: Distraction

    public static func distractionToFields(_ distraction: Distraction) -> [String: Any] {
        var fields: [String: Any] = [
            "appName": distraction.appName,
            "bundleId": distraction.bundleId,
            "startTime": distraction.startTime,
            "duration": distraction.duration,
            "snoozed": distraction.snoozed
        ]
        if let url = distraction.url {
            fields["url"] = url
        }
        return fields
    }

    public static func distractionFromFields(id: UUID, fields: [String: Any]) -> Distraction {
        let appName = fields["appName"] as? String ?? ""
        let bundleId = fields["bundleId"] as? String ?? ""
        let url = fields["url"] as? String
        let startTime = fields["startTime"] as? Date ?? Date()
        let duration = fields["duration"] as? TimeInterval ?? 0
        let snoozed = fields["snoozed"] as? Bool ?? false

        return Distraction(
            id: id,
            appName: appName,
            bundleId: bundleId,
            url: url,
            startTime: startTime,
            duration: duration,
            snoozed: snoozed
        )
    }

    // MARK: - CRUD: Session

    public func saveSession(_ session: Session, source: String) async throws {
        let record = CKRecord(
            recordType: Self.sessionRecordType,
            recordID: CKRecord.ID(recordName: session.id.uuidString)
        )
        let fields = Self.sessionToFields(session, source: source)
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        _ = try await database.save(record)
    }

    public func updateSession(_ session: Session, source: String) async throws {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = try await database.record(for: recordID)
        let fields = Self.sessionToFields(session, source: source)
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        _ = try await database.save(record)
    }

    public func fetchSession(id: UUID) async throws -> Session {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = try await database.record(for: recordID)
        return Self.sessionFromRecord(record)
    }

    public func fetchSessions(predicate: NSPredicate = NSPredicate(value: true)) async throws -> [Session] {
        let query = CKQuery(recordType: Self.sessionRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        let (results, _) = try await database.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return Self.sessionFromRecord(record)
        }
    }

    public func deleteSession(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        try await database.deleteRecord(withID: recordID)
    }

    // MARK: - CRUD: Active Session

    public func updateActiveSession(_ session: Session, source: String) async throws {
        let recordID = CKRecord.ID(recordName: "active")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            let newRecord = CKRecord(
                recordType: Self.activeSessionRecordType,
                recordID: recordID
            )
            let fields = Self.sessionToFields(session, source: source)
            for (key, value) in fields {
                newRecord[key] = value as? CKRecordValue
            }
            newRecord["sessionId"] = session.id.uuidString as CKRecordValue
            _ = try await database.save(newRecord)
            return
        }
        let fields = Self.sessionToFields(session, source: source)
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        record["sessionId"] = session.id.uuidString as CKRecordValue
        _ = try await database.save(record)
    }

    public func fetchActiveSession() async throws -> Session? {
        let recordID = CKRecord.ID(recordName: "active")
        do {
            let record = try await database.record(for: recordID)
            guard let idString = record["sessionId"] as? String,
                  let id = UUID(uuidString: idString) else { return nil }
            return Self.sessionFromFields(id: id, fields: Self.fieldsFromRecord(record))
        } catch {
            return nil
        }
    }

    // MARK: - CRUD: Category Config

    public func saveCategoryConfig(_ data: Data) async throws {
        let recordID = CKRecord.ID(recordName: "current")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            let newRecord = CKRecord(
                recordType: Self.categoryConfigRecordType,
                recordID: recordID
            )
            newRecord["configData"] = data as CKRecordValue
            newRecord["updatedAt"] = Date() as CKRecordValue
            _ = try await database.save(newRecord)
            return
        }
        record["configData"] = data as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    public func fetchCategoryConfig() async throws -> Data? {
        let recordID = CKRecord.ID(recordName: "current")
        do {
            let record = try await database.record(for: recordID)
            return record["configData"] as? Data
        } catch {
            return nil
        }
    }

    // MARK: - Subscriptions

    public func setupSubscriptions() async throws {
        let sessionSubscription = CKQuerySubscription(
            recordType: Self.sessionRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "session-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let sessionNotification = CKSubscription.NotificationInfo()
        sessionNotification.shouldSendContentAvailable = true
        sessionSubscription.notificationInfo = sessionNotification

        let activeSubscription = CKQuerySubscription(
            recordType: Self.activeSessionRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "active-session-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let activeNotification = CKSubscription.NotificationInfo()
        activeNotification.shouldSendContentAvailable = true
        activeSubscription.notificationInfo = activeNotification

        let configSubscription = CKQuerySubscription(
            recordType: Self.categoryConfigRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "config-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let configNotification = CKSubscription.NotificationInfo()
        configNotification.shouldSendContentAvailable = true
        configSubscription.notificationInfo = configNotification

        _ = try await database.save(sessionSubscription)
        _ = try await database.save(activeSubscription)
        _ = try await database.save(configSubscription)
    }

    // MARK: - Private Helpers

    private static func sessionFromRecord(_ record: CKRecord) -> Session {
        let fields = fieldsFromRecord(record)
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        return sessionFromFields(id: id, fields: fields)
    }

    private static func fieldsFromRecord(_ record: CKRecord) -> [String: Any] {
        var fields: [String: Any] = [:]
        for key in record.allKeys() {
            if let value = record[key] {
                fields[key] = value
            }
        }
        return fields
    }
}
