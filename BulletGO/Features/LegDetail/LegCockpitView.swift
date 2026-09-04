import SwiftUI

struct LegCockpitContentView: View {
    var cockpit: LegCockpitSnapshot
    var onWhatsNext: (TimelineNowItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            if let item = cockpit.whatsNext {
                whatsNextSection(item)
            }
            summarySection
            readinessSection
        }
    }

    private func whatsNextSection(_ item: TimelineNowItem) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("What’s next")
                .font(DesignTokens.Typography.headline)
            HomePrimaryNowCard(item: item) {
                onWhatsNext(item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legCockpitWhatsNext)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Summary")
                .font(DesignTokens.Typography.headline)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                if cockpit.dateText != nil || cockpit.timeText != nil {
                    scheduleMetaRow
                }
                CockpitFactRow(
                    systemImage: "tram.fill",
                    title: LocalizedStringResource("Transport", comment: "Leg detail label for the transport mode."),
                    value: cockpit.transport
                )
                CockpitFactRow(
                    systemImage: "ticket.fill",
                    title: LocalizedStringResource("Booking", comment: "Leg cockpit label for reservation status."),
                    value: cockpit.reservationStatus
                )
                if let service = cockpit.reservationService {
                    CockpitFactRow(
                        systemImage: "app.badge.checkmark.fill",
                        title: LocalizedStringResource(
                            "Booking service",
                            comment: "Leg cockpit label for the booking service."
                        ),
                        value: service
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
            .opaqueSurface(cornerRadius: DesignTokens.Radius.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legCockpitSummary)
    }

    @ViewBuilder
    private var scheduleMetaRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let dateText = cockpit.dateText {
                CockpitMetaChip(systemImage: "calendar", text: dateText)
            }
            if let timeText = cockpit.timeText {
                CockpitMetaChip(systemImage: "clock", text: timeText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Readiness")
                .font(DesignTokens.Typography.headline)
            VStack(spacing: 0) {
                CockpitReadinessRow(
                    title: LocalizedStringResource(
                        "Booking readiness",
                        comment: "Leg cockpit readiness row for booking."
                    ),
                    systemImage: "checkmark.shield.fill",
                    status: cockpit.bookingReadiness
                )
                Divider()
                    .padding(.leading, DesignTokens.Spacing.md + 28 + DesignTokens.Spacing.sm)
                CockpitReadinessRow(
                    title: LocalizedStringResource(
                        "Luggage readiness",
                        comment: "Leg cockpit readiness row for luggage."
                    ),
                    systemImage: "suitcase.fill",
                    status: cockpit.luggageReadiness
                )
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
            .opaqueSurface(cornerRadius: DesignTokens.Radius.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legCockpitReadiness)
    }
}

private struct CockpitMetaChip: View {
    var systemImage: String
    var text: String

    var body: some View {
        Label {
            Text(verbatim: text)
                .font(DesignTokens.Typography.callout.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.primaryText)
        } icon: {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.footnote.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.tint)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Color.tintSoft, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private struct CockpitFactRow: View {
    var systemImage: String
    var title: LocalizedStringResource
    var value: DisplayText

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(DesignTokens.Color.tint)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Color.tintSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                DisplayTextLabel(text: value)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
        }
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

private struct CockpitReadinessRow: View {
    var title: LocalizedStringResource
    var systemImage: String
    var status: PreparationStatusKind

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(status.accentColor)
                .frame(width: 28, height: 28)
                .background(status.accentColor.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DesignTokens.Spacing.xs)
            PreparationStatusBadge(status: status)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(status.displayTitle))
    }
}

#if DEBUG
#Preview("Cockpit Content") {
    ScrollView {
        LegCockpitContentView(
            cockpit: LegCockpitComposer.snapshot(
                trip: PreviewTrips.readyForNow,
                leg: PreviewTrips.readyForNow.legs[0],
                catalog: nil
            ),
            onWhatsNext: { _ in }
        )
        .padding(DesignTokens.Spacing.lg)
    }
    .background(DesignTokens.Color.canvas)
}

#Preview("Cockpit Content Japanese") {
    ScrollView {
        LegCockpitContentView(
            cockpit: LegCockpitComposer.snapshot(
                trip: PreviewTrips.readyForNow,
                leg: PreviewTrips.readyForNow.legs[0],
                catalog: nil
            ),
            onWhatsNext: { _ in }
        )
        .padding(DesignTokens.Spacing.lg)
    }
    .background(DesignTokens.Color.canvas)
    .environment(\.locale, Locale(identifier: "ja"))
}
#endif
