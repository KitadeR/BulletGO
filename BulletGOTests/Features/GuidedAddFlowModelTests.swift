import Foundation
import Testing
@testable import BulletGO

@MainActor
struct GuidedAddFlowModelTests {
    @Test func activityStepsStayOnDraftUntilCommit() throws {
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .activity,
            initialDate: try LocalDate(year: 2026, month: 10, day: 3),
            now: EngineTestSupport.now
        )
        #expect(model.steps == [.activityWhat, .activityDate, .activityTiming, .activityReview])
        #expect(model.canAdvance == false)
        model.draft = .activity(ActivityAddDraft(title: "Fushimi Inari", place: "Kyoto", hasDate: true, date: EngineTestSupport.now))
        #expect(model.canAdvance)
        model.advance()
        #expect(model.currentStep == .activityDate)
        model.advance()
        #expect(model.currentStep == .activityTiming)
        model.skipOptional()
        #expect(model.currentStep == .activityReview)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        #expect(mutations.count == 1)
        guard case .addActivity(let activity, _) = mutations[0] else {
            Issue.record("Expected addActivity")
            return
        }
        #expect(activity.title.value == "Fushimi Inari")
        #expect(activity.scheduledAt.value?.isAllDay == false)
    }

    @Test func travelRequiresResolvedPlacesModeAndDate() throws {
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: nil,
            now: EngineTestSupport.now
        )
        #expect(model.steps == [.travelPlaces, .travelMode, .travelSchedule, .travelReview])
        #expect(model.canAdvance == false)

        var draft = LegAddDraft(origin: "Tokyo", destination: "Kyoto", hasDate: false)
        model.draft = .travel(draft)
        #expect(model.canAdvance == false)

        draft.originPlace = Self.tokyoStation
        draft.destinationPlace = Self.shinKobeStation
        model.draft = .travel(draft)
        #expect(model.canAdvance)
        model.advance()
        #expect(model.currentStep == .travelMode)
        #expect(model.canAdvance == false)

        draft.mode = .shinkansen
        model.draft = .travel(draft)
        #expect(model.canAdvance)
        model.advance()
        #expect(model.currentStep == .travelSchedule)
        #expect(model.canAdvance == false)

        draft.hasDate = true
        model.draft = .travel(draft)
        #expect(model.canAdvance)
        model.advance()
        #expect(model.currentStep == .travelReview)
        #expect(model.canAdvance)
    }

    @Test func travelTypedPlacesWithoutCandidateAreNotEnough() throws {
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(
            LegAddDraft(
                origin: "Tokyo",
                destination: "Osaka",
                originPlace: .manual(name: "Tokyo"),
                destinationPlace: .manual(name: "Osaka")
            )
        )
        #expect(model.canAdvance == false)
    }

    @Test func travelDepartureNeedsConfirmedClock() throws {
        var draft = Self.resolvedTravelDraft()
        draft.timeKind = .departure
        draft.clockConfirmed = false
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        model.stepIndex = model.steps.firstIndex(of: .travelSchedule) ?? 0
        #expect(model.canAdvance == false)

        draft.clockConfirmed = true
        model.draft = .travel(draft)
        #expect(model.canAdvance)
    }

    @Test func travelLastTrainDoesNotNeedClock() throws {
        var draft = Self.resolvedTravelDraft()
        draft.timeKind = .lastTrain
        draft.clockConfirmed = false
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        model.stepIndex = model.steps.firstIndex(of: .travelSchedule) ?? 0
        #expect(model.canAdvance)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        #expect(leg.scheduledAt.value?.time == nil)
        let lastTrainDate = try LocalDate(year: 2026, month: 10, day: 2)
        #expect(leg.scheduledAt.value?.date == lastTrainDate)
    }

    @Test func travelFirstTrainDoesNotNeedClock() throws {
        var draft = Self.resolvedTravelDraft()
        draft.timeKind = .firstTrain
        draft.clockConfirmed = false
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        model.stepIndex = model.steps.firstIndex(of: .travelSchedule) ?? 0
        #expect(model.canAdvance)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        #expect(mutations.count == 2)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        #expect(leg.scheduledAt.value?.time == nil)
        let expectedDate = try LocalDate(year: 2026, month: 10, day: 2)
        #expect(leg.scheduledAt.value?.date == expectedDate)
        guard case .setTransportMode(_, let mode) = mutations[1] else {
            Issue.record("Expected setTransportMode")
            return
        }
        #expect(mode == .shinkansen)
    }

    @Test func travelCommitSavesDepartureTimeAndMode() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TripCalendar.timeZone
        let date = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let departs = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 10, minute: 0))!
        var draft = Self.resolvedTravelDraft()
        draft.date = date
        draft.timeKind = .departure
        draft.clockConfirmed = true
        draft.departureTime = departs
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        #expect(leg.origin.value == "Tokyo Station")
        #expect(leg.destination.value == "Shin-Kobe Station")
        #expect(leg.originPlace?.provider == .appleMaps)
        #expect(leg.scheduledAt.value?.time?.hour == 10)
        #expect(leg.scheduledAt.value?.time?.minute == 0)
        #expect(mutations.count == 2)
    }

    @Test func travelCommitSavesArrivalTimeSeparately() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TripCalendar.timeZone
        let date = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2))!
        let arrives = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12, minute: 30))!
        var draft = Self.resolvedTravelDraft()
        draft.date = date
        draft.timeKind = .arrival
        draft.clockConfirmed = true
        draft.arrivalTime = arrives
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        #expect(mutations.count == 3)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        #expect(leg.scheduledAt.value?.time == nil)
        guard case .updateLegArrivesAt(_, let arrival) = mutations[2] else {
            Issue.record("Expected updateLegArrivesAt")
            return
        }
        #expect(arrival.time?.hour == 12)
        #expect(arrival.time?.minute == 30)
    }

    @Test func travelReviewJumpReturnsToPlaces() throws {
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.stepIndex = model.steps.firstIndex(of: .travelReview) ?? 0
        model.jump(to: .travelPlaces)
        #expect(model.currentStep == .travelPlaces)
    }

    @Test func travelSkipTimeKeepsDateAndOmitsClock() throws {
        var draft = Self.resolvedTravelDraft()
        draft.skippedTime = true
        draft.timeKind = .undecided
        draft.clockConfirmed = false
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .travel(draft)
        model.stepIndex = model.steps.firstIndex(of: .travelSchedule) ?? 0
        #expect(model.canAdvance)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        let skippedDate = try LocalDate(year: 2026, month: 10, day: 2)
        #expect(leg.scheduledAt.value?.date == skippedDate)
        #expect(leg.scheduledAt.value?.time == nil)
    }

    @Test func stayRequiresPlaceAndRejectsInvertedDates() throws {
        var draft = StayAddDraft(place: "Kyoto Hotel", hasCheckIn: true, hasCheckOut: true)
        draft.checkIn = Date(timeIntervalSince1970: 1_788_480_000)
        draft.checkOut = Date(timeIntervalSince1970: 1_788_393_600)
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .stay,
            initialDate: try LocalDate(year: 2026, month: 10, day: 2),
            now: EngineTestSupport.now
        )
        model.draft = .stay(draft)
        model.stepIndex = model.steps.firstIndex(of: .stayCheckOut) ?? 0
        #expect(model.canAdvance == false)
        draft.checkOut = Date(timeIntervalSince1970: 1_788_566_400)
        model.draft = .stay(draft)
        #expect(model.canAdvance)
        model.stepIndex = model.steps.firstIndex(of: .stayReview) ?? 0
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addStay(let stay, _) = mutations[0] else {
            Issue.record("Expected addStay")
            return
        }
        #expect(stay.place.value == "Kyoto Hotel")
        #expect(stay.checkIn.status == .confirmed)
        #expect(stay.checkOut.status == .confirmed)
    }

    @Test func cancelKeepsTripUnchangedBecauseCommitIsTheOnlySave() async throws {
        let repository = InMemoryTripRepository()
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        try await repository.save(trip)
        let session = TripSessionModel(
            store: TripStore(repository: repository, brain: try EngineTestSupport.brain())
        )
        await session.load()
        let model = GuidedAddFlowModel(tripID: trip.id, kind: .activity, initialDate: nil, now: EngineTestSupport.now)
        model.draft = .activity(ActivityAddDraft(title: "Unsaved", hasDate: false))
        #expect(model.isDirty)
        #expect(session.trip?.activities.isEmpty == true)
    }

    @Test func activityCommitUsesTokyoLocalDateAndTimeNotPickerCalendar() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TripCalendar.timeZone
        let date = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let start = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 10, minute: 0))!
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .activity,
            initialDate: try LocalDate(year: 2026, month: 10, day: 3),
            now: EngineTestSupport.now
        )
        model.draft = .activity(
            ActivityAddDraft(
                title: "Kinkaku-ji",
                place: "Kyoto",
                hasDate: true,
                date: date,
                timing: .start,
                startTime: start
            )
        )
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addActivity(let activity, _) = mutations[0] else {
            Issue.record("Expected addActivity")
            return
        }
        let expectedDate = try LocalDate(year: 2026, month: 10, day: 3)
        #expect(activity.scheduledAt.value?.timeZoneIdentifier == TripCalendar.timeZoneIdentifier)
        #expect(activity.scheduledAt.value?.date == expectedDate)
        #expect(activity.scheduledAt.value?.time?.hour == 10)
        #expect(activity.scheduledAt.value?.time?.minute == 0)
    }

    @Test func seedDraftUsesTokyoDateNotDeviceTimeZone() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let seeded = GuidedAddComposer.seedDraft(
            kind: .activity,
            initialDate: oct3,
            now: EngineTestSupport.now
        )
        guard case .activity(let draft) = seeded else {
            Issue.record("Expected activity draft")
            return
        }
        let local = try ScheduledMomentComposer.localDate(from: draft.date, timeZone: TripCalendar.timeZone)
        #expect(local == oct3)
        #expect(draft.hasDate)
    }

    @Test func activityCommitKeepsMapKitPlaceAndSelectedDate() async throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        let place = PlaceReference(
            provider: .appleMaps,
            providerID: "poi-kinkaku",
            name: "Kinkaku-ji",
            coordinate: GeoCoordinate(latitude: 35.0394, longitude: 135.7292),
            address: "1 Kinkakujicho, Kita-ku, Kyoto",
            category: "MKPOICategoryLandmark"
        )
        let repository = InMemoryTripRepository()
        let trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: LocalDate(year: 2026, month: 10, day: 1),
            endDate: LocalDate(year: 2026, month: 10, day: 8),
            now: EngineTestSupport.now
        )
        try await repository.save(trip)
        let session = TripSessionModel(
            store: TripStore(repository: repository, brain: try EngineTestSupport.brain())
        )
        await session.load()
        let model = GuidedAddFlowModel(
            tripID: trip.id,
            kind: .activity,
            initialDate: oct3,
            now: EngineTestSupport.now
        )
        guard let date = oct3.date(in: TripCalendar.timeZone) else {
            Issue.record("Expected Tokyo date")
            return
        }
        model.draft = .activity(
            ActivityAddDraft(
                title: "Kinkaku-ji",
                place: "Kinkaku-ji",
                hasDate: true,
                date: date,
                placeReference: place
            )
        )
        #expect(session.trip?.activities.isEmpty == true)
        #expect(try model.makeMutations(now: EngineTestSupport.now).count == 1)
        #expect(session.trip?.activities.isEmpty == true)

        let saved = await model.commit(session: session)
        #expect(saved)
        let activity = try #require(session.trip?.activities.first)
        #expect(activity.placeReference?.provider == .appleMaps)
        #expect(activity.placeReference?.providerID == "poi-kinkaku")
        #expect(activity.placeReference?.address == "1 Kinkakujicho, Kita-ku, Kyoto")
        #expect(activity.scheduledAt.value?.date == oct3)
        #expect(session.trip?.timeline == [.activity(activity.id)])
        #expect(session.trip?.activities.count == 1)
    }

    @Test func typedPlaceWithoutSelectionBecomesManualReference() throws {
        let oct3 = try LocalDate(year: 2026, month: 10, day: 3)
        guard let date = oct3.date(in: TripCalendar.timeZone) else {
            Issue.record("Expected Tokyo date")
            return
        }
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .activity,
            initialDate: oct3,
            now: EngineTestSupport.now
        )
        model.draft = .activity(
            ActivityAddDraft(
                title: "Walk in Gion",
                place: "Gion",
                hasDate: true,
                date: date
            )
        )
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        guard case .addActivity(let activity, _) = mutations[0] else {
            Issue.record("Expected addActivity")
            return
        }
        #expect(activity.placeReference?.provider == .manual)
        #expect(activity.placeReference?.name == "Gion")
        #expect(activity.placeReference?.providerID == nil)
        #expect(activity.scheduledAt.value?.date == oct3)
    }

    private static let tokyoStation = PlaceReference(
        provider: .appleMaps,
        providerID: "poi-tokyo",
        name: "Tokyo Station",
        coordinate: GeoCoordinate(latitude: 35.6812, longitude: 139.7671),
        address: "Chiyoda City, Tokyo",
        category: "MKPOICategoryPublicTransport"
    )

    private static let shinKobeStation = PlaceReference(
        provider: .appleMaps,
        providerID: "poi-shinkobe",
        name: "Shin-Kobe Station",
        coordinate: GeoCoordinate(latitude: 34.7045, longitude: 135.1956),
        address: "Kobe",
        category: "MKPOICategoryPublicTransport"
    )

    private static func resolvedTravelDraft() -> LegAddDraft {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TripCalendar.timeZone
        let date = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2)) ?? EngineTestSupport.now
        return LegAddDraft(
            origin: "Tokyo Station",
            destination: "Shin-Kobe Station",
            mode: .shinkansen,
            hasDate: true,
            date: date,
            originPlace: tokyoStation,
            destinationPlace: shinKobeStation
        )
    }
}
