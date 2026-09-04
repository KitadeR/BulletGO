import Foundation
import Testing
@testable import BulletGO

struct ContextualHomePresentationTests {
    @Test func tripPhaseIsBeforeTripBeforeStartDate() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let today = try LocalDate(year: 2026, month: 9, day: 4)
        #expect(TripPhaseResolver.resolve(trip: trip, today: today) == .beforeTrip)
        let snapshot = ContextualHomeComposer.snapshot(
            for: trip,
            catalog: nil,
            now: try tokyoDate(today)
        )
        #expect(snapshot.tripPhase == .beforeTrip)
        #expect(snapshot.daysUntilStart == 27)
    }

    @Test func tripPhaseIsInTripOnStartAndEndDates() throws {
        let trip = try DomainTestSupport.sampleTrip()
        #expect(TripPhaseResolver.resolve(trip: trip, today: try LocalDate(year: 2026, month: 10, day: 1)) == .inTrip)
        #expect(TripPhaseResolver.resolve(trip: trip, today: try LocalDate(year: 2026, month: 10, day: 8)) == .inTrip)
    }

    @Test func tripPhaseIsFinishedAfterEndDate() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let today = try LocalDate(year: 2026, month: 10, day: 9)
        #expect(TripPhaseResolver.resolve(trip: trip, today: today) == .finished)
        let snapshot = ContextualHomeComposer.snapshot(
            for: trip,
            catalog: try EngineTestSupport.catalog(),
            now: try tokyoDate(today)
        )
        #expect(snapshot.tripPhase == .finished)
        #expect(snapshot.primaryNow == nil)
    }

    @Test func missingDatesStayPlanning() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.startDate = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
        trip.endDate = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
        #expect(TripPhaseResolver.resolve(trip: trip, today: try LocalDate(year: 2026, month: 10, day: 1)) == .planning)
    }

    @Test func todayScheduleExtractsOnlyTodayAndKeepsUntimedNeutral() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let today = try LocalDate(year: 2026, month: 10, day: 1)
        let later = try LocalDate(year: 2026, month: 10, day: 2)
        trip.legs[0].scheduledAt = try Slot.confirmed(
            value: ScheduledMoment(
                date: today,
                time: try LocalTime(hour: 8, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.activities[0].scheduledAt = try Slot.confirmed(
            value: ScheduledMoment(date: today, timeZoneIdentifier: DomainTestSupport.timeZone),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.legs[1].scheduledAt = try Slot.confirmed(
            value: ScheduledMoment(date: later, timeZoneIdentifier: DomainTestSupport.timeZone),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        try trip.validate()

        let now = try tokyoDate(today, hour: 9)
        let rows = TodayScheduleComposer.rows(
            for: trip,
            today: today,
            now: now,
            timeZone: TripPhaseResolver.calendarTimeZone
        )
        #expect(rows.count == 2)
        #expect(rows[0].id == .leg(trip.legs[0].id))
        #expect(rows[0].visualState == .completed)
        #expect(rows[0].timeLabel == "08:00")
        #expect(rows[1].id == .activity(trip.activities[0].id))
        #expect(rows[1].visualState == .neutral)
        #expect(rows[1].timeLabel == nil)
        #expect(!rows.contains(where: { $0.id == .leg(trip.legs[1].id) }))
    }

    @Test func unknownPlaceDoesNotInventACity() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.currentContext.focus = .none
        for index in trip.legs.indices {
            trip.legs[index].origin = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
            trip.legs[index].destination = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
        }
        for index in trip.activities.indices {
            trip.activities[index].place = try Slot.unknown(updatedAt: DomainTestSupport.timestamp)
        }
        let place = ContextPlaceComposer.place(for: trip, today: try LocalDate(year: 2026, month: 10, day: 1))
        #expect(place.city == nil)
        #expect(place.detail == nil)
        #expect(place.precision == .country)
        #expect(place.country == "Japan")
    }

    @Test func primaryNowTakesTheFirstDisplayPipelineCandidate() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let first = makeTask(ActionPurpose.captureDimensions, importance: .required, scope: focus)
        let second = makeTask(ActionPurpose.selectBookingMethod, importance: .important, scope: focus)
        let third = makeTask(ActionPurpose.reserveOversizedSeat, importance: .recommended, scope: focus)
        let fourth = makeTask(ActionPurpose.verifyReservationMeetsBaggage, importance: .optional, scope: focus)
        trip.tasks = [first, second, third, fourth]
        trip.legs[0].phase = .booking
        let catalog = try EngineTestSupport.catalog()
        trip = try markSetupReady(trip, catalog: catalog)

        let pipeline = TaskDisplayPipeline.snapshot(for: trip)
        #expect(pipeline.now.count == 3)
        let primary = HomePrimaryActionComposer.primary(for: trip, catalog: catalog, tripPhase: .inTrip)
        #expect(primary?.kind == .task(pipeline.now[0]))
        #expect(primary?.kind == .task(first.id))
    }

    @Test func operationalTasksStayHiddenBeforeTheTrip() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let operational = makeTask(
            "leave_for_station",
            importance: .required,
            scope: focus,
            phases: [.goingToDeparture, .atDeparture]
        )
        trip.tasks = [operational]
        trip.legs[0].phase = .goingToDeparture
        let catalog = try EngineTestSupport.catalog()
        trip = try markSetupReady(trip, catalog: catalog)

        #expect(
            HomePrimaryActionComposer.primary(for: trip, catalog: catalog, tripPhase: .beforeTrip) == nil
        )
        #expect(
            HomePrimaryActionComposer.primary(for: trip, catalog: catalog, tripPhase: .inTrip)?.kind == .task(operational.id)
        )
    }

    @Test func bookedReservationIsNotTreatedAsReady() throws {
        var trip = try DomainTestSupport.sampleTrip()
        trip.legs[0].reservation.status = try Slot.confirmed(
            value: .booked,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.readinessChecks = []
        let items = PreparationOverviewComposer.items(for: trip)
        let first = try #require(items.first)
        #expect(first.bookingStatus == .booked)
        #expect(first.readinessStatus == .unverified)
        #expect(first.readinessStatus != .ready)
    }

    @Test func resolverUsesOneImplementationForHomeAndBrainDates() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let today = try LocalDate(year: 2026, month: 10, day: 4)
        let fromResolver = TripPhaseResolver.resolve(trip: trip, today: today)
        let snapshot = ContextualHomeComposer.snapshot(
            for: trip,
            catalog: nil,
            now: try tokyoDate(today)
        )
        #expect(fromResolver == .inTrip)
        #expect(snapshot.tripPhase == fromResolver)
    }
}

