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

struct TripsDaySection: View {
    var section: ItinerarySection
    var trip: Trip
    var catalog: QuestionCatalog?
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
                VStack(alignment: .leading, spacing: TripsV2Style.rowSpacing) {
                    ForEach(section.rows) { row in
                        TripsTimelineItemRow(
                            row: row,
                            trip: trip,
                            catalog: catalog,
                            locale: locale
                        )
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
