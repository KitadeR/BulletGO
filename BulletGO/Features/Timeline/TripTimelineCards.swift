import SwiftUI

struct TripsCompactHeader: View {
    var title: String
    var datesText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(verbatim: title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let datesText {
                Text(verbatim: datesText)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

struct TripsDateSelector: View {
    var options: [TripsDayOption]
    var selectedDate: LocalDate?
    var onSelect: (LocalDate) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(options) { option in
                        Button {
                            onSelect(option.date)
                        } label: {
                            VStack(spacing: 2) {
                                Text(verbatim: TripsDateFormatting.monthToken(option.date))
                                    .font(DesignTokens.Typography.footnote)
                                Text(verbatim: "\(option.date.day)")
                                    .font(DesignTokens.Typography.headline)
                            }
                            .foregroundStyle(
                                selectedDate == option.date
                                    ? DesignTokens.Color.elevated
                                    : DesignTokens.Color.primaryText
                            )
                            .frame(minWidth: DesignTokens.TapTarget.minimum, minHeight: DesignTokens.TapTarget.minimum)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .contentShape(Rectangle())
                            .background(
                                selectedDate == option.date
                                    ? DesignTokens.Color.tint
                                    : DesignTokens.Color.grouped,
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            )
                            .opacity(option.hasItems || selectedDate == option.date ? 1 : 0.55)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: TripsDateFormatting.full(option.date)))
                        .accessibilityAddTraits(selectedDate == option.date ? .isSelected : [])
                        .accessibilityIdentifier(AccessibilityID.tripsDateOption(option.date))
                        .id(ItineraryDayComposer.selectorAnchor(for: option.date))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(AccessibilityID.tripsDateSelector)
            .onChange(of: selectedDate) { _, date in
                guard let date else { return }
                proxy.scrollTo(ItineraryDayComposer.selectorAnchor(for: date), anchor: .center)
            }
        }
    }
}

struct TripsDayHeader: View {
    var date: LocalDate

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(verbatim: "\(date.day)")
                .font(DesignTokens.Typography.display)
                .foregroundStyle(DesignTokens.Color.primaryText)
            Text(verbatim: "\(TripsDateFormatting.monthToken(date)) · \(TripsDateFormatting.weekday(date))")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: TripsDateFormatting.full(date)))
        .accessibilityIdentifier(AccessibilityID.tripsDaySection(date))
    }
}

struct TripsEmptyDayState: View {
    var date: LocalDate
    var addTitle: LocalizedStringResource
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Nothing planned yet")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityID.tripsEmptyDay)
            Button(action: onAdd) {
                Label {
                    Text(addTitle)
                } icon: {
                    Image(systemName: "plus")
                }
                .font(DesignTokens.Typography.body)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityID.tripsDayAdd(date))
        }
    }
}

struct TripsDayAddButton: View {
    var date: LocalDate
    var title: LocalizedStringResource
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "plus")
            }
            .font(DesignTokens.Typography.body)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(AccessibilityID.tripsDayAdd(date))
    }
}

struct TripLegCard: View {
    var row: TimelineRow

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            JourneyArtwork(kind: row.visualKind, isCompact: true)
                .frame(width: 88, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                if let timeText = row.timeText {
                    Text(verbatim: timeText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
                Text(verbatim: row.title)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DisplayTextLabel(text: row.subtitle)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .opaqueSurface(cornerRadius: DesignTokens.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(legID)
    }

    private var legID: String {
        if case .leg(let id) = row.id {
            return AccessibilityID.timelineLeg(id)
        }
        return ""
    }
}

struct TripsPreparationRow: View {
    var indication: TripsPreparationIndication
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(DesignTokens.Color.caution)
                    .accessibilityHidden(true)
                Text(indication.title)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DesignTokens.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .frame(minHeight: DesignTokens.TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.tripsPreparation)
    }
}

struct TripStayCard: View {
    var row: TimelineRow

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            fallbackVisual(systemImage: "bed.double.fill")
            VStack(alignment: .leading, spacing: 2) {
                if let timeText = row.timeText {
                    Text(verbatim: timeText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
                Text(verbatim: row.title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DisplayTextLabel(text: row.subtitle)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(stayID)
    }

    private var stayID: String {
        if case .stay(let id, let role) = row.id {
            return AccessibilityID.timelineStay(id, role: role)
        }
        return ""
    }
}

struct TripActivityCard: View {
    var row: TimelineRow

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            fallbackVisual(systemImage: "mappin.and.ellipse")
            VStack(alignment: .leading, spacing: 2) {
                if let timeText = row.timeText {
                    Text(verbatim: timeText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
                Text(verbatim: row.title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DisplayTextLabel(text: row.subtitle)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(activityID)
    }

    private var activityID: String {
        if case .activity(let id) = row.id {
            return AccessibilityID.timelineActivity(id)
        }
        return ""
    }
}

struct TripTimelineConnector: View {
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: DesignTokens.Spacing.xxs) {
                Circle()
                    .fill(DesignTokens.Color.stroke)
                    .frame(width: 6, height: 6)
                Rectangle()
                    .fill(DesignTokens.Color.stroke)
                    .frame(width: 2, height: 18)
            }
            Spacer()
        }
        .accessibilityHidden(true)
    }
}

private func fallbackVisual(systemImage: String) -> some View {
    Image(systemName: systemImage)
        .font(DesignTokens.Typography.title)
        .foregroundStyle(DesignTokens.Color.remembered)
        .frame(width: 72, height: 56)
        .background(
            DesignTokens.Color.tintSoft,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
        )
        .accessibilityHidden(true)
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
