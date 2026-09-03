import Foundation
import SwiftData

@Model
final class TripRecord {
    @Attribute(.unique) var tripID: UUID
    var displayName: String
    var startDateSortKey: String?
    var payloadVersion: Int
    var domainSchemaVersion: Int
    var payload: Data
    var createdAt: Date
    var updatedAt: Date

    init(
        tripID: UUID,
        displayName: String,
        startDateSortKey: String?,
        payloadVersion: Int,
        domainSchemaVersion: Int,
        payload: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.tripID = tripID
        self.displayName = displayName
        self.startDateSortKey = startDateSortKey
        self.payloadVersion = payloadVersion
        self.domainSchemaVersion = domainSchemaVersion
        self.payload = payload
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
