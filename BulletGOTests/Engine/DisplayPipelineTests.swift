import Foundation
import Testing
@testable import BulletGO

@MainActor
struct DisplayPipelineTests {
    @Test func nowIsCappedAtThreeAndExcludesHiddenAndUnsatisfiedDependencies() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let bagID = PolicyScenarioSupport.bagA
        trip.baggageInventory = [
            Bag(
                id: bagID,
                kind: try Slot.unknown(updatedAt: EngineTestSupport.now),
                userDescription: try Slot.unknown(updatedAt: EngineTestSupport.now),
                perceivedSize: try Slot.unknown(updatedAt: EngineTestSupport.now),
                dimensions: try Slot.unknown(updatedAt: EngineTestSupport.now),
                weightKilograms: try Slot.unknown(updatedAt: EngineTestSupport.now),
                createdAt: EngineTestSupport.now
            ),
        ]
        trip.tasks = [
            makeTask("completed", state: .completed, scope: focus, importance: .required),
            makeTask("cancelled", state: .cancelled, scope: focus, importance: .required),
            makeTask("stale", state: .stale, scope: focus, importance: .required),
            makeTask(
                "blocked",
                state: .notStarted,
                scope: focus,
                importance: .required,
                dependencies: [TaskDependency(path: .bag(bagID, .dimensions), requiredTaskID: nil)]
            ),
            makeTask("one", state: .notStarted, scope: focus, importance: .required),
            makeTask("two", state: .notStarted, scope: focus, importance: .important),
            makeTask("three", state: .notStarted, scope: focus, importance: .recommended),
            makeTask("four", state: .notStarted, scope: focus, importance: .optional),
        ]
        let snapshot = TaskDisplayPipeline.snapshot(for: trip)
        #expect(snapshot.now.count == 3)
        #expect(Set(snapshot.hidden).isSuperset(of: Set(trip.tasks.prefix(3).map(\.id))))
        #expect(!snapshot.now.contains(trip.tasks[3].id))
        #expect(snapshot.next.contains(trip.tasks[3].id) || snapshot.later.contains(trip.tasks[3].id))
        #expect(snapshot.now.contains(trip.tasks[4].id))
    }

    @Test func needsReviewAndActionRequiredReadinessAreBoosted() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let review = makeTask("review", state: .needsReview, scope: focus, importance: .optional)
        let ordinary = makeTask("ordinary", state: .notStarted, scope: focus, importance: .required)
        trip.tasks = [ordinary, review]
        trip.readinessChecks = [
            ReadinessCheck(
                id: ReadinessCheckID(),
                checkType: .baggageReservation,
                scope: .leg(focus),
                relatedPolicyID: .jrShinkansenOversizedBaggage,
                status: .actionRequired,
                documentSignal: .unverified,
                detailKey: nil,
                evidenceSources: [],
                evaluatedAt: EngineTestSupport.now,
                stale: false
            ),
        ]
        let snapshot = TaskDisplayPipeline.snapshot(for: trip)
        #expect(snapshot.now.first == review.id)
        #expect(snapshot.now.contains(ordinary.id))
    }

    private func makeTask(
        _ key: String,
        state: TaskState,
        scope: LegID,
        importance: TaskImportance,
        dependencies: [TaskDependency] = []
    ) -> TripTask {
        TripTask(
            id: TaskID(),
            contentKey: key,
            type: .check,
            state: state,
            importance: importance,
            relevantPhases: [.planning, .booking],
            deadline: nil,
            dependencies: dependencies,
            evidence: .none,
            scope: .leg(scope),
            relatedActionID: nil,
            relatedPolicyID: .jrShinkansenOversizedBaggage,
            relatedGuideID: nil,
            completionCondition: .userConfirmsDone
        )
    }
}
