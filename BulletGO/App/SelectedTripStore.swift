import Foundation

protocol SelectedTripStoring: Sendable {
    func load() -> TripID?
    func save(_ id: TripID?)
}

struct UserDefaultsSelectedTripStore: SelectedTripStoring {
    static let key = "bulletgo.selectedTripID"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> TripID? {
        guard let raw = defaults.string(forKey: Self.key), let uuid = UUID(uuidString: raw) else {
            return nil
        }
        return TripID(rawValue: uuid)
    }

    func save(_ id: TripID?) {
        if let id {
            defaults.set(id.rawValue.uuidString, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }
}

final class InMemorySelectedTripStore: SelectedTripStoring, @unchecked Sendable {
    private var value: TripID?

    init(_ value: TripID? = nil) {
        self.value = value
    }

    func load() -> TripID? { value }

    func save(_ id: TripID?) { value = id }
}
