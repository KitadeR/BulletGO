import Foundation
import Testing
@testable import BulletGO

@MainActor
struct ItineraryPresentationTests {
    @Test func undatedTripKeepsASingleUnscheduledSection() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let sections = ItineraryDayComposer.sections(for: trip)
        #expect(sections.count == 1)
        #expect(sections[0].id == .unscheduled)
        #expect(sections[0].rows.count == 6)
        #expect(sections[0].rows[0].title == "Tokyo → Kyoto")
    }

    @Test func datedItemsKeepUnscheduledLast() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let now = EngineTestSupport.now
        let dated = try EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 2))
        let leg = try ItineraryItemFactory.makeLeg(origin: "Tokyo", destination: "Osaka", scheduledAt: dated, at: now)
        let activity = try ItineraryItemFactory.makeActivity(title: "USJ", place: "Osaka", at: now)
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: now)
        let sections = ItineraryDayComposer.sections(for: trip)
        let october2 = try LocalDate(year: 2026, month: 10, day: 2)
        #expect(sections.last?.id == .unscheduled)
        #expect(sections.last?.rows.contains { $0.title == "USJ" } == true)
        #expect(sections.first?.id == .day(october2))
        #expect(sections.contains { $0.id == .day(october2) })
    }

    @Test func unscheduledTenAMKeepsExactGutter() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: nil,
                time: try LocalTime(hour: 10, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        let section = try #require(ItineraryDayComposer.sections(for: trip).first { $0.id == .unscheduled })
        let row = try #require(section.rows.first { $0.title == "Kinkaku-ji" })
        #expect(row.gutterDisplay == .exact("10:00"))
        #expect(row.timeText == "10:00")
    }

    @Test func dateOptionsUseFullRangeWhenStartAndEndExist() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct8 = try LocalDate(year: 2026, month: 10, day: 8)
        let options = ItineraryDayComposer.dateOptions(for: trip)
        #expect(options.first == oct1)
        #expect(options.last == oct8)
        #expect(options.count == 8)
        let snapshot = ItineraryDayComposer.snapshot(for: trip, now: EngineTestSupport.now)
        #expect(snapshot.dateOptions.count == 8)
        #expect(snapshot.dateOptions.filter(\.hasItems).map(\.date) == [oct1, oct2])
    }

    @Test func dateOptionsFallBackToDatedItemsWhenRangeIsMissing() throws {
        var trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        trip.startDate = try Slot.unknown(updatedAt: EngineTestSupport.now)
        trip.endDate = try Slot.unknown(updatedAt: EngineTestSupport.now)
        #expect(ItineraryDayComposer.dateOptions(for: trip) == [oct1, oct2])
    }

    @Test func dateOptionsAreEmptyWhenNoRangeAndNoDatedItemsExist() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        trip.startDate = try Slot.unknown(updatedAt: EngineTestSupport.now)
        trip.endDate = try Slot.unknown(updatedAt: EngineTestSupport.now)
        let activity = try ItineraryItemFactory.makeActivity(title: "USJ", place: "Osaka", at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        #expect(ItineraryDayComposer.dateOptions(for: trip).isEmpty)
        #expect(ItineraryDayComposer.initialDate(for: trip, now: EngineTestSupport.now) == nil)
        let sections = ItineraryDayComposer.sections(for: trip)
        #expect(sections.map(\.id) == [.unscheduled])
    }

    @Test func initialDateUsesPhaseAndAllowsEmptyToday() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let timeZone = TripPhaseResolver.calendarTimeZone
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let oct9 = try LocalDate(year: 2026, month: 10, day: 9)
        #expect(ItineraryDayComposer.initialDate(for: trip, now: EngineTestSupport.now) == oct1)

        let inTripNow = try #require(oct2.date(in: timeZone))
        #expect(ItineraryDayComposer.initialDate(for: trip, now: inTripNow) == oct2)

        let emptyTodayNow = try #require(oct3.date(in: timeZone))
        #expect(ItineraryDayComposer.initialDate(for: trip, now: emptyTodayNow) == oct3)

        let finishedNow = try #require(oct9.date(in: timeZone))
        #expect(ItineraryDayComposer.initialDate(for: trip, now: finishedNow) == oct2)
    }

    @Test func assignmentUsesScheduledAtAndCheckInWithoutReplicatingStay() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let sections = ItineraryDayComposer.sections(for: trip)
        let first = try #require(sections.first { $0.id == .day(oct1) })
        let second = try #require(sections.first { $0.id == .day(oct2) })
        #expect(first.rows.map(\.title) == ["Tokyo → Kyoto", "Kinkaku-ji"])
        #expect(second.rows.map(\.title) == ["Kyoto Hotel", "Kyoto sightseeing"])
        #expect(first.rows.contains { if case .stay = $0.id { return true }; return false } == false)
        #expect(ItineraryDayComposer.date(for: trip.timeline[0], in: trip) == oct1)
        #expect(ItineraryDayComposer.date(for: trip.timeline[2], in: trip) == oct2)
    }

    @Test func sameDayKeepsTimelineOrderInsteadOfClockOrder() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let untimed = try EngineTestSupport.moment(oct1)
        let timed = try ScheduledMoment(
            date: oct1,
            time: try LocalTime(hour: 10, minute: 3),
            timeZoneIdentifier: DomainTestSupport.timeZone
        )
        let activity = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: untimed,
            at: EngineTestSupport.now
        )
        let leg = try ItineraryItemFactory.makeLeg(
            origin: "Tokyo",
            destination: "Kyoto",
            scheduledAt: timed,
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(activity, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        let section = try #require(ItineraryDayComposer.sections(for: trip).first { $0.id == .day(oct1) })
        #expect(section.rows.map(\.title) == ["Kinkaku-ji", "Tokyo → Kyoto"])
        #expect(section.rows[0].gutterDisplay == .none)
        #expect(section.rows[0].timeText == nil)
        #expect(section.rows[1].gutterDisplay == .exact("10:03"))
        #expect(section.rows[1].timeText == "10:03")
    }

    @Test func timingGutterUsesExactClockTimeAndLeavesUntimedBlank() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let rows = TimelineRowComposer.rows(for: trip)
        let sections = ItineraryDayComposer.sections(for: trip)

        let leg = try #require(rows.first { $0.title == "Tokyo → Kyoto" })
        #expect(leg.gutterDisplay == .exact("10:03"))
        #expect(leg.timeText == "10:03")

        let dateOnlyActivity = try #require(rows.first { $0.title == "Kinkaku-ji" })
        #expect(dateOnlyActivity.gutterDisplay == .none)
        #expect(dateOnlyActivity.timeText == nil)

        let checkInStay = try #require(rows.first { $0.title == "Kyoto Hotel" })
        #expect(checkInStay.gutterDisplay == .exact("16:00"))
        #expect(checkInStay.timeText == "16:00")

        let checkInDay = try #require(sections.first { $0.id == .day(oct2) })
        #expect(checkInDay.rows.contains { $0.id == checkInStay.id })
        #expect(sections.contains { $0.id == .day(oct1) && $0.rows.contains { $0.id == checkInStay.id } } == false)
        #expect(sections.contains { $0.id == .day(oct3) } == false)
    }

    @Test func timingGutterMapsConfirmedActivityTimeAndLeavesUnknownBlank() throws {
        var trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let tea = try ItineraryItemFactory.makeActivity(
            title: "Tea ceremony",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct1,
                time: try LocalTime(hour: 14, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addActivity(tea, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)

        let rows = TimelineRowComposer.rows(for: trip)
        let teaRow = try #require(rows.first { $0.title == "Tea ceremony" })
        #expect(teaRow.gutterDisplay == .exact("14:00"))
        #expect(teaRow.timeText == "14:00")

        let unknownTrip = try DomainTestSupport.sampleTrip()
        let unknownRows = TimelineRowComposer.rows(for: unknownTrip)
        #expect(unknownRows.allSatisfy { $0.gutterDisplay == .none })
        #expect(unknownRows.allSatisfy { $0.timeText == nil })
    }

    @Test func timingGutterLeavesDateOnlyStayAndUnconfirmedClockTimeBlank() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let dateOnlyStay = try ItineraryItemFactory.makeStay(
            place: "Nara Inn",
            checkIn: try EngineTestSupport.moment(oct2),
            at: EngineTestSupport.now
        )
        var inferredLeg = try ItineraryItemFactory.makeLeg(
            origin: "Kyoto",
            destination: "Nara",
            at: EngineTestSupport.now
        )
        inferredLeg.scheduledAt = try Slot.inferred(
            value: try ScheduledMoment(
                date: oct2,
                time: try LocalTime(hour: 9, minute: 30),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            updatedAt: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addStay(dateOnlyStay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(.addLeg(inferredLeg, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)

        let rows = TimelineRowComposer.rows(for: trip)
        let stayRow = try #require(rows.first { $0.title == "Nara Inn" })
        #expect(stayRow.gutterDisplay == .none)
        #expect(stayRow.timeText == nil)

        let inferredRow = try #require(rows.first { $0.title == "Kyoto → Nara" })
        #expect(inferredRow.gutterDisplay == .none)
        #expect(inferredRow.timeText == nil)
    }

    @Test func tripsV2LegCardShowsConfirmedTransportAndOmitsInventedTrainMeta() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 2),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        var leg = try ItineraryItemFactory.makeLeg(
            origin: "Tokyo",
            destination: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct2,
                time: try LocalTime(hour: 10, minute: 3),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        leg.reservation.details.trainName = "のぞみ215号"
        leg.reservation.details.arrivalTime = try LocalTime(hour: 12, minute: 11)
        trip = try TripMutationApplier.apply(.addLeg(leg, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(
            .setTransportMode(leg.id, .shinkansen),
            to: trip,
            at: EngineTestSupport.now
        )

        let row = try #require(TimelineRowComposer.rows(for: trip).first { $0.title == "Tokyo → Kyoto" })
        #expect(row.gutterDisplay == .exact("10:03"))

        let unbooked = try #require(TripsLegCardComposer.presentation(row: row, trip: trip, catalog: nil))
        #expect(unbooked.transport == .localized(TripContentResolver.transportSummary(for: trip.legs[0])))
        #expect(unbooked.route == "Tokyo → Kyoto")
        #expect(unbooked.arrivalTimeText == nil)
        #expect(unbooked.trainName == nil)
        #expect(unbooked.hasReservationMeta == false)

        trip.legs[0].reservation.status = try Slot.confirmed(
            value: .booked,
            source: .userStated,
            updatedAt: EngineTestSupport.now
        )
        let booked = try #require(TripsLegCardComposer.presentation(
            row: TimelineRowComposer.rows(for: trip)[0],
            trip: trip,
            catalog: nil
        ))
        #expect(booked.arrivalTimeText == "12:11")
        #expect(booked.trainName == "のぞみ215号")
    }

    @Test func tripsV2ActivityCardKeepsTimingOutOfTheCard() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 2),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let untimed = try ItineraryItemFactory.makeActivity(
            title: "Fushimi Inari",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(date: oct3, timeZoneIdentifier: DomainTestSupport.timeZone),
            at: EngineTestSupport.now
        )
        var tea = try ItineraryItemFactory.makeActivity(
            title: "Tea ceremony",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(
                date: oct3,
                time: try LocalTime(hour: 14, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            at: EngineTestSupport.now
        )
        tea.reservation.status = try Slot.confirmed(value: .booked, source: .userStated, updatedAt: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(.addActivity(untimed, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        trip = try TripMutationApplier.apply(.addActivity(tea, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)

        let rows = TimelineRowComposer.rows(for: trip)
        let untimedRow = try #require(rows.first { $0.title == "Fushimi Inari" })
        let teaRow = try #require(rows.first { $0.title == "Tea ceremony" })
        #expect(untimedRow.gutterDisplay == .none)
        #expect(teaRow.gutterDisplay == .exact("14:00"))

        let untimedCard = try #require(TripsActivityCardComposer.presentation(row: untimedRow, trip: trip))
        #expect(untimedCard.title == "Fushimi Inari")
        #expect(untimedCard.place == "Kyoto")
        #expect(untimedCard.isBooked == false)

        let teaCard = try #require(TripsActivityCardComposer.presentation(row: teaRow, trip: trip))
        #expect(teaCard.title == "Tea ceremony")
        #expect(teaCard.isBooked == true)
    }

    @Test func tripsV2StayCardUsesConfirmedStayFactsWithoutCheckInClock() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 2),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct5 = try LocalDate(year: 2026, month: 10, day: 5)
        let stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto Granbell Hotel",
            checkIn: try ScheduledMoment(
                date: oct2,
                time: try LocalTime(hour: 16, minute: 0),
                timeZoneIdentifier: DomainTestSupport.timeZone
            ),
            checkOut: try ScheduledMoment(date: oct5, timeZoneIdentifier: DomainTestSupport.timeZone),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)

        let row = try #require(TimelineRowComposer.rows(for: trip).first { $0.title == "Kyoto Granbell Hotel" })
        #expect(row.gutterDisplay == .exact("16:00"))

        let card = try #require(
            TripsStayCardComposer.presentation(row: row, trip: trip, locale: Locale(identifier: "ja"))
        )
        #expect(card.name == "Kyoto Granbell Hotel")
        #expect(card.nights == 3)
        #expect(card.dateRange == "10月2日 → 10月5日")
        #expect(card.dateRange?.contains("16:00") == false)
        #expect(card.role == .checkIn)
    }

    @Test func stayOccupancyProjectsCheckInStayingAndCheckOutWithoutDuplicatingEntity() throws {
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 2),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let oct4 = try LocalDate(year: 2026, month: 10, day: 4)
        let oct5 = try LocalDate(year: 2026, month: 10, day: 5)
        let stay = try ItineraryItemFactory.makeStay(
            place: "Kyoto Hotel",
            checkIn: try ScheduledMoment(date: oct2, timeZoneIdentifier: DomainTestSupport.timeZone),
            checkOut: try ScheduledMoment(date: oct5, timeZoneIdentifier: DomainTestSupport.timeZone),
            at: EngineTestSupport.now
        )
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: EngineTestSupport.now)
        let sections = ItineraryDayComposer.sections(for: trip)
        let checkIn = try #require(sections.first { $0.id == .day(oct2) }?.rows.first)
        let staying = try #require(sections.first { $0.id == .day(oct3) }?.rows.first)
        let lastNight = try #require(sections.first { $0.id == .day(oct4) }?.rows.first)
        let checkOut = try #require(sections.first { $0.id == .day(oct5) }?.rows.first)
        #expect(checkIn.id == .stay(stay.id, .checkIn))
        #expect(staying.id == .stay(stay.id, .staying(night: 1, of: 3)))
        #expect(lastNight.id == .stay(stay.id, .staying(night: 2, of: 3)))
        #expect(checkOut.id == .stay(stay.id, .checkOut))
        #expect(trip.stays.count == 1)
    }

    @Test func tripsV2FloatingAddUsesSelectedDayWithoutWeekday() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let label = TripsFloatingAddComposer.dayLabel(date: oct3, locale: Locale(identifier: "ja"))
        #expect(label == "10月3日")
        #expect(label.contains("土") == false)
    }

    @Test func emptyDayAppearsOnlyWhenSelectedAndInRange() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let oct9 = try LocalDate(year: 2026, month: 10, day: 9)
        let populated = ItineraryDayComposer.sections(for: trip)
        #expect(populated.contains { $0.id == .day(oct3) } == false)
        let inserted = ItineraryDayComposer.sections(for: trip, insertingEmptyDay: oct3)
        #expect(inserted.contains { $0.id == .day(oct3) && $0.rows.isEmpty })
        #expect(inserted.last?.id == .unscheduled)
        let ignored = ItineraryDayComposer.sections(for: trip, insertingEmptyDay: oct9)
        #expect(ignored.contains { $0.id == .day(oct9) } == false)
    }

    @Test func preparationUsesRealStateAndIgnoresUnverifiedOnly() throws {
        var trip = try DomainTestSupport.multiDayTrip()
        let rows = TimelineRowComposer.rows(for: trip)
        let legRow = try #require(rows.first { if case .leg = $0.id { return true }; return false })
        let stayRow = try #require(rows.first { if case .stay = $0.id { return true }; return false })
        let activityRow = try #require(rows.first { if case .activity = $0.id { return true }; return false })

        #expect(TripsPreparationComposer.indication(for: legRow, trip: trip, catalog: nil) == nil)
        trip.readinessChecks = [
            ReadinessCheck(
                id: ReadinessCheckID(),
                checkType: .ticketIssuance,
                scope: .leg(trip.legs[0].id),
                relatedPolicyID: nil,
                status: .unverified,
                documentSignal: .unverified,
                detailKey: nil,
                evidenceSources: [],
                evaluatedAt: EngineTestSupport.now,
                stale: false
            ),
        ]
        #expect(TripsPreparationComposer.indication(for: legRow, trip: trip, catalog: nil) == nil)

        trip.readinessChecks[0].status = .actionRequired
        #expect(TripsPreparationComposer.indication(for: legRow, trip: trip, catalog: nil)?.title.key == "Action needed")

        trip.readinessChecks = [
            ReadinessCheck(
                id: ReadinessCheckID(),
                checkType: .entryTicket,
                scope: .stay(trip.stays[0].id),
                relatedPolicyID: nil,
                status: .actionRequired,
                documentSignal: .unverified,
                detailKey: nil,
                evidenceSources: [],
                evaluatedAt: EngineTestSupport.now,
                stale: false
            ),
        ]
        #expect(TripsPreparationComposer.indication(for: stayRow, trip: trip, catalog: nil) == nil)
        #expect(TripsPreparationComposer.indication(for: activityRow, trip: trip, catalog: nil) == nil)

        trip.tasks = [
            TripTask(
                id: TaskID(),
                contentKey: "one",
                type: .check,
                state: .notStarted,
                importance: .required,
                relevantPhases: [.planning],
                deadline: nil,
                dependencies: [],
                evidence: .none,
                scope: .leg(trip.legs[0].id),
                relatedActionID: nil,
                relatedPolicyID: nil,
                relatedGuideID: nil,
                completionCondition: .userConfirmsDone
            ),
        ]
        trip.readinessChecks = []
        #expect(TripsPreparationComposer.indication(for: legRow, trip: trip, catalog: nil) != nil)

        let catalog = try EngineTestSupport.catalog()
        #expect(
            TripsPreparationComposer.indication(for: legRow, trip: trip, catalog: catalog)?.title.key
                == "Journey details still needed"
        )
    }

    @Test func dayLocalMoveMapsOntoTimelineWithoutChangingDates() throws {
        let trip = try DomainTestSupport.multiDayTrip()
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let section = try #require(ItineraryDayComposer.sections(for: trip).first { $0.id == .day(oct1) })
        let activity = section.rows[1]
        let destination = try #require(ItineraryDayComposer.moveDestination(of: activity.id, offset: -1, in: trip))
        let originalStayDate = trip.stays[0].checkIn
        let originalLegDate = trip.legs[0].scheduledAt
        let updated = try TripMutationApplier.apply(
            .moveTimelineItem(from: destination.from, to: destination.to),
            to: trip,
            at: EngineTestSupport.now
        )
        #expect(updated.stays[0].checkIn == originalStayDate)
        #expect(updated.legs[0].scheduledAt == originalLegDate)
        let moved = try #require(ItineraryDayComposer.sections(for: updated).first { $0.id == .day(oct1) })
        #expect(moved.rows.first?.id == activity.id)
        #expect(ItineraryDayComposer.moveDestination(of: section.rows[0].id, offset: 1, in: trip) != nil)
        #expect(ItineraryDayComposer.moveDestination(of: section.rows[1].id, offset: 1, in: trip) == nil)
        #expect(ItineraryDayComposer.moveDestination(of: section.rows[0].id, offset: -1, in: trip) == nil)
    }
}

