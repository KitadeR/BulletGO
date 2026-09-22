import SwiftUI

struct YouView: View {
    @Environment(AppRouter.self) private var router
    @Environment(TripSessionModel.self) private var session
    @Environment(\.featureRegistry) private var registry

    var body: some View {
        Group {
            switch session.loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn’t load your trip", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        Task { await session.retry() }
                    }
                }
            case .empty:
                emptyState
            case .loaded:
                if let trip = session.trip {
                    loadedYou(trip)
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.youView)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            Text("Traveler details appear with a trip")
                .font(DesignTokens.Typography.headline)
                .multilineTextAlignment(.center)
            Text("Language and luggage are stored on the current trip. Create a trip to see them here.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .multilineTextAlignment(.center)
            PrimaryCTA(
                title: LocalizedStringResource("Create trip", comment: "Empty You action that opens trip creation."),
                accessibilityID: AccessibilityID.createTripButton
            ) {
                router.present(.createTrip)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func loadedYou(_ trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GuidedAddCard {
                    VStack(alignment: .leading, spacing: 0) {
                        languageRow(trip)
                        luggageRow(trip)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                Text("These details belong to the current trip, not a global traveler profile.")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .padding(.horizontal, 4)
                GuidedAddCard {
                    VStack(alignment: .leading, spacing: 0) {
                        comingSoonRow(.savedDocuments)
                        comingSoonRow(.appSettings)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.vertical, 16)
        }
        .background(DesignTokens.Color.canvas)
    }

    private func languageRow(_ trip: Trip) -> some View {
        Button {
            router.push(.comingSoon(.travelerLanguage))
        } label: {
            HStack {
                Label("Language", systemImage: "globe")
                    .foregroundStyle(DesignTokens.Color.primaryText)
                Spacer()
                DisplayTextLabel(text: languageLabel(trip.traveler.preferredLanguage.value))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
            .frame(minHeight: DesignTokens.TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.youLanguage)
    }

    private func luggageRow(_ trip: Trip) -> some View {
        HStack {
            Label("Luggage", systemImage: "suitcase")
                .foregroundStyle(DesignTokens.Color.primaryText)
            Spacer()
            Text(verbatim: "\(trip.baggageInventory.count)")
                .foregroundStyle(DesignTokens.Color.secondaryText)
        }
        .frame(minHeight: DesignTokens.TapTarget.minimum)
        .accessibilityIdentifier(AccessibilityID.youLuggage)
    }

    private func comingSoonRow(_ feature: AppFeature) -> some View {
        let registration = registry.registration(for: feature)
        return Button {
            router.push(.comingSoon(feature))
        } label: {
            HStack {
                Label(registration.title, systemImage: registration.systemImage)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                Spacer()
                Text("›")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: DesignTokens.TapTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(feature == .savedDocuments ? AccessibilityID.youDocuments : AccessibilityID.youSettings)
    }

    private func languageLabel(_ code: String?) -> DisplayText {
        switch code {
        case "ja":
            .localized(LocalizedStringResource("Japanese", comment: "Japanese"))
        case "en":
            .localized(LocalizedStringResource("English", comment: "English"))
        case let value?:
            .verbatim(value)
        case nil:
            .localized(
                LocalizedStringResource(
                    "Unknown",
                    comment: "Label for the language when the user's preferred language is unknown."
                )
            )
        }
    }
}

#if DEBUG
#Preview("English") {
    NavigationStack {
        YouView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.reference))
}

#Preview("Japanese") {
    NavigationStack {
        YouView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.japaneseTraveler))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Empty") {
    NavigationStack {
        YouView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .empty))
}

#Preview("Dark") {
    NavigationStack {
        YouView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        YouView()
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.withBags))
    .dynamicTypeSize(.accessibility3)
}
#endif
