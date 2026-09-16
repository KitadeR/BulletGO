import SwiftUI

struct LegCockpitContentView: View {
    var cockpit: LegCockpitSnapshot
    var onOpen: (TimelineNowItem) -> Void

    @State private var expandedID: LegCockpitBlockID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let blocks = LegCockpitAccordionComposer.blocks(for: cockpit)
        let expanded = resolvedExpanded(in: blocks)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ForEach(blocks) { block in
                accordionBlock(block, isExpanded: block.id == expanded)
            }
        }
        .animation(DesignTokens.Motion.content(reduceMotion), value: expanded)
    }

    private func resolvedExpanded(in blocks: [LegCockpitBlock]) -> LegCockpitBlockID {
        let fallback = LegCockpitAccordionComposer.initialExpandedID(for: cockpit)
        if let expandedID, blocks.contains(where: { $0.id == expandedID }) {
            return expandedID
        }
        return fallback
    }

    private func accordionBlock(_ block: LegCockpitBlock, isExpanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Button {
                expandedID = block.id
            } label: {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                    AccordionStepBadge(
                        number: block.stepNumber,
                        tone: isExpanded ? .current : .upcoming
                    )
                    Text(block.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Color.primaryText)
                    Spacer(minLength: DesignTokens.Spacing.xs)
                }
                .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Step \(block.stepNumber), \(block.title)"))
            .accessibilityValue(Text(isExpanded ? "Current" : "Not started"))

            if isExpanded {
                blockContent(block.id)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .modifier(OptionalAccessibilityIdentifier(identifier: accessibilityID(for: block.id)))
    }

    @ViewBuilder
    private func blockContent(_ id: LegCockpitBlockID) -> some View {
        switch id {
        case .whatsNext:
            if let item = cockpit.whatsNext {
                HomePrimaryNowCard(item: item) {
                    onOpen(item)
                }
            }
        case .luggage:
            if let item = cockpit.luggageGuide {
                CockpitLuggageRow(item: item) {
                    onOpen(item)
                }
            }
        case .summary:
            summaryContent
        case .readiness:
            readinessContent
        }
    }

    private func accessibilityID(for id: LegCockpitBlockID) -> String? {
        switch id {
        case .whatsNext:
            AccessibilityID.legCockpitWhatsNext
        case .luggage:
            nil
        case .summary:
            AccessibilityID.legCockpitSummary
        case .readiness:
            AccessibilityID.legCockpitReadiness
        }
    }

    private var summaryContent: some View {
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

    private var readinessContent: some View {
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
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    var identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private struct CockpitLuggageRow: View {
    var item: TimelineNowItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "suitcase.fill")
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(DesignTokens.Color.tint)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Color.tintSoft, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        LocalizedStringResource(
                            "Check bag size",
                            comment: "Cockpit action that opens the luggage measurement guide."
                        )
                    )
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(TripContentResolver.taskWhyNow(item.contentKey))
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DesignTokens.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
            .opaqueSurface(cornerRadius: DesignTokens.Radius.lg)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.legCockpitLuggage)
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
            onOpen: { _ in }
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
            onOpen: { _ in }
        )
        .padding(DesignTokens.Spacing.lg)
    }
    .background(DesignTokens.Color.canvas)
    .environment(\.locale, Locale(identifier: "ja"))
}
#endif
