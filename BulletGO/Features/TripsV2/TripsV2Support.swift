import SwiftUI

enum TripsV2Style {
    static let canvas = Color(red: 249 / 255, green: 249 / 255, blue: 250 / 255)
    static let selectedFill = Color(red: 247 / 255, green: 250 / 255, blue: 1)
    static let selectedStroke = Color(red: 209 / 255, green: 222 / 255, blue: 250 / 255)
    static let accent = Color(red: 26 / 255, green: 99 / 255, blue: 245 / 255)
    static let guide = Color.primary.opacity(0.12)
    static let placeholderFill = Color(red: 240 / 255, green: 240 / 255, blue: 247 / 255)
    static let screenPadding: CGFloat = 20
    static let gutterWidth: CGFloat = 54
    static let guideWidth: CGFloat = 1
    static let cardGap: CGFloat = 7
    static let dateChipSize = CGSize(width: 62, height: 48)
    static let dateChipSpacing: CGFloat = 8
}

nonisolated enum TripsV2Formatting {
    static func destinations(in trip: Trip) -> String {
        var seen = Set<String>()
        var result: [String] = []
        for leg in trip.legs {
            append(leg.origin.value, into: &result, seen: &seen)
            append(leg.destination.value, into: &result, seen: &seen)
        }
        return result.joined(separator: "・")
    }

    static func dateRange(for trip: Trip, locale: Locale) -> String? {
        guard let start = trip.startDate.value, let end = trip.endDate.value else {
            return TripContentResolver.tripDatesText(trip)
        }
        return "\(formatDay(start, locale: locale, weekday: false))〜\(formatDay(end, locale: locale, weekday: false))"
    }

    static func dayHeading(_ date: LocalDate, locale: Locale) -> String {
        formatDay(date, locale: locale, weekday: true)
    }

    static func weekday(_ date: LocalDate, locale: Locale) -> String {
        formatted(date, locale: locale, format: "EEE")
    }

    static func placeLabel(for section: ItinerarySection) -> String? {
        guard let first = section.rows.first else {
            return nil
        }
        if first.isLeg {
            return first.title
        }
        if case .verbatim(let value) = first.subtitle, !value.isEmpty {
            return value
        }
        return nil
    }

    private static func append(_ value: String?, into result: inout [String], seen: inout Set<String>) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, seen.insert(trimmed).inserted else {
            return
        }
        result.append(trimmed)
    }

    private static func formatDay(_ date: LocalDate, locale: Locale, weekday: Bool) -> String {
        formatted(date, locale: locale, format: weekday ? "M月d日（EEE）" : "M月d日")
    }

    private static func formatted(_ date: LocalDate, locale: Locale, format: String) -> String {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        guard let value = date.date(in: timeZone) else {
            return date.displayString
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: value)
    }
}
