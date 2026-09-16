import Foundation
import Testing
@testable import BulletGO

struct TripsQuickContextPresentationTests {
    @Test func readyLegWithNoTasksShowsDetailsOnly() throws {
        let trip = try markReady(try DomainTestSupport.sampleTrip())
        let row = try legRow(trip, at: 0)
        let snapshot = try #require(
            TripsQuickContextComposer.snapshot(
                row: row,
                trip: trip,
                catalog: try EngineTestSupport.catalog(),
                now: DomainTestSupport.timestamp
            )
        )
        #expect(snapshot.items.isEmpty)
        #expect(snapshot.heading == nil)
        #expect(snapshot.detail == .legDetail(trip.id, trip.legs[0].id))
        #expect(snapshot.title.contains("Tokyo"))
    }

    @Test func setupAppearsForIncompleteLegAndDoesNotInventNow() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let row = try legRow(trip, at: 0)
        let snapshot = try #require(
            TripsQuickContextComposer.snapshot(
                row: row,
                trip: trip,
                catalog: try EngineTestSupport.catalog(),
                now: DomainTestSupport.timestamp
            )
        )
        #expect(snapshot.items.count == 1)
        #expect(snapshot.items[0].title.key == "Continue setting this up")
        #expect(snapshot.heading?.key == "Before departure")
        #expect(snapshot.detail == .legDetail(trip.id, trip.legs[0].id))
        let detail = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(detail.mode == .setup)
        #expect(detail.cockpit == nil)
    }

    @Test func scopedTasksStayWithinTheTappedLegAndCapAtThree() throws {
        var trip = try markReady(try DomainTestSupport.sampleTrip())
        trip.tasks = [
            makeTask(ActionPurpose.captureDimensions, importance: .required, scope: trip.legs[0].id),
            makeTask(ActionPurpose.selectBookingMethod, importance: .required, scope: trip.legs[0].id),
            makeTask(ActionPurpose.reserveOversizedSeat, importance: .important, scope: trip.legs[0].id),
            makeTask(ActionPurpose.verifyReservationMeetsBaggage, importance: .optional, scope: trip.legs[0].id),
            makeTask(ActionPurpose.selectBookingMethod, importance: .required, scope: trip.legs[1].id),
        ]
        let row = try legRow(trip, at: 0)
        let snapshot = try #require(
            TripsQuickContextComposer.snapshot(
                row: row,
                trip: trip,
                catalog: try EngineTestSupport.catalog(),
                now: DomainTestSupport.timestamp
            )
        )
        #expect(snapshot.items.count == TripsQuickContextComposer.itemLimit)
        #expect(snapshot.items.allSatisfy { $0.id.hasPrefix("task-") })
        #expect(snapshot.items.contains { $0.id.contains(ActionPurpose.selectBookingMethod) })
        #expect(snapshot.items.contains { item in
            if case .taskDetail(_, let taskID) = item.destination {
                return trip.tasks.first { $0.id == taskID }?.scope == .leg(trip.legs[1].id)
            }
            return false
        } == false)
        #expect(snapshot.items.first?.why?.key == TripContentResolver.taskWhyNow(ActionPurpose.captureDimensions).key)
    }

    @Test func activityUsesBeforeYouGoAndIgnoresOtherScopes() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let activityID = trip.activities[0].id
        trip.tasks = [
            makeActivityTask("activity.check", scope: activityID),
            makeTask(ActionPurpose.captureDimensions, importance: .required, scope: trip.legs[0].id),
        ]
        let row = try #require(
            TimelineRowComposer.rows(for: trip).first { row in
                if case .activity(let id) = row.id { return id == activityID }
                return false
            }
        )
        let snapshot = try #require(
            TripsQuickContextComposer.snapshot(
                row: row,
                trip: trip,
                catalog: try EngineTestSupport.catalog(),
                now: DomainTestSupport.timestamp
            )
        )
        #expect(snapshot.heading?.key == "Before you go")
        #expect(snapshot.items.count == 1)
        #expect(snapshot.items[0].id == "task-activity.check")
        #expect(snapshot.detail == .activityDetail(trip.id, activityID))
    }

    @Test func inTripHeadingDoesNotUseStationNames() throws {
        let trip = try markReady(try DomainTestSupport.sampleTrip())
        var working = trip
        working.tasks = [makeTask(ActionPurpose.selectBookingMethod, importance: .required, scope: trip.legs[0].id)]
        let row = try legRow(working, at: 0)
        let now = try #require(
            LocalDate(year: 2026, month: 10, day: 3).date(in: TimeZone(identifier: "Asia/Tokyo") ?? .gmt)
        )
        let snapshot = try #require(
            TripsQuickContextComposer.snapshot(
                row: row,
                trip: working,
                catalog: try EngineTestSupport.catalog(),
                now: now
            )
        )
        #expect(snapshot.heading?.key == "For this journey")
        #expect(snapshot.heading?.key.contains("Tokyo") == false)
        #expect(snapshot.heading?.key.contains("Kyoto") == false)
    }
}

