import Foundation
import Testing
@testable import BulletGO

@MainActor
struct TaskSeparationTests {
    @Test func completedTaskCanCoexistWithUserStatedEvidenceAndActionRequiredReadiness() throws {
        let trip = try DomainTestSupport.sampleTrip()
        let legID = trip.legs[0].id
        let now = DomainTestSupport.timestamp

        let task = TripTask(
            id: TaskID(),
            contentKey: "reserve_shinkansen",
            type: .book,
            state: .completed,
            importance: .required,
            relevantPhases: [.booking],
            deadline: nil,
            dependencies: [TaskDependency(path: .leg(legID, .reservation), requiredTaskID: nil)],
            evidence: .userStated,
            scope: .leg(legID),
            relatedActionID: nil,
            relatedPolicyID: PolicyID(rawValue: "jr_shinkansen_oversized_baggage"),
            relatedGuideID: nil,
            completionCondition: .userConfirmsDone
        )

        var reservation = try DomainTestSupport.emptyReservation()
        reservation.status = try Slot.confirmed(value: .booked, source: .userStated, updatedAt: now)
        reservation.progress = .completed
        reservation.evidenceLevel = .userStated
        reservation.evidenceHistory = [
            ReservationEvidenceRecord(level: .userStated, capturedAt: now, sourceTaskID: task.id, documentType: nil),
        ]

        let readiness = ReadinessCheck(
            id: ReadinessCheckID(),
            checkType: .baggageReservation,
            scope: .leg(legID),
            relatedPolicyID: PolicyID(rawValue: "jr_shinkansen_oversized_baggage"),
            status: .actionRequired,
            documentSignal: .unverified,
            detailKey: "check_oversized_seat",
            evidenceSources: ["reservation.details"],
            evaluatedAt: now,
            stale: false
        )

        #expect(task.state == .completed)
        #expect(reservation.evidenceLevel == .userStated)
        #expect(readiness.status == .actionRequired)
        #expect(task.state == .completed && reservation.evidenceLevel == .userStated && readiness.status == .actionRequired)
    }

    @Test func actionRequirementRemainsASkeletonContract() {
        let action = ActionRequirement(
            id: ActionRequirementID(),
            purposeKey: "select_booking_method",
            importance: .mustDo,
            relatedPolicyID: PolicyID(rawValue: "jr_shinkansen_oversized_baggage"),
            requiredStateSummary: "transport_mode confirmed",
            completionCondition: "booking_service != unknown"
        )
        #expect(action.importance == .mustDo)
    }
}
