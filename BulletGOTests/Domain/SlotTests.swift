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

    @Test func updatingCanChangeCollectionTimingWhileKeepingRevisions() throws {
        let original = try Slot<BaggageDimensions>.unknown(updatedAt: now)
        let updated = try original.updating(
            value: nil,
            status: .unknown,
            source: nil,
            confidence: nil,
            collectionTiming: .justInTime(.baggagePolicyEvaluation),
            at: now.addingTimeInterval(30)
        )
        #expect(updated.collectionTiming == .justInTime(.baggagePolicyEvaluation))
        #expect(updated.presentationTiming == .immediate)
        #expect(updated.revisions.count == 1)
        #expect(updated.revisions[0].status == .unknown)
        #expect(updated.revisions[0].collectionTiming == .immediate)
        #expect(updated.revisions[0].presentationTiming == .immediate)
    }

    @Test func negativeAllowsFalseValue() throws {
        let slot = try Slot.negative(value: false, updatedAt: now)
        #expect(slot.status == .negative)
        #expect(slot.value == false)
    }

    @Test func decodeRejectsUnknownSlotWithValue() throws {
        let slot = try Slot<String>.unknown(updatedAt: now)
        var json = try jsonObject(from: slot)
        json["value"] = "Tokyo"
        #expect(throws: DomainError.invalidSlotCombination(status: .unknown, source: nil, hasValue: true)) {
            try decodeSlot(json)
        }
    }

    @Test func decodeRejectsConfirmedSlotWithAIInferredSource() throws {
        let slot = try Slot.confirmed(value: "Kyoto", source: .userStated, updatedAt: now)
        var json = try jsonObject(from: slot)
        json["source"] = "aiInferred"
        #expect(throws: DomainError.confirmedSlotRequiresNonInferredSource) {
            try decodeSlot(json)
        }
    }

    private func jsonObject(from slot: Slot<String>) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(slot)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    private func decodeSlot(_ json: [String: Any]) throws -> Slot<String> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(Slot<String>.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
