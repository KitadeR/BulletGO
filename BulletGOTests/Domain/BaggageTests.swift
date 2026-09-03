import Foundation
import Testing
@testable import BulletGO

@MainActor
struct BaggageTests {
    @Test func dimensionsRequirePositiveValues() {
        #expect(throws: DomainError.invalidBaggageDimension) {
            try BaggageDimensions(lengthCM: 0, widthCM: 50, heightCM: 30)
        }
        #expect(throws: DomainError.invalidBaggageDimension) {
            try BaggageDimensions(lengthCM: 80, widthCM: -1, heightCM: 30)
        }
    }

    @Test func totalCMSumsThreeSides() throws {
        let dimensions = try BaggageDimensions(lengthCM: 80, widthCM: 50, heightCM: 30)
        #expect(dimensions.totalCM == 160)
    }

    @Test func decodeRejectsNonPositiveDimensions() {
        let data = Data(#"{"lengthCM":0,"widthCM":50,"heightCM":30}"#.utf8)
        #expect(throws: DomainError.invalidBaggageDimension) {
            try JSONDecoder().decode(BaggageDimensions.self, from: data)
        }
    }

    @Test func bagDoesNotStorePolicyClassification() throws {
        let now = DomainTestSupport.timestamp
        let bag = Bag(
            id: BagID(),
            kind: try Slot.inferred(value: .suitcase, updatedAt: now),
            userDescription: try Slot.confirmed(value: "huge", source: .userStated, updatedAt: now),
            perceivedSize: try Slot.inferred(value: .large, updatedAt: now),
            dimensions: try Slot.unknown(
                collectionTiming: .justInTime(.baggagePolicyEvaluation),
                updatedAt: now
            ),
            weightKilograms: try Slot.unknown(updatedAt: now),
            createdAt: now
        )
        #expect(bag.perceivedSize.value == .large)
        #expect(bag.dimensions.status == .unknown)
    }
}
