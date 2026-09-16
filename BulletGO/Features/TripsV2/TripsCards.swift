import SwiftUI

struct TripsTimelineItemRow: View {
    var row: TimelineRow
    var trip: Trip
    var catalog: QuestionCatalog?
    var locale: Locale
    var onOpenQuickContext: (TimelineRow) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: TripsV2Style.cardGap) {
            TripsTimingGutter(display: row.gutterDisplay)
            card
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(rowIdentifier)
        .accessibilityAction {
            onOpenQuickContext(row)
        }
    }

    @ViewBuilder
    private var card: some View {
        switch row.id {
        case .leg:
            if let presentation = TripsLegCardComposer.presentation(row: row, trip: trip, catalog: catalog) {
                TripsLegCard(presentation: presentation, onOpen: { onOpenQuickContext(row) })
            }
        case .activity:
            if let presentation = TripsActivityCardComposer.presentation(row: row, trip: trip) {
                TripsActivityCard(presentation: presentation, onOpen: { onOpenQuickContext(row) })
            }
        case .stay:
            if let presentation = TripsStayCardComposer.presentation(row: row, trip: trip, locale: locale) {
                TripsStayCard(presentation: presentation, onOpen: { onOpenQuickContext(row) })
            }
        }
    }

    private var rowIdentifier: String {
        switch row.id {
        case .leg(let id):
            AccessibilityID.timelineLeg(id)
        case .stay(let id, let role):
            AccessibilityID.timelineStay(id, role: role)
        case .activity(let id):
            AccessibilityID.timelineActivity(id)
        }
    }
}

struct TripsLegCard: View {
    var presentation: TripsLegCardPresentation
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 6) {
                    DisplayTextLabel(text: presentation.transport)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                    Text(verbatim: presentation.route)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if presentation.hasReservationMeta {
                        Text(verbatim: reservationMetaText)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DesignTokens.Color.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, presentation.action == nil ? 14 : 12)
            }
            .buttonStyle(.plain)

            if let action = presentation.action {
                Rectangle()
                    .fill(TripsV2Style.divider)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(TripsV2Style.accent)
                            .frame(width: 8, height: 8)
                        Text(action.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TripsV2Style.accent)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(verbatim: "›")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(TripsV2Style.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.tripsPreparation)
            }
        }
        .background(
            DesignTokens.Color.elevated,
            in: RoundedRectangle(cornerRadius: TripsV2Style.legCardRadius, style: .continuous)
        )
    }

    private var reservationMetaText: String {
        var parts: [String] = []
        if let arrival = presentation.arrivalTimeText {
            parts.append(String(localized: LocalizedStringResource(
                "Arrives \(arrival)",
                comment: "Confirmed reservation arrival time on a Trips leg card."
            )))
        }
        if let trainName = presentation.trainName {
            parts.append(trainName)
        }
        return parts.joined(separator: " · ")
    }
}

struct TripsActivityCard: View {
    var presentation: TripsActivityCardPresentation
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 14) {
                TripsPhotoPlaceholder(
                    label: LocalizedStringResource(
                        "Photo",
                        comment: "Neutral photo placeholder on a Trips activity card."
                    )
                )
                .frame(width: 80, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: presentation.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if presentation.isBooked {
                        Text("Already booked")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TripsV2Style.accent)
                    } else if let place = presentation.place {
                        Text(verbatim: place)
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.elevated,
                in: RoundedRectangle(cornerRadius: TripsV2Style.cardRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TripsStayCard: View {
    var presentation: TripsStayCardPresentation
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                TripsPhotoPlaceholder(
                    label: LocalizedStringResource(
                        "Hotel photo",
                        comment: "Neutral photo placeholder on a Trips stay card."
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: presentation.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignTokens.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    roleLine
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                    if let dateRange = presentation.dateRange {
                        Text(verbatim: dateRange)
                            .font(.system(size: 11))
                            .foregroundStyle(TripsV2Style.tertiaryText)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.elevated,
                in: RoundedRectangle(cornerRadius: TripsV2Style.cardRadius, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: TripsV2Style.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var roleLine: some View {
        switch presentation.role {
        case .checkIn:
            HStack(spacing: 0) {
                Text("Check-in")
                if let nights = presentation.nights {
                    Text(verbatim: " · ")
                    Text(
                        LocalizedStringResource(
                            "\(nights) nights",
                            comment: "Confirmed stay length in nights on a check-in card."
                        )
                    )
                }
            }
        case .staying(let night, let of):
            Text("Night \(night) of \(of)")
        case .checkOut:
            Text("Check-out")
        }
    }
}

private struct TripsPhotoPlaceholder: View {
    var label: LocalizedStringResource

    var body: some View {
        Text(label)
            .font(.system(size: 11))
            .foregroundStyle(TripsV2Style.placeholderText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TripsV2Style.placeholderFill)
    }
}