struct LegAccordionPresentationTests {
    @Test func setupKeepsOriginalStepNumbersAfterCompletion() throws {
        var trip = try DomainTestSupport.sampleTrip()
        try trip.updateLeg(id: trip.legs[0].id) { leg in
            leg.scheduledAt = try Slot.confirmed(
                value: try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
                source: .userStated,
                updatedAt: DomainTestSupport.timestamp
            )
        }
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let dateStep = try #require(snapshot.setup?.steps.first { $0.question.id == .legDate })
        let transportStep = try #require(snapshot.setup?.steps.first { $0.question.id == .transport })
        #expect(dateStep.kind == .completed)
        #expect(dateStep.stepNumber == 1)
        #expect(transportStep.kind == .current)
        #expect(transportStep.stepNumber == 2)
        #expect(snapshot.cockpit == nil)
    }

    @Test func cockpitOmitsLuggageAndKeepsStableNumbers() throws {
        let trip = try markReady(try DomainTestSupport.sampleTrip())
        let cockpit = LegCockpitComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let blocks = LegCockpitAccordionComposer.blocks(for: cockpit)
        #expect(blocks.map(\.id) == [.summary, .readiness])
        #expect(blocks.map(\.stepNumber) == [1, 2])
        #expect(LegCockpitAccordionComposer.initialExpandedID(for: cockpit) == .summary)
    }

    @Test func luggageGuideBecomesInitialAccordionFocus() throws {
        var trip = try markReady(try DomainTestSupport.sampleTrip())
        trip.tasks = [
            makeTask(
                ActionPurpose.captureDimensions,
                importance: .required,
                scope: trip.legs[0].id,
                relatedGuideID: .shinkansenBaggageMeasurement
            ),
        ]
        let cockpit = LegCockpitComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        let blocks = LegCockpitAccordionComposer.blocks(for: cockpit)
        #expect(blocks.contains { $0.id == .luggage })
        #expect(LegCockpitAccordionComposer.initialExpandedID(for: cockpit) == .luggage)
        let luggageNumber = try #require(blocks.first { $0.id == .luggage }?.stepNumber)
        let summaryNumber = try #require(blocks.first { $0.id == .summary }?.stepNumber)
        #expect(luggageNumber < summaryNumber)
    }

    @Test func airplaneSetupDoesNotGainShinkansenLuggage() throws {
        let trip = try PolicyScenarioSupport.trip(
            transport: .airplane,
            reservation: nil,
            baggagePresence: nil
        )
        let snapshot = LegDetailComposer.snapshot(
            trip: trip,
            leg: trip.legs[0],
            catalog: try EngineTestSupport.catalog()
        )
        #expect(snapshot.setup?.steps.contains { $0.question.id == .luggagePresence } == false)
        let numbers = snapshot.setup?.steps.map(\.stepNumber) ?? []
        #expect(numbers == Array(1...numbers.count))
    }
}

private func legRow(_ trip: Trip, at index: Int) throws -> TimelineRow {
    let id = trip.legs[index].id
    return try #require(
        TimelineRowComposer.rows(for: trip).first { row in
            if case .leg(let rowID) = row.id { return rowID == id }
            return false
        }
    )
}

private func makeTask(
    _ contentKey: String,
    importance: TaskImportance,
    scope: LegID,
    relatedGuideID: ProcedureID? = nil
) -> TripTask {
    TripTask(
        id: TaskID(),
        contentKey: contentKey,
        type: .check,
        state: .notStarted,
        importance: importance,
        relevantPhases: [.planning, .booking],
        deadline: nil,
        dependencies: [],
        evidence: .none,
        scope: .leg(scope),
        relatedActionID: nil,
        relatedPolicyID: .jrShinkansenOversizedBaggage,
        relatedGuideID: relatedGuideID,
        completionCondition: .userConfirmsDone
    )
}

private func makeActivityTask(_ contentKey: String, scope: ActivityID) -> TripTask {
    TripTask(
        id: TaskID(),
        contentKey: contentKey,
        type: .check,
        state: .notStarted,
        importance: .required,
        relevantPhases: [.planning],
        deadline: nil,
        dependencies: [],
        evidence: .none,
        scope: .activity(scope),
        relatedActionID: nil,
        relatedPolicyID: nil,
        relatedGuideID: nil,
        completionCondition: .userConfirmsDone
    )
}

private func markReady(_ trip: Trip) throws -> Trip {
    var working = trip
    let now = DomainTestSupport.timestamp
    working.legs[0].scheduledAt = try Slot.confirmed(
        value: EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
        source: .userStated,
        updatedAt: now
    )
    working.legs[0].transportMode = try Slot.confirmed(value: .shinkansen, source: .userStated, updatedAt: now)
    working.legs[0].reservation.status = try Slot.confirmed(value: .notBooked, source: .userStated, updatedAt: now)
    working.legs[0].baggagePresence = try Slot.confirmed(value: .yes, source: .userStated, updatedAt: now)
    working.legs[0].phase = .booking
    try working.validate()
    return working
}
