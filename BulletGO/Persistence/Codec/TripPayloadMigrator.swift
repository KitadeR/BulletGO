import Foundation

nonisolated enum TripPayloadMigrator {
    static let currentDomainSchemaVersion = Trip.currentSchemaVersion

    static func migrateV1Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateReservations(in: &json, timestamp: timestamp)
            migrateSeatPreferences(in: &json, timestamp: timestamp)
            migrateStays(in: &json)
            migrateFoundationV1(in: &json, timestamp: timestamp)
            migrateDaySubtitles(in: &json)
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    static func migrateV2Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateSeatPreferences(in: &json, timestamp: timestamp)
            migrateStays(in: &json)
            migrateFoundationV1(in: &json, timestamp: timestamp)
            migrateDaySubtitles(in: &json)
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    static func migrateV3Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateStays(in: &json)
            migrateFoundationV1(in: &json, timestamp: timestamp)
            migrateDaySubtitles(in: &json)
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    static func migrateV4Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateFoundationV1(in: &json, timestamp: timestamp)
            migrateDaySubtitles(in: &json)
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    static func migrateV5Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateDaySubtitles(in: &json)
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    static func migrateV6Payload(_ data: Data) throws -> Data {
        try migrate(data) { json, timestamp in
            migrateScheduleV7(in: &json, timestamp: timestamp)
        }
    }

    private static func migrate(
        _ data: Data,
        mutate: (inout [String: Any], Double) -> Void
    ) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PersistenceError.decodingFailed
        }
        let timestamp = json["updatedAt"] as? Double ?? json["createdAt"] as? Double ?? 0
        mutate(&json, timestamp)
        json["schemaVersion"] = currentDomainSchemaVersion
        return try JSONSerialization.data(withJSONObject: json)
    }

    private static func migrateStays(in trip: inout [String: Any]) {
        if trip["stays"] == nil {
            trip["stays"] = [Any]()
        }
    }

    private static func migrateFoundationV1(in trip: inout [String: Any], timestamp: Double) {
        if trip["savedPlaces"] == nil { trip["savedPlaces"] = [Any]() }
        if trip["notes"] == nil { trip["notes"] = [Any]() }
        if trip["attachments"] == nil { trip["attachments"] = [Any]() }
        if trip["connectorEstimates"] == nil { trip["connectorEstimates"] = [Any]() }
        if var legs = trip["legs"] as? [[String: Any]] {
            for index in legs.indices where legs[index]["arrivesAt"] == nil {
                legs[index]["arrivesAt"] = slotJSON(for: "unknown", timestamp: timestamp)
            }
            trip["legs"] = legs
        }
        if var activities = trip["activities"] as? [[String: Any]] {
            for index in activities.indices where activities[index]["endsAt"] == nil {
                activities[index]["endsAt"] = slotJSON(for: "unknown", timestamp: timestamp)
            }
            trip["activities"] = activities
        }
    }

    private static func migrateDaySubtitles(in trip: inout [String: Any]) {
        if trip["daySubtitles"] == nil {
            trip["daySubtitles"] = [Any]()
        }
    }

    private static func migrateScheduleV7(in trip: inout [String: Any], timestamp: Double) {
        trip["connectorEstimates"] = [Any]()
        if var legs = trip["legs"] as? [[String: Any]] {
            for index in legs.indices {
                liftEndTime(from: &legs[index], startKey: "scheduledAt", endKey: "arrivesAt", timestamp: timestamp)
            }
            trip["legs"] = legs
        }
        if var stays = trip["stays"] as? [[String: Any]] {
            for index in stays.indices {
                liftEndTime(from: &stays[index], startKey: "checkIn", endKey: "checkOut", timestamp: timestamp)
            }
            trip["stays"] = stays
        }
        if var activities = trip["activities"] as? [[String: Any]] {
            for index in activities.indices {
                liftEndTime(from: &activities[index], startKey: "scheduledAt", endKey: "endsAt", timestamp: timestamp)
            }
            trip["activities"] = activities
        }
    }

    private static func migrateMomentSlot(in owner: inout [String: Any], key: String) {
        guard var slot = owner[key] as? [String: Any], var value = slot["value"] as? [String: Any] else {
            return
        }
        value.removeValue(forKey: "endTime")
        slot["value"] = value
        owner[key] = slot
    }

    private static func liftEndTime(
        from owner: inout [String: Any],
        startKey: String,
        endKey: String,
        timestamp: Double
    ) {
        guard var startSlot = owner[startKey] as? [String: Any],
              var startValue = startSlot["value"] as? [String: Any],
              let endTime = startValue["endTime"]
        else {
            migrateMomentSlot(in: &owner, key: startKey)
            return
        }
        startValue.removeValue(forKey: "endTime")
        startSlot["value"] = startValue
        owner[startKey] = startSlot

        let endUnknown: Bool = {
            guard let endSlot = owner[endKey] as? [String: Any] else { return true }
            return endSlot["status"] as? String == "unknown" || endSlot["value"] == nil
        }()
        guard endUnknown else {
            return
        }
        var endValue = startValue
        endValue["time"] = endTime
        endValue["isAllDay"] = false
        owner[endKey] = [
            "status": "confirmed",
            "value": endValue,
            "source": "userStated",
            "confidence": "high",
            "collectionTiming": ["immediate": [String: Any]()],
            "presentationTiming": ["immediate": [String: Any]()],
            "updatedAt": timestamp,
            "revisions": [Any](),
        ] as [String: Any]
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

    private static func migrateSeatPreferences(in trip: inout [String: Any], timestamp: Double) {
        guard var legs = trip["legs"] as? [[String: Any]] else {
            return
        }
        for index in legs.indices where legs[index]["seatPreference"] == nil {
            legs[index]["seatPreference"] = slotJSON(for: "unknown", timestamp: timestamp)
        }
        trip["legs"] = legs
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