private func tokyoDate(_ date: LocalDate, hour: Int = 12) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TripPhaseResolver.calendarTimeZone
    let value = calendar.date(
        from: DateComponents(year: date.year, month: date.month, day: date.day, hour: hour)
    )
    return try #require(value)
}

private func makeTask(
    _ contentKey: String,
    importance: TaskImportance,
    scope: LegID,
    phases: [LegPhase] = [.planning, .booking]
) -> TripTask {
    TripTask(
        id: TaskID(),
        contentKey: contentKey,
        type: .check,
        state: .notStarted,
        importance: importance,
        relevantPhases: phases,
        deadline: nil,
        dependencies: [],
        evidence: .none,
        scope: .leg(scope),
        relatedActionID: nil,
        relatedPolicyID: .jrShinkansenOversizedBaggage,
        relatedGuideID: nil,
        completionCondition: .userConfirmsDone
    )
}

private func markSetupReady(_ trip: Trip, catalog: QuestionCatalog) throws -> Trip {
    var working = trip
    let now = DomainTestSupport.timestamp
    let date = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1))
    working.legs[0].scheduledAt = try Slot.confirmed(value: date, source: .userStated, updatedAt: now)
    working.legs[0].transportMode = try Slot.confirmed(value: .shinkansen, source: .userStated, updatedAt: now)
    working.legs[0].reservation.status = try Slot.confirmed(value: .notBooked, source: .userStated, updatedAt: now)
    working.legs[0].reservation.service = try Slot.confirmed(value: .smartEX, source: .userStated, updatedAt: now)
    working.legs[0].baggagePresence = try Slot.confirmed(value: .yes, source: .userStated, updatedAt: now)
    working.legs[0].phase = .booking
    try working.validate()
    #expect(GuidanceProgressEvaluator.isReadyForNow(trip: working, catalog: catalog))
    return working
}
