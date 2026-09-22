import SwiftUI

struct GuidedAddFlowView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.placeSearching) private var environmentSearch
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: GuidedAddFlowModel
    private let searchOverride: (any PlaceSearching)?

    init(
        tripID: TripID,
        kind: ItineraryAddKind,
        initialDate: LocalDate?,
        now: Date,
        search: (any PlaceSearching)? = nil,
        seedPlace: PlaceReference? = nil
    ) {
        _model = State(initialValue: GuidedAddFlowModel(
            tripID: tripID,
            kind: kind,
            initialDate: initialDate,
            now: now,
            seedPlace: seedPlace
        ))
        searchOverride = search
    }

    private var search: (any PlaceSearching)? {
        searchOverride ?? environmentSearch
    }

    var body: some View {
        NavigationStack {
            GuidedAddChrome(
                title: model.currentStep.title,
                subtitle: headerSubtitle,
                isFirst: model.isFirstStep,
                showsCTA: showsCTA,
                ctaTitle: model.isReview
                    ? LocalizedStringResource("追加する", comment: "Guided Add review save action.")
                    : LocalizedStringResource("次へ", comment: "Guided Add continue action."),
                ctaEnabled: model.canAdvance,
                ctaBusy: model.isSaving,
                ctaID: model.isReview ? AccessibilityID.guidedAddSave : AccessibilityID.guidedAddContinue,
                onCancel: attemptDismiss,
                onBack: {
                    withAnimation(GuidedAddMotion.card(reduceMotion)) {
                        model.back()
                    }
                },
                onCTA: {
                    if model.isReview {
                        Task { await save() }
                    } else {
                        withAnimation(GuidedAddMotion.card(reduceMotion)) {
                            model.advance()
                        }
                    }
                }
            ) {
                stepContent
            }
        }
        .interactiveDismissDisabled(model.isDirty)
        .onChange(of: model.isDirty) { _, _ in }
        .confirmationDialog(
            "Discard this item?",
            isPresented: $model.showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { router.dismissPresentation() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Couldn’t add this item", isPresented: $model.saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier(AccessibilityID.guidedAddSheet)
        .animation(GuidedAddMotion.card(reduceMotion), value: model.currentStep)
    }

    private var headerSubtitle: String? {
        nil
    }

    private var showsCTA: Bool {
        if model.kind == .travel, case .travel(let draft) = model.draft, model.currentStep == .travelMode, draft.mode == nil {
            return false
        }
        return true
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.draft {
        case .activity(let draft):
            activityStep(draft)
        case .travel(let draft):
            travelStep(draft)
        case .stay(let draft):
            stayStep(draft)
        }
    }

    @ViewBuilder
    private func activityStep(_ draft: ActivityAddDraft) -> some View {
        ActivityGuidedAddStack(
            draft: draft,
            step: model.currentStep,
            search: search,
            update: updateActivity,
            onSkipTiming: skipOptional,
            onJump: jump
        )
    }

    @ViewBuilder
    private func travelStep(_ draft: LegAddDraft) -> some View {
        TravelGuidedAddStack(
            draft: draft,
            step: model.currentStep,
            search: search,
            update: updateTravel,
            onSelectMode: { mode in
                withAnimation(GuidedAddMotion.card(reduceMotion)) {
                    updateTravel { $0.mode = mode }
                }
            },
            onOpenMaps: {
                guard let origin = draft.originPlace, let destination = draft.destinationPlace else { return }
                AppleMapsDirectionsHandoff.open(from: origin, to: destination)
            },
            onJump: jump
        )
    }

    @ViewBuilder
    private func stayStep(_ draft: StayAddDraft) -> some View {
        StayGuidedAddStack(
            draft: draft,
            step: model.currentStep,
            search: search,
            update: updateStay,
            onSkipCheckIn: skipOptional,
            onSkipCheckOut: skipOptional,
            onJump: jump
        )
    }

    private func skipOptional() {
        withAnimation(GuidedAddMotion.card(reduceMotion)) {
            model.skipOptional()
        }
    }

    private func jump(to step: GuidedAddStep) {
        withAnimation(GuidedAddMotion.card(reduceMotion)) {
            model.jump(to: step)
        }
    }

    private func attemptDismiss() {
        if model.isDirty {
            model.showDiscardConfirmation = true
        } else {
            router.dismissPresentation()
        }
    }

    private func save() async {
        if await model.commit(session: session) {
            router.dismissPresentation()
        }
    }
}

private extension GuidedAddFlowView {
    func updateActivity(_ body: (inout ActivityAddDraft) -> Void) {
        guard case .activity(var value) = model.draft else { return }
        body(&value)
        model.draft = .activity(value)
    }

    func updateTravel(_ body: (inout LegAddDraft) -> Void) {
        guard case .travel(var value) = model.draft else { return }
        body(&value)
        model.draft = .travel(value)
    }

    func updateStay(_ body: (inout StayAddDraft) -> Void) {
        guard case .stay(var value) = model.draft else { return }
        body(&value)
        model.draft = .stay(value)
    }
}

#if DEBUG
#Preview("XL Dynamic Type") {
    GuidedAddFlowView(
        tripID: PreviewTrips.planning.id,
        kind: .activity,
        initialDate: PreviewTrips.planning.startDate.value,
        now: PreviewTrips.phaseClockNow
    )
    .environment(AppRouter())
    .environment(
        TripSessionModel(
            previewState: .loaded,
            trip: PreviewTrips.planning,
            clock: .fixed(PreviewTrips.phaseClockNow)
        )
    )
    .dynamicTypeSize(.accessibility3)
}
#endif
