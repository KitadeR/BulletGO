import SwiftUI

struct TripsTimingGutter: View {
    var display: TripsTimingGutterDisplay

    var body: some View {
        Text(verbatim: gutterText)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DesignTokens.Color.primaryText)
            .frame(width: TripsV2Style.gutterWidth, alignment: .leading)
            .accessibilityHidden(gutterText.isEmpty)
    }

    private var gutterText: String {
        switch display {
        case .none:
            ""
        case .exact(let text):
            text
        }
    }
}

struct TripsTimelineGuide: View {
    var body: some View {
        Rectangle()
            .fill(TripsV2Style.guide)
            .frame(width: TripsV2Style.guideWidth)
            .accessibilityHidden(true)
    }
}

struct TripsPlaceholderRow: View {
    var row: TimelineRow

    var body: some View {
        HStack(alignment: .top, spacing: TripsV2Style.cardGap) {
            TripsTimingGutter(display: row.gutterDisplay)
            Text(verbatim: row.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.primaryText)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .padding(14)
                .background(
                    DesignTokens.Color.elevated,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(rowIdentifier)
    }

    private var rowIdentifier: String {
        switch row.id {
        case .leg(let id):
            AccessibilityID.timelineLeg(id)
        case .stay(let id):
            AccessibilityID.timelineStay(id)
        case .activity(let id):
            AccessibilityID.timelineActivity(id)
        }
    }
}

struct TripsDaySection: View {
    var section: ItinerarySection
    var locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let date = section.date {
                TripsDaySectionHeader(
                    date: date,
                    place: TripsV2Formatting.placeLabel(for: section),
                    locale: locale
                )
            } else {
                Text(section.title)
                    .font(.system(size: 23, weight: .semibold))
                    .padding(.horizontal, TripsV2Style.screenPadding)
            }

            if section.rows.isEmpty {
                Text("Nothing planned yet")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .padding(.horizontal, TripsV2Style.screenPadding)
                    .accessibilityIdentifier(AccessibilityID.tripsEmptyDay)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(section.rows) { row in
                        TripsPlaceholderRow(row: row)
                    }
                }
                .padding(.horizontal, TripsV2Style.screenPadding)
                .overlay(alignment: .leading) {
                    TripsTimelineGuide()
                        .padding(.leading, TripsV2Style.screenPadding + TripsV2Style.gutterWidth)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
