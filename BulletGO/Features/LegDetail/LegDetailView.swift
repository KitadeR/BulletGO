import SwiftUI

struct LegDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let tripID: TripID
    let legID: LegID

    var body: some View {
        Group {
            if let trip, let leg {
                detail(trip: trip, leg: leg)
            } else {
                ContentUnavailableView("This journey isn’t available", systemImage: "map")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ChromeIconButton(
                    systemImage: "chevron.backward",
                    accessibilityLabel: LocalizedStringResource("Back", comment: "Back button on journey detail."),
                    action: { dismiss() }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.legDetail)
    }

    private var trip: Trip? {
        guard let trip = session.trip, trip.id == tripID else { return nil }
        return trip
    }

    private var leg: Leg? {
        trip?.legs.first { $0.id == legID }
    }

    private func detail(trip: Trip, leg: Leg) -> some View {
        let remembered = TimelineNextComposer.rememberedItems(for: trip, legID: leg.id)
        let title = "\(leg.origin.value ?? "") → \(leg.destination.value ?? "")"
        return ZStack(alignment: .top) {
            DesignTokens.Color.canvas
                .ignoresSafeArea()
            JourneyArtwork(kind: JourneyVisualProvider.kind(for: leg))
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 112)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        Text(verbatim: title)
                            .font(DesignTokens.Typography.display)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(TripContentResolver.transportSummary(for: leg))
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.secondaryText)

                        knownSection(trip: trip, leg: leg)
                        stillNeededSection(trip: trip, leg: leg)

                        if !remembered.isEmpty {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                Text("Remembered")
                                    .font(DesignTokens.Typography.headline)
                                    .accessibilityIdentifier(AccessibilityID.rememberedSection)
                                ForEach(remembered) { item in
                                    QuietComingUpRow(
                                        title: .localized(item.content.title),
                                        subtitle: item.content.subtitle.map(DisplayText.localized),
                                        systemImage: item.content.systemImage,
                                        showsChevron: false,
                                        accessibilityID: AccessibilityID.rememberedRow(rememberedContentKey(item))
                                    )
                                }
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        DesignTokens.Color.canvas,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: DesignTokens.Radius.hero,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: DesignTokens.Radius.hero,
                            style: .continuous
                        )
                    )
                }
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            startGuidanceButton
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Color.canvas)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func knownSection(trip: Trip, leg: Leg) -> some View {
        let items = knownItems(trip: trip, leg: leg)
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("What we know")
                        .font(DesignTokens.Typography.headline)
                        .accessibilityIdentifier(AccessibilityID.knownSection)
                    ForEach(items, id: \.id) { item in
                        labeled(title: item.title, value: item.value)
                    }
                }
            }
        }
    }

    private func stillNeededSection(trip: Trip, leg: Leg) -> some View {
        let items = stillNeeded(trip: trip, leg: leg)
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Still needed")
                        .font(DesignTokens.Typography.headline)
                        .accessibilityIdentifier(AccessibilityID.stillNeededSection)
                    ForEach(items, id: \.key) { item in
                        Text(item.title)
                            .font(DesignTokens.Typography.body)
                            .padding(DesignTokens.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                DesignTokens.Color.grouped,
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                            )
                    }
                }
            }
        }
    }

    private var startGuidanceButton: some View {
        let button = Button {
            router.present(.guidance(tripID, legID, .compose))
        } label: {
            Label("Tell us about this journey", systemImage: "text.bubble")
                .font(DesignTokens.Typography.headline)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
        }
        .accessibilityIdentifier(AccessibilityID.startGuidance)

        return Group {
            if #available(iOS 26, *), GlassChrome.allowsGlass(
                reduceTransparency: reduceTransparency,
                increaseContrast: contrast == .increased
            ) {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        }
    }

    private func labeled(title: LocalizedStringResource, value: DisplayText) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            DisplayTextLabel(text: value)
                .font(DesignTokens.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func knownItems(trip: Trip, leg: Leg) -> [(id: String, title: LocalizedStringResource, value: DisplayText)] {
        var items: [(id: String, title: LocalizedStringResource, value: DisplayText)] = [
            (
                "from",
                LocalizedStringResource("From", comment: "Leg detail label for the origin city."),
                .verbatim(leg.origin.value ?? "")
            ),
            (
                "to",
                LocalizedStringResource("To", comment: "Leg detail label for the destination city."),
                .verbatim(leg.destination.value ?? "")
            ),
        ]
        if leg.transportMode.status == .confirmed {
            items.append((
                "transport",
                LocalizedStringResource("Transport", comment: "Leg detail label for the transport mode."),
                .localized(TripContentResolver.transportSummary(for: leg))
            ))
        }
        if let date = leg.scheduledAt.value?.date, leg.scheduledAt.status == .confirmed {
            items.append((
                "date",
                LocalizedStringResource("Travel date", comment: "Summary heading for the journey date."),
                .verbatim("\(date.year)/\(date.month)/\(date.day)")
            ))
        }
        _ = trip
        return items
    }

    private func stillNeeded(trip: Trip, leg: Leg) -> [(key: String, title: LocalizedStringResource)] {
        guard let catalog = session.catalog, trip.focusLegID == leg.id else {
            return []
        }
        return QuestionEngine.applicableQuestions(in: trip, catalog: catalog, role: .setup)
            .filter { !QuestionEngine.isConfirmed($0.target, trip: trip, leg: leg) }
            .map { ($0.id.rawValue, TripContentResolver.questionPrompt($0)) }
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
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Remembered") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.withComingUpAndRemembered.id,
            legID: PreviewTrips.withComingUpAndRemembered.legs[0].id
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withComingUpAndRemembered))
}

#Preview("Japanese") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        LegDetailView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .dynamicTypeSize(.accessibility3)
}
#endif
