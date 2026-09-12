import Foundation

nonisolated enum TripsFloatingAddAction: Equatable, Sendable {
    case activity
    case leg
    case stay
}

nonisolated enum TripsFloatingAddComposer {
    static func dayLabel(date: LocalDate, locale: Locale) -> String {
        TripsV2Formatting.addMenuDayLabel(date, locale: locale)
    }
}
