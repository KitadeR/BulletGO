import SwiftUI

struct TripsEmptyDayState: View {
    var date: LocalDate
    var addTitle: LocalizedStringResource
    var onSelect: (TripsFloatingAddAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Nothing planned yet")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.tripsEmptyDay)
            TripsDayAddButton(date: date, title: addTitle, onSelect: onSelect)
        }
    }
}

struct TripsDayAddButton: View {
    var date: LocalDate
    var title: LocalizedStringResource
    var onSelect: (TripsFloatingAddAction) -> Void

    var body: some View {
        Menu {
            TripsAddKindMenuItems(onSelect: onSelect)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "plus")
            }
            .font(DesignTokens.Typography.body)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(AccessibilityID.tripsDayAdd(date))
    }
}

enum TripsDateFormatting {
    static func weekday(_ date: LocalDate) -> String {
        formatted(date, format: "EEE").uppercased()
    }

    static func monthToken(_ date: LocalDate) -> String {
        formatted(date, format: "MMM").uppercased()
    }

    static func full(_ date: LocalDate) -> String {
        formatted(date, format: "MMMM d, yyyy")
    }

    static func addDayLabel(_ date: LocalDate) -> String {
        formatted(date, format: "MMM d")
    }

    private static func formatted(_ date: LocalDate, format: String) -> String {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let value = date.date(in: utc) else {
            return date.displayString
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = .current
        formatter.timeZone = utc
        formatter.dateFormat = format
        return formatter.string(from: value)
    }
}
