import Foundation

nonisolated enum AppFeature: String, CaseIterable, Hashable, Identifiable, Sendable {
    case baggageCheck = "baggage_check"
    case departureReminder = "departure_reminder"
    case operationStatus = "operation_status"
    case ocrItinerary = "ocr_itinerary"
    case bookingMethod = "booking_method"
    case vehicleEquipment = "vehicle_equipment"
    case gateToPlatform = "gate_to_platform"
    case liveActivity = "live_activity"
    case stationInfo = "station_info"
    case tripSharing = "trip_sharing"

    var id: String { rawValue }
}
