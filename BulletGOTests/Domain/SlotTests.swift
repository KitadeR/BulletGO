import Foundation
import Testing
@testable import BulletGO

@MainActor
struct SlotTests {
    private let now = DomainTestSupport.timestamp

    @Test func unknownRejectsValue() {
        #expect(throws: DomainError.invalidSlotCombination(status: .unknown, source: nil, hasValue: true)) {
            try Slot(value: "Tokyo", status: .unknown, source: nil, confidence: nil, collectionTiming: .immediate, presentationTiming: .immediate, updatedAt: now)
        }
    }

    @Test func inferredRequiresValueAndAISource() throws {
        let slot = try Slot<String>.inferred(value: "shinkansen", updatedAt: now)
        #expect(slot.status == .inferred)
        #expect(slot.source == .aiInferred)
        #expect(slot.value == "shinkansen")

        #expect(throws: DomainError.invalidSlotCombination(status: .inferred, source: .userStated, hasValue: true)) {
            try Slot(value: "shinkansen", status: .inferred, source: .userStated, confidence: .medium, collectionTiming: .immediate, presentationTiming: .immediate, updatedAt: now)
        }
    }

    @Test func confirmedRejectsAIInferredSource() {
        #expect(throws: DomainError.confirmedSlotRequiresNonInferredSource) {
            try Slot<String>.confirmed(value: "Kyoto", source: .aiInferred, updatedAt: now)
        }
    }

    @Test func confirmedAcceptsUserStatedValue() throws {
        let slot = try Slot.confirmed(value: "Kyoto", source: .userStated, updatedAt: now)
        #expect(slot.status == .confirmed)
        #expect(slot.source == .userStated)
        #expect(slot.value == "Kyoto")
    }

    @Test func deferredPresentationIsIndependentOfStatus() throws {
        let fujiSeat = try Slot.confirmed(
            value: "Mt. Fuji view seat",
            source: .userStated,
            presentationTiming: .deferred(until: .seatSelection),
            updatedAt: now
        )
        #expect(fujiSeat.status == .confirmed)
        #expect(fujiSeat.presentationTiming == .deferred(until: .seatSelection))
    }

    @Test func justInTimeCollectionIsIndependentOfStatus() throws {
        let dimensions = try Slot<BaggageDimensions>.unknown(
            collectionTiming: .justInTime(.baggagePolicyEvaluation),
            updatedAt: now
        )
        #expect(dimensions.status == .unknown)
        #expect(dimensions.value == nil)
        #expect(dimensions.collectionTiming == .justInTime(.baggagePolicyEvaluation))
    }

    @Test func updatingKeepsRevisionHistory() throws {
        let original = try Slot.inferred(value: 2, confidence: .low, updatedAt: now)
        let updated = try original.updating(
            value: 2,
            status: .confirmed,
            source: .userConfirmed,
            confidence: .high,
            at: now.addingTimeInterval(60)
        )
        #expect(updated.status == .confirmed)
        #expect(updated.source == .userConfirmed)
        #expect(updated.revisions.count == 1)
        #expect(updated.revisions[0].status == .inferred)
        #expect(updated.revisions[0].source == .aiInferred)
        #expect(updated.revisions[0].value == 2)
    }

    @Test func negativeAllowsFalseValue() throws {
        let slot = try Slot.negative(value: false, updatedAt: now)
        #expect(slot.status == .negative)
        #expect(slot.value == false)
    }
}
