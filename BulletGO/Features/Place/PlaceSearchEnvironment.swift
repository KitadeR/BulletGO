import SwiftUI

enum PlaceSearchFactory {
    static func make(isUITesting: Bool) -> any PlaceSearching {
        isUITesting ? FakePlaceSearch.uiTesting : MapKitPlaceSearch()
    }
}

extension EnvironmentValues {
    @Entry var placeSearching: (any PlaceSearching)? = nil
}
