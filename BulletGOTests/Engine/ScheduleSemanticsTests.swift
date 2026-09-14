import Foundation
import Testing
@testable import BulletGO

struct ScheduleSemanticsTests {
    @Test func undatedTenAMRoundTripsAndKeepsTimeOnReassignment() throws {
        let ten = try LocalTime(hour: 10, minute: 0)
        let moment = try ScheduledMoment(
            date: nil,
            time: ten,
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        #expect(moment.date == nil)
        #expect(moment.time == ten)
        #expect(moment.placement == .unscheduledStart(ten))

        let encoded = try TripPayloadCodec.makeEncoder().encode(moment)
        let decoded = try TripPayloadCodec.makeDecoder().decode(ScheduledMoment.self, from: encoded)
        #expect(decoded == moment)

        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let reassigned = try decoded.replacingDate(oct3)
        #expect(reassigned.date == oct3)
        #expect(reassigned.time == ten)
    }

    @Test func shrinkingTripDatesRejectsThenMovesItemsToUnscheduledKeepingTimeAndOrder() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let ten = try ScheduledMoment(
            date: oct3,
            time: try LocalTime(hour: 10, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        let noon = try ScheduledMoment(
            date: oct3,
            time: try LocalTime(hour: 12, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: ten,
            at: EngineTestSupport.now
        )
        let stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto Hotel",
            checkIn: ten,
            checkOut: noon,
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(
            [
                .addActivity(activity, atTimelineIndex: nil),
                .updateActivityEndsAt(activity.id, noon),
                .addStay(stay, atTimelineIndex: nil),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        let originalTimeline = trip.timeline
        let start = try LocalDate(year: 2026, month: 10, day: 1)
        let end = try LocalDate(year: 2026, month: 10, day: 2)

        do {
            _ = try TripMutationApplier.apply(
                .setTripDateRange(start: start, end: end, handling: .rejectOutOfRange),
                to: trip,
                at: EngineTestSupport.now
            )
            Issue.record("Expected itemsOutsideDateRange")
        } catch let TripValidationError.itemsOutsideDateRange(items) {
            #expect(Set(items) == Set(originalTimeline))
        }

        trip = try TripMutationApplier.apply(
            .setTripDateRange(start: start, end: end, handling: .moveOutOfRangeToUnscheduledPreservingTiming),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(trip.timeline == originalTimeline)
        #expect(trip.activities[0].scheduledAt.value?.date == nil)
        #expect(trip.activities[0].scheduledAt.value?.time?.hour == 10)
        #expect(trip.activities[0].endsAt.value?.time?.hour == 12)
        #expect(trip.stays[0].checkIn.value?.date == nil)
        #expect(trip.stays[0].checkIn.value?.time?.hour == 10)
        #expect(trip.startDate.value == start)
        #expect(trip.endDate.value == end)
    }

    @Test func activityDraftSavesTimesAndStayDraftClearsCheckout() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        var activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 10, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        var draft = ActivityEditDraft.from(activity, now: EngineTestSupport.now)
        #expect(draft.isDirty(comparedTo: activity) == false)
        draft.timing = .range
        draft.endTime = ScheduledMomentComposer.combine(
            date: oct3,
            time: try LocalTime(hour: 12, minute: 0),
            timeZone: TripCalendar.timeZone
        ) ?? draft.endTime
        #expect(draft.isDirty(comparedTo: activity))
        let mutations = try draft.mutations(activityID: activity.id)
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(mutations, to: trip, at: EngineTestSupport.now)
        #expect(trip.activities[0].endsAt.value?.time?.hour == 12)

        var stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto Hotel",
            checkIn: try ScheduledMoment(date: oct3, timeZoneIdentifier: DomainTestSupport.timeZone),
            checkOut: try ScheduledMoment(
                date: try LocalDate(year: 2026, month: 10, day: 4),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        var stayDraft = StayEditDraft.from(stay, now: EngineTestSupport.now)
        stayDraft.hasCheckOut = false
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(try stayDraft.mutations(stayID: stay.id), to: trip, at: EngineTestSupport.now)
        #expect(trip.stays[0].checkOut.status == .unknown)
        #expect(trip.stays[0].checkIn.value?.date == oct3)
    }

    @Test func emptyMomentIsRejected() {
        #expect(throws: DomainError.invalidScheduledMoment) {
            try ScheduledMoment(timeZoneIdentifier: TripCalendar.timeZoneIdentifier)
        }
    }

    @Test func invertedSameDayRangeIsRejectedAndTransactionCanRepairBeforeValidate() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let ten = try ScheduledMoment(
            date: oct3,
            time: try LocalTime(hour: 10, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        let noon = try ScheduledMoment(
            date: oct3,
            time: try LocalTime(hour: 12, minute: 0),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: ten,
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        #expect(throws: TripValidationError.invertedItemSchedule) {
            _ = try TripMutationApplier.apply(
                .replaceActivitySchedule(activity.id, start: noon, end: ten),
                to: trip,
                at: EngineTestSupport.now
            )
        }
        trip = try TripMutationTransaction.apply(
            [
                .replaceActivitySchedule(activity.id, start: noon, end: ten),
                .replaceActivitySchedule(activity.id, start: ten, end: noon),
            ],
            to: trip,
            at: EngineTestSupport.now
        ).trip
        #expect(trip.activities[0].scheduledAt.value?.time?.hour == 10)
        #expect(trip.activities[0].endsAt.value?.time?.hour == 12)
    }

    @Test func shrinkingDatesKeepsDaySubtitles() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 10, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(
            [
                .addActivity(activity, atTimelineIndex: nil),
                .setDaySubtitle(oct3, "Temple morning"),
            ],
            to: trip,
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(
            .setTripDateRange(
                start: try LocalDate(year: 2026, month: 10, day: 1),
                end: try LocalDate(year: 2026, month: 10, day: 2),
                handling: .moveOutOfRangeToUnscheduledPreservingTiming
            ),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(trip.daySubtitles.map(\.text) == ["Temple morning"])
        #expect(trip.daySubtitles.first?.date == oct3)
    }

    @Test func stayDraftKeepsClockTimeWhenOnlyPlaceChanges() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let ten = try LocalTime(hour: 10, minute: 0)
        var stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto Hotel",
            checkIn: try ScheduledMoment(date: oct3, time: ten, timeZoneIdentifier: DomainTestSupport.timeZone),
            at: EngineTestSupport.now
        )
        var draft = StayEditDraft.from(stay, now: EngineTestSupport.now)
        draft.placeText = "Gion Hotel"
        stay.placeReference = nil
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(try draft.mutations(stayID: stay.id), to: trip, at: EngineTestSupport.now)
        #expect(trip.stays[0].place.value == "Gion Hotel")
        #expect(trip.stays[0].checkIn.value?.date == oct3)
        #expect(trip.stays[0].checkIn.value?.time == ten)
    }

    @Test func legDraftKeepsArrivalDayOffsetWhenDateChanges() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let oct4 = try LocalDate(year: 2026, month: 10, day: 4)
        var leg = try ItineraryItemFactory.makeLeg(
            origin: "Tokyo",
            destination: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 21, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        leg.arrivesAt = try Slot.confirmed(
            value: ScheduledMoment(
                date: oct4,
                time: try LocalTime(hour: 7, minute: 30),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            source: .userStated,
            updatedAt: EngineTestSupport.now
        )
        var draft = LegEditDraft.from(leg, now: EngineTestSupport.now)
        #expect(draft.arrivalDayOffset == 1)
        draft = draft.shiftingDate(
            to: ScheduledMomentComposer.combine(
                date: try LocalDate(year: 2026, month: 10, day: 5),
                time: try LocalTime(hour: 0, minute: 0),
                timeZone: TripCalendar.timeZone
            ) ?? draft.date
        )
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(try draft.mutations(legID: leg.id), to: trip, at: EngineTestSupport.now)
        let expectedDeparture = try LocalDate(year: 2026, month: 10, day: 5)
        let expectedArrival = try LocalDate(year: 2026, month: 10, day: 6)
        #expect(trip.legs[0].scheduledAt.value?.date == expectedDeparture)
        #expect(trip.legs[0].arrivesAt.value?.date == expectedArrival)
        #expect(trip.legs[0].scheduledAt.value?.time?.hour == 21)
        #expect(trip.legs[0].arrivesAt.value?.time?.hour == 7)
        #expect(trip.legs[0].arrivesAt.value?.time?.minute == 30)
    }
}