@MainActor
struct ItineraryDraftTests {
    @Test func deterministicExtractorCapturesTokyoOsakaAndLuggage() async throws {
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let extractor = LocalDeterministicItineraryDraftExtractor()
        let draft = try await extractor.extract(
            "October 2 morning, Tokyo to Osaka by Shinkansen. Large suitcase.",
            scope: .trip,
            trip: trip
        )
        #expect(draft.items.contains { $0.kind == .leg && $0.origin == "Tokyo" && $0.destination == "Osaka" })
        #expect(draft.items.contains { $0.kind == .baggageHint })
        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        #expect(mutations.contains { if case .addLeg = $0 { return true }; return false })
    }

    @Test func japaneseExtractorCapturesTokyoOsakaWithoutInventingReservation() async throws {
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        let extractor = LocalDeterministicItineraryDraftExtractor()
        let draft = try await extractor.extract(
            "10月2日の朝、東京から大阪へ新幹線。大きい荷物がある。",
            scope: .trip,
            trip: trip
        )
        #expect(draft.items.contains { $0.kind == .leg && $0.origin == "Tokyo" && $0.destination == "Osaka" })
        #expect(draft.items.contains { $0.kind == .baggageHint })
        #expect(!draft.items.contains { $0.kind == .leg && $0.baggageHint != nil })
        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        #expect(!mutations.contains { if case .setReservationStatus = $0 { return true }; return false })
        #expect(!mutations.contains { if case .setBagDimensions = $0 { return true }; return false })
    }

