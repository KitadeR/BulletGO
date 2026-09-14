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
    @Environment(TripSessionModel.self) private var session

    var section: ItinerarySection
    var trip: Trip
    var catalog: QuestionCatalog?
    var locale: Locale
    var onAdd: (LocalDate, TripsFloatingAddAction) -> Void
    var onMove: (TimelineRow, Int) -> Void
    var onMoveToDate: (TimelineRow, LocalDate?) -> Void
    var onDelete: (TimelineRow) -> Void
    var onEditSubtitle: (LocalDate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let date = section.date {
                TripsDaySectionHeader(
                    date: date,
                    subtitle: trip.daySubtitle(on: date),
                    locale: locale,
                    onEditSubtitle: { onEditSubtitle(date) }
                )
            } else {
                Text(section.title)
                    .font(.system(size: 23, weight: .semibold))
                    .padding(.horizontal, TripsV2Style.screenPadding)
            }

            if section.rows.isEmpty, let date = section.date {
                TripsEmptyDayState(
                    date: date,
                    addTitle: addTitle(for: date),
                    onSelect: { onAdd(date, $0) }
                )
                .padding(.horizontal, TripsV2Style.screenPadding)
            } else {
                VStack(alignment: .leading, spacing: TripsV2Style.rowSpacing) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        VStack(alignment: .leading, spacing: 8) {
                            if index > 0 {
                                ConnectorEstimateRow(
                                    from: section.rows[index - 1],
                                    to: row,
                                    trip: trip
                                )
                            }
                            TripsTimelineItemRow(
                                row: row,
                                trip: trip,
                                catalog: catalog,
                                locale: locale
                            )
                            .contextMenu {
                                menu(for: row)
                            }
                            .accessibilityAction(named: Text("Move up")) { onMove(row, -1) }
                            .accessibilityAction(named: Text("Move down")) { onMove(row, 1) }
                            .accessibilityAction(named: Text("Delete")) { onDelete(row) }
                        }
                    }
                }
                .padding(.horizontal, TripsV2Style.screenPadding)
                .overlay(alignment: .leading) {
                    TripsTimelineGuide()
                        .padding(.leading, TripsV2Style.screenPadding + TripsV2Style.gutterWidth)
                }
                if let date = section.date {
                    TripsDayAddButton(
                        date: date,
                        title: addTitle(for: date),
                        onSelect: { onAdd(date, $0) }
                    )
                    .padding(.horizontal, TripsV2Style.screenPadding)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(sectionIdentifier)
    }

    @ViewBuilder
    private func menu(for row: TimelineRow) -> some View {
        if !row.id.isProjectedStay {
            Button("Move up") { onMove(row, -1) }
            Button("Move down") { onMove(row, 1) }
            Menu("Move to day") {
                ForEach(ItineraryDayComposer.dateOptions(for: trip), id: \.self) { date in
                    Button(date.displayString) { onMoveToDate(row, date) }
                }
                Button("Unscheduled") { onMoveToDate(row, nil) }
            }
        }
        Button("Delete", role: .destructive) { onDelete(row) }
    }

    private func addTitle(for date: LocalDate) -> LocalizedStringResource {
        LocalizedStringResource(
            "Add to \(TripsDateFormatting.addDayLabel(date))",
            comment: "Menu that opens Guided Add with this day prefilled."
        )
    }

    private var sectionIdentifier: String {
        if let date = section.date {
            return AccessibilityID.tripsDaySection(date)
        }
        return AccessibilityID.itineraryUnscheduled
    }
}

struct ConnectorEstimateRow: View {
    @Environment(TripSessionModel.self) private var session
    var from: TimelineRow
    var to: TimelineRow
    var trip: Trip
    private let estimator: any RouteEstimating = MapKitRouteEstimator()

    var body: some View {
        let cached = ConnectorEstimateComposer.cached(from: from.id.item, to: to.id.item, in: trip)
        return HStack {
            Spacer()
            if let cached {
                Text(durationText(cached.estimate))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            } else {
                Rectangle()
                    .fill(TripsV2Style.guide)
                    .frame(width: 2, height: 12)
            }
            Spacer()
        }
        .accessibilityHidden(cached == nil)
        .task {
            await refreshIfNeeded()
        }
    }

    private func durationText(_ estimate: RouteEstimate) -> String {
        let minutes = max(Int((estimate.durationSeconds / 60).rounded()), 1)
        return String(localized: "\(minutes) min")
    }

    private func refreshIfNeeded() async {
        guard ConnectorEstimateComposer.cached(from: from.id.item, to: to.id.item, in: trip) == nil else {
            return
        }
        guard let origin = ConnectorEstimateComposer.coordinate(for: from.id.item, in: trip),
              let destination = ConnectorEstimateComposer.coordinate(for: to.id.item, in: trip)
        else {
            return
        }
        do {
            let estimate = try await estimator.estimate(from: origin, to: destination, mode: .walking)
            let record = ConnectorEstimate(
                fromItem: from.id.item,
                toItem: to.id.item,
                estimate: estimate,
                updatedAt: session.now
            )
            _ = await session.process(.applyMutation(.cacheConnectorEstimate(record)))
        } catch {
            return
        }
    }
}
