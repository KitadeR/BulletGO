import SwiftUI

struct LegDetailView: View {
    @Environment(TripSessionModel.self) private var session
    let tripID: TripID
    let legID: LegID

    var body: some View {
        Group {
            if let trip, let leg {
                detailList(trip: trip, leg: leg)
            } else {
                ContentUnavailableView {
                    Label(
                        "This journey isn’t available",
                        systemImage: "map"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.legDetail)
    }

    private var trip: Trip? {
        guard let trip = session.trip, trip.id == tripID else {
            return nil
        }
        return trip
    }

    private var leg: Leg? {
        trip?.legs.first { $0.id == legID }
    }

    private var navigationTitle: String {
        guard let leg else {
            return ""
        }
        let origin = leg.origin.value ?? ""
        let destination = leg.destination.value ?? ""
        return "\(origin) → \(destination)"
    }

    private func detailList(trip: Trip, leg: Leg) -> some View {
        let remembered = TimelineNextComposer.rememberedItems(for: trip, legID: leg.id)
        return List {
            Section {
                detailField(
                    title: LocalizedStringResource(
                        "From",
                        comment: "Leg detail label for the origin city."
                    ),
                    value: .verbatim(leg.origin.value ?? "")
                )
                detailField(
                    title: LocalizedStringResource(
                        "To",
                        comment: "Leg detail label for the destination city."
                    ),
                    value: .verbatim(leg.destination.value ?? "")
                )
                detailField(
                    title: LocalizedStringResource(
                        "Transport",
                        comment: "Leg detail label for the transport mode."
                    ),
                    value: .localized(TripContentResolver.transportSummary(for: leg))
                )
            }
            .listRowInsets(sectionInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if !remembered.isEmpty {
                Section {
                    ForEach(remembered) { item in
                        TimelineCardRow(
                            title: .localized(item.content.title),
                            subtitle: item.content.subtitle.map(DisplayText.localized),
                            systemImage: item.content.systemImage,
                            kind: .remembered,
                            showsChevron: false
                        )
                        .listRowInsets(sectionInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier(AccessibilityID.rememberedRow(rememberedContentKey(item)))
                    }
                } header: {
                    Text("Remembered")
                        .accessibilityIdentifier(AccessibilityID.rememberedSection)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(DesignTokens.Spacing.md)
    }

    private func detailField(title: LocalizedStringResource, value: DisplayText) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            DisplayTextLabel(text: value)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .leading)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var sectionInsets: EdgeInsets {
        EdgeInsets(
            top: DesignTokens.Spacing.xs,
            leading: DesignTokens.Spacing.md,
            bottom: DesignTokens.Spacing.xs,
            trailing: DesignTokens.Spacing.md
        )
    }

    private func rememberedContentKey(_ item: TimelineNextItem) -> String {
        if case .remembered(let remembered) = item.kind {
            return remembered.contentKey
        }
        return ""
    }
}

#if DEBUG
#Preview("Tokyo to Kyoto") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.reference.id, legID: ReferenceTripIdentity.tokyoKyoto)
    }
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Remembered") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.withComingUpAndRemembered.id, legID: PreviewTrips.withComingUpAndRemembered.legs[0].id)
    }
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
}

#Preview("Japanese") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.withComingUpAndRemembered.id, legID: PreviewTrips.withComingUpAndRemembered.legs[0].id)
    }
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.withComingUpAndRemembered.id, legID: PreviewTrips.withComingUpAndRemembered.legs[0].id)
    }
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        LegDetailView(tripID: PreviewTrips.withComingUpAndRemembered.id, legID: PreviewTrips.withComingUpAndRemembered.legs[0].id)
    }
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
    .dynamicTypeSize(.accessibility3)
}
#endif
