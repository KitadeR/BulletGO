import Foundation

nonisolated enum TripPayloadMigrator {
    static let currentDomainSchemaVersion = 2

    static func migrateV1Payload(_ data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PersistenceError.decodingFailed
        }
        let timestamp = json["updatedAt"] as? Double ?? json["createdAt"] as? Double ?? 0
        migrateReservations(in: &json, timestamp: timestamp)
        json["schemaVersion"] = currentDomainSchemaVersion
        return try JSONSerialization.data(withJSONObject: json)
    }

    private static func migrateReservations(in trip: inout [String: Any], timestamp: Double) {
        if var legs = trip["legs"] as? [[String: Any]] {
            for index in legs.indices {
                migrateReservation(in: &legs[index], timestamp: timestamp)
            }
            trip["legs"] = legs
        }
        if var activities = trip["activities"] as? [[String: Any]] {
            for index in activities.indices {
                migrateReservation(in: &activities[index], timestamp: timestamp)
            }
            trip["activities"] = activities
        }
    }

    private static func migrateReservation(in owner: inout [String: Any], timestamp: Double) {
        guard var reservation = owner["reservation"] as? [String: Any] else {
            return
        }
        if let status = reservation["status"] as? String {
            reservation["status"] = slotJSON(for: status, timestamp: timestamp)
        }
        owner["reservation"] = reservation
    }

    private static func slotJSON(for status: String, timestamp: Double) -> [String: Any] {
        var json: [String: Any] = [
            "status": status == "unknown" ? "unknown" : "confirmed",
            "collectionTiming": ["immediate": [String: Any]()],
            "presentationTiming": ["immediate": [String: Any]()],
            "updatedAt": timestamp,
            "revisions": [Any](),
        ]
        if status != "unknown" {
            json["value"] = status
            json["source"] = "userStated"
            json["confidence"] = "high"
        }
        return json
    }
}
