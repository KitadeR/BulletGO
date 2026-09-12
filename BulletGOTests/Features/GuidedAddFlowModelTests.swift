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

    @Test func travelAllowsLaterModeAndRequiresOriginDestination() throws {
        let model = GuidedAddFlowModel(
            tripID: TripID(),
            kind: .travel,
            initialDate: nil,
            now: EngineTestSupport.now
        )
        #expect(model.steps.first == .travelOrigin)
        #expect(model.canAdvance == false)
        model.draft = .travel(LegAddDraft(origin: "Tokyo", destination: "Kyoto", skipMode: true, hasDate: false))
        model.stepIndex = model.steps.firstIndex(of: .travelReview) ?? 0
        #expect(model.canAdvance)
        let mutations = try model.makeMutations(now: EngineTestSupport.now)
        #expect(mutations.count == 1)
        guard case .addLeg(let leg, _) = mutations[0] else {
            Issue.record("Expected addLeg")
            return
        }
        #expect(leg.origin.value == "Tokyo")
        #expect(leg.destination.value == "Kyoto")
        #expect(leg.scheduledAt.status == .unknown)
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
}
