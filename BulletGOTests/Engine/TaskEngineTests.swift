import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TaskEngineTests {
    @Test func policyToActionToTaskUsesPackTemplates() throws {
        let pack = try EngineTestSupport.pack()
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        let actions = ActionResolver.resolve(trip: trip, pack: pack)
        #expect(actions.map(\.purposeKey).contains(ActionPurpose.reserveOversizedSeat))
        #expect(actions.map(\.purposeKey).contains(ActionPurpose.selectBookingMethod))
        let tasks = try TripTaskGenerator.generate(actions: actions, trip: trip, pack: pack)
        #expect(Set(tasks.map(\.contentKey)).isSuperset(of: [
            ActionPurpose.reserveOversizedSeat,
            ActionPurpose.selectBookingMethod,
        ]))
        #expect(tasks.allSatisfy { $0.relatedPolicyID == pack.id })
    }

    @Test func rerunningKeepsTaskIdentityAndCompletedState() throws {
        let pack = try EngineTestSupport.pack()
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        let first = try TripTaskGenerator.generate(
            actions: ActionResolver.resolve(trip: trip, pack: pack),
            trip: trip,
            pack: pack
        )
        var existing = first
        existing[0].state = .completed
        existing[0].evidence = .userStated
        let second = try TripTaskGenerator.generate(
            actions: ActionResolver.resolve(trip: trip, pack: pack),
            trip: trip,
            pack: pack
        )
        let reconciled = TaskReconciler.reconcile(
            existing: existing,
            desired: second,
            focusLegID: trip.legs[0].id,
            impact: ImpactAssessment(level: .low, targetLegs: [], changedPaths: [])
        )
        let matched = try #require(reconciled.first { $0.contentKey == existing[0].contentKey })
        #expect(matched.id == existing[0].id)
        #expect(matched.state == .completed)
        #expect(matched.evidence == .userStated)
        #expect(reconciled.filter { $0.contentKey == existing[0].contentKey }.count == 1)
    }

    @Test func completedTaskNeedsReviewWhenDependencyPathChanges() throws {
        let pack = try EngineTestSupport.pack()
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        var tasks = try TripTaskGenerator.generate(
            actions: ActionResolver.resolve(trip: trip, pack: pack),
            trip: trip,
            pack: pack
        )
        let index = try #require(tasks.firstIndex(where: { $0.contentKey == ActionPurpose.reserveOversizedSeat }))
        tasks[index].state = .completed
        let desired = try TripTaskGenerator.generate(
            actions: ActionResolver.resolve(trip: trip, pack: pack),
            trip: trip,
            pack: pack
        )
        let reconciled = TaskReconciler.reconcile(
            existing: tasks,
            desired: desired,
            focusLegID: trip.legs[0].id,
            impact: ImpactAssessment(
                level: .low,
                targetLegs: [trip.legs[0].id],
                changedPaths: [.bag(PolicyScenarioSupport.bagA, .dimensions)]
            )
        )
        let reserve = try #require(reconciled.first { $0.contentKey == ActionPurpose.reserveOversizedSeat })
        #expect(reserve.state == TaskState.needsReview)
        #expect(reserve.id == tasks[index].id)
    }

    @Test func vanishedPrerequisiteCancelsFocusTaskAndLeavesOtherLegs() throws {
        let pack = try EngineTestSupport.pack()
        var trip = try PolicyScenarioSupport.trip(
            bags: [(PolicyScenarioSupport.bagA, PolicyScenarioSupport.dimensions(length: 80, width: 50, height: 31))]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        var tasks = try TripTaskGenerator.generate(
            actions: ActionResolver.resolve(trip: trip, pack: pack),
            trip: trip,
            pack: pack
        )
        let other = TripTask(
            id: TaskID(),
            contentKey: "other_leg_task",
            type: .check,
            state: .notStarted,
            importance: .optional,
            relevantPhases: [.planning],
            deadline: nil,
            dependencies: [],
            evidence: .none,
            scope: .leg(trip.legs[1].id),
            relatedActionID: nil,
            relatedPolicyID: pack.id,
            relatedGuideID: nil,
            completionCondition: .userConfirmsDone
        )
        tasks.append(other)
        let reconciled = TaskReconciler.reconcile(
            existing: tasks,
            desired: [],
            focusLegID: trip.legs[0].id,
            impact: ImpactAssessment(level: .high, targetLegs: [trip.legs[0].id], changedPaths: [])
        )
        #expect(reconciled.contains { $0.id == other.id && $0.state == .notStarted })
        #expect(reconciled.filter { $0.scope == .leg(trip.legs[0].id) }.allSatisfy { $0.state == .cancelled })
    }
}
