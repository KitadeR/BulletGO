import Foundation
import Testing
@testable import BulletGO

struct DeletionCascadeTests {
    @Test func removingActivityPurgesNotesAttachmentsTasksAndConnectors() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            at: EngineTestSupport.now
        )
        let other = try ItineraryItemFactory.makeActivity(
            title: "Gion",
            place: "Kyoto",
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(
            [
                .addActivity(activity, atTimelineIndex: nil),
                .addActivity(other, atTimelineIndex: nil),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        let note = ScopedNote(
            id: NoteID(),
            scope: .activity(activity.id),
            body: "Buy tickets",
            updatedAt: EngineTestSupport.now
        )
        let attachment = AttachmentRecord(
            id: AttachmentID(),
            scope: .activity(activity.id),
            fileName: "ticket.jpg",
            utType: "public.jpeg",
            relativePath: "trip/file.jpg",
            createdAt: EngineTestSupport.now
        )
        let bag = try ItineraryItemFactory.makeActivity(
            title: "Keep bag",
            place: "Kyoto",
            at: EngineTestSupport.now
        )
        _ = bag
        trip = try TripMutationApplier.apply(
            [
                .upsertNote(note),
                .addAttachment(attachment),
                .cacheConnectorEstimate(
                    ConnectorEstimate(
                        fromItem: .activity(activity.id),
                        toItem: .activity(other.id),
                        estimate: RouteEstimate(mode: .walking, durationSeconds: 600, distanceMeters: 800),
                        updatedAt: EngineTestSupport.now,
                        originFingerprint: "1",
                        destinationFingerprint: "2"
                    )
                ),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        let receipt = MutationReceiptPlanner.plan(.removeActivity(activity.id), on: trip)
        trip = try TripMutationApplier.apply(.removeActivity(activity.id), to: trip, at: EngineTestSupport.now)
        #expect(trip.activities.contains { $0.id == activity.id } == false)
        #expect(trip.notes.isEmpty)
        #expect(trip.attachments.isEmpty)
        #expect(trip.connectorEstimates.isEmpty)
        #expect(trip.timeline == [.activity(other.id)])
        guard case .restoreItineraryItem(let bundle) = receipt.inverse.first else {
            Issue.record("Expected restore receipt")
            return
        }
        trip = try TripMutationApplier.apply(.restoreItineraryItem(bundle), to: trip, at: EngineTestSupport.now)
        #expect(trip.activities.contains { $0.id == activity.id })
        #expect(trip.notes.map(\.body) == ["Buy tickets"])
        #expect(trip.attachments.map(\.fileName) == ["ticket.jpg"])
        #expect(trip.timeline.first == .activity(activity.id))
    }
}
