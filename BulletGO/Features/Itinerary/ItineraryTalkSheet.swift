import SwiftUI

struct ItineraryTalkSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let scope: ItineraryInputScope

    @State private var text = ""
    @State private var isBusy = false
    @State private var draft: ProposedItineraryDraft?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    review(draft)
                } else {
                    compose
                }
            }
            .navigationTitle(draft == nil ? "Tell us about your trip" : "Here’s what we understood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.dismissPresentation() }
                        .accessibilityIdentifier(AccessibilityID.guidanceClose)
                }
            }
        }
        .accessibilityIdentifier(
            draft == nil ? AccessibilityID.itineraryTalkSheet : AccessibilityID.itineraryDraftReview
        )
    }

    private var compose: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Add dates, places, or journeys in your own words. We’ll show a summary before saving.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            TextField("Tokyo to Osaka on October 2 morning. Large suitcase.", text: $text, axis: .vertical)
                .lineLimit(4...10)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(AccessibilityID.itineraryTalkInput)
            if let errorMessage {
                Text(errorMessage)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.danger)
            }
            Spacer()
            PrimaryCTA(
                title: "Use this answer",
                isEnabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isBusy: isBusy,
                accessibilityID: AccessibilityID.itineraryTalkSubmit,
                action: { Task { await extract() } }
            )
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Color.canvas)
    }

    private func review(_ draft: ProposedItineraryDraft) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            List {
                if let name = draft.tripName {
                    LabeledContent("Trip") { Text(name) }
                }
                ForEach(Array(draft.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(itemTitle(item))
                            .font(DesignTokens.Typography.headline)
                        Text(item.sourceQuote)
                            .font(DesignTokens.Typography.footnote)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                    }
                }
                if !draft.unresolved.isEmpty {
                    Section("Needs review") {
                        ForEach(draft.unresolved, id: \.self) { note in
                            Text(note)
                        }
                    }
                }
            }
            PrimaryCTA(
                title: "Add to trip",
                isEnabled: !draft.items.isEmpty || draft.tripName != nil,
                accessibilityID: AccessibilityID.itineraryDraftConfirm,
                action: { Task { await confirm(draft) } }
            )
            .padding(DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Color.canvas)
    }

    private func itemTitle(_ item: ProposedItineraryItem) -> String {
        switch item.kind {
        case .leg:
            "\(item.origin ?? "") → \(item.destination ?? "")"
        case .stay:
            item.place ?? "Stay"
        case .activity:
            item.title ?? "Activity"
        case .baggageHint:
            item.baggageHint ?? "Luggage"
        case .tripNote:
            "Note"
        }
    }

    private func extract() async {
        isBusy = true
        defer { isBusy = false }
        guard let trip = session.trip else { return }
        do {
            draft = try await session.extractItineraryDraft(text, scope: scope, trip: trip)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t read that yet. Add the plan with Transport, Stay, or Activity instead."
        }
    }

    private func confirm(_ draft: ProposedItineraryDraft) async {
        guard let trip = session.trip else { return }
        do {
            let mutations = try ItineraryDraftMutations.mutations(from: draft, trip: trip, now: Date())
            if !mutations.isEmpty {
                _ = await session.process(.applyMutations(mutations))
            }
            router.dismissPresentation()
        } catch {
            errorMessage = "Couldn’t save those changes. Try adding them manually."
            self.draft = nil
        }
    }
}
