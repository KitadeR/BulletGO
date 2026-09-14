import Foundation
import Testing
import UniformTypeIdentifiers
@testable import BulletGO

struct SchedulePlacementTests {
    @Test func scheduledMomentMapsDateOnlyAllDayStartAndRange() throws {
        let date = try LocalDate(year: 2026, month: 10, day: 3)
        let none = try ScheduledMoment(date: date, timeZoneIdentifier: DomainTestSupport.timeZone)
        #expect(none.placement == .dateOnly(date))
        let allDay = try ScheduledMoment(date: date, timeZoneIdentifier: DomainTestSupport.timeZone, isAllDay: true)
        #expect(allDay.placement == .allDay(date))
        let start = try ScheduledMoment(
            date: date,
            time: try LocalTime(hour: 10, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        #expect(start.placement == .start(start))
        let undated = try ScheduledMoment(
            date: nil,
            time: try LocalTime(hour: 10, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        let ten = try LocalTime(hour: 10, minute: 0)
        #expect(undated.placement == .unscheduledStart(ten))
    }

    @Test func unknownSlotIsUnscheduled() throws {
        let slot = try Slot<ScheduledMoment>.unknown(updatedAt: DomainTestSupport.timestamp)
        #expect(slot.placement == .unscheduled)
    }
}

struct PlaceSearchTests {
    @Test func fakeSearchReturnsMatchingCompletionsAndManualFallback() async throws {
        let fushimi = PlaceReference(
            provider: .appleMaps,
            providerID: "poi-1",
            name: "Fushimi Inari Taisha",
            coordinate: GeoCoordinate(latitude: 34.9671, longitude: 135.7727),
            address: "Kyoto",
            category: nil
        )
        let search = FakePlaceSearch(
            completions: [
                PlaceSearchCompletion(id: "poi-1", title: "Fushimi Inari Taisha", subtitle: "Kyoto")
            ],
            places: ["poi-1": fushimi]
        )
        let results = try await search.completions(for: "fushimi")
        #expect(results.count == 1)
        let lookedUp = try await search.lookup(results[0])
        #expect(lookedUp.coordinate?.latitude == 34.9671)
        let missing = try await search.lookup(PlaceSearchCompletion(id: "missing", title: "Typed place", subtitle: ""))
        #expect(missing.provider == .manual)
        #expect(missing.name == "Typed place")
    }

    @Test func fakeRouteEstimatorIsDeterministic() async throws {
        let estimator = FakeRouteEstimator(
            result: RouteEstimate(mode: .walking, durationSeconds: 600, distanceMeters: 800)
        )
        let estimate = try await estimator.estimate(
            from: GeoCoordinate(latitude: 35, longitude: 135),
            to: GeoCoordinate(latitude: 35.01, longitude: 135.01),
            mode: .walking
        )
        #expect(estimate.durationSeconds == 600)
        #expect(estimate.distanceMeters == 800)
    }
}

struct AttachmentStoreTests {
    @Test func importAndDeleteKeepsFilesOutOfTripPayload() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BulletGO-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AttachmentStore(root: root)
        let tripID = TripID()
        let source = root.appending(path: "source.txt")
        try Data("hello".utf8).write(to: source)
        let record = try store.importFile(from: source, tripID: tripID, fileName: "note.txt", utType: .plainText)
        #expect(FileManager.default.fileExists(atPath: store.url(for: record).path))
        #expect(record.relativePath.contains(tripID.rawValue.uuidString))
        try store.delete(record)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: record).path))
    }

    @Test func expiredTrashIsRemovedOnCleanupAndRecentTrashIsKept() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BulletGO-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AttachmentStore(root: root)
        let tripID = TripID()
        let expired = try store.importData(
            Data("old".utf8),
            tripID: tripID,
            fileName: "old.txt",
            utType: .plainText,
            scope: .trip
        )
        let recent = try store.importData(
            Data("new".utf8),
            tripID: tripID,
            fileName: "new.txt",
            utType: .plainText,
            scope: .trip
        )
        try store.trash(expired)
        try store.trash(recent)
        let expiredFolder = root
            .appending(path: ".trash", directoryHint: .isDirectory)
            .appending(path: tripID.rawValue.uuidString, directoryHint: .isDirectory)
            .appending(path: expired.id.rawValue.uuidString, directoryHint: .isDirectory)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: expiredFolder.path
        )
        try store.cleanupExpiredTrash(olderThan: 24 * 60 * 60)
        try store.restore(expired)
        try store.restore(recent)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: expired).path))
        #expect(FileManager.default.fileExists(atPath: store.url(for: recent).path))
    }
}