    @Test func extractionDoesNotSaveUntilConfirm() async throws {
        let repository = InMemoryTripRepository()
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        try await repository.save(trip)
        let store = TripStore(repository: repository, brain: try EngineTestSupport.brain())
        let session = TripSessionModel(store: store)
        await session.load()
        let draft = try await session.extractItineraryDraft(
            "October 2 morning, Tokyo to Osaka by Shinkansen. Large suitcase.",
            scope: .trip,
            trip: trip
        )
        #expect(!draft.items.isEmpty)
        let loaded = try await store.fetch(id: trip.id)
        #expect(loaded?.legs.isEmpty == true)

        let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: EngineTestSupport.now)
        _ = await session.process(.applyMutations(mutations))
        #expect(session.trip?.legs.contains { $0.origin.value == "Tokyo" && $0.destination.value == "Osaka" } == true)
    }

    @Test func validatorDropsItemsWithoutASourceQuote() {
        let draft = ProposedItineraryDraft(
            tripName: nil,
            startDate: nil,
            endDate: nil,
            items: [
                ProposedItineraryItem(
                    kind: .leg,
                    origin: "Tokyo",
                    destination: "Hakata",
                    place: nil,
                    title: nil,
                    date: nil,
                    time: nil,
                    transport: nil,
                    checkIn: nil,
                    checkOut: nil,
                    baggageHint: nil,
                    sourceQuote: "not in the source",
                    confidence: .low
                )
            ],
            unresolved: []
        )
        let validated = ItineraryDraftValidator.validated(draft, source: "Tokyo to Osaka")
        #expect(validated.items.isEmpty)
        #expect(!validated.unresolved.isEmpty)
    }

    @Test func dateChipSelectionWaitsUntilTheNextHeadingReachesThePin() throws {
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let pin: CGFloat = 24

        #expect(
            TripsV2Formatting.selectedDate(
                from: [oct1: 8, oct2: 420, oct3: 860],
                pin: pin
            ) == oct1
        )
        #expect(
            TripsV2Formatting.selectedDate(
                from: [oct1: -180, oct2: 120, oct3: 540],
                pin: pin
            ) == oct1
        )
        #expect(
            TripsV2Formatting.selectedDate(
                from: [oct1: -360, oct2: 25, oct3: 420],
                pin: pin
            ) == oct1
        )
        #expect(
            TripsV2Formatting.selectedDate(
                from: [oct1: -400, oct2: 20, oct3: 380],
                pin: pin
            ) == oct2
        )
    }
}
