import SwiftUI

struct GuidanceFlowView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let legID: LegID
    let entry: GuidanceEntry
    let completion: GuidanceCompletion

    @State private var model: GuidanceFlowModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .task {
            let created = GuidanceFlowModel(
                tripID: tripID,
                legID: legID,
                entry: entry,
                completion: completion,
                session: session
            )
            model = created
            await created.start()
        }
        .onChange(of: model?.stage) { _, stage in
            if stage == .ready, completion == .showHome {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    router.dismissPresentation()
                    router.showHome(reset: true)
                }
            }
        }
        .onChange(of: model?.shouldDismissToSource) { _, shouldDismiss in
            if shouldDismiss == true {
                router.dismissPresentation()
            }
        }
    }

    @ViewBuilder
    private func content(_ model: GuidanceFlowModel) -> some View {
        VStack(spacing: 0) {
            header(model)
            stageBody(model)
                .animation(DesignTokens.Motion.content(reduceMotion), value: model.stage)
            if showsFooterCTA(model) {
                footer(model)
                    .padding(DesignTokens.Spacing.md)
                    .padding(.bottom, DesignTokens.Spacing.sm)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.guidanceSheet)
        .sensoryFeedback(.success, trigger: model.didCompleteReady)
    }

    private func header(_ model: GuidanceFlowModel) -> some View {
        HStack {
            Button {
                router.dismissPresentation()
            } label: {
                Image(systemName: "xmark")
                    .font(DesignTokens.Typography.headline)
                    .frame(width: DesignTokens.TapTarget.minimum, height: DesignTokens.TapTarget.minimum)
            }
            .accessibilityIdentifier(AccessibilityID.guidanceClose)
            .accessibilityLabel(Text("Close"))
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.xs)
    }

    @ViewBuilder
    private func stageBody(_ model: GuidanceFlowModel) -> some View {
        switch model.stage {
        case .compose:
            compose(model)
        case .interpreting:
            ProgressView("Reading what you wrote")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .summary:
            summary(model)
        case .setupQuestion:
            question(model)
        case .ready:
            ready
        case .failed:
            failed(model)
        case .structuredFallback:
            fallback(model)
        }
    }

    private func compose(_ model: GuidanceFlowModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if let trip = session.trip {
                    Text(verbatim: TripContentResolver.legTitle(trip: trip, legID: legID))
                        .font(DesignTokens.Typography.caption)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                        .background(DesignTokens.Color.tintSoft, in: Capsule())
                }
                Text("Tell us about this journey")
                    .font(DesignTokens.Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                TextField(
                    "What do you already know?",
                    text: Bindable(model).draftText,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(6, reservesSpace: true)
                .accessibilityIdentifier(AccessibilityID.guidanceInput)
                Text("For example: \(model.exampleText)")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.guidanceCompose)
    }

    private func summary(_ model: GuidanceFlowModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Here’s what we understood")
                    .font(DesignTokens.Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary = model.summary {
                    summaryGroup(
                        title: LocalizedStringResource("We know this", comment: "Summary section for confirmed facts."),
                        items: summary.confirmed
                    )
                    summaryGroup(
                        title: LocalizedStringResource("We’ll remember this", comment: "Summary section for deferred facts."),
                        items: summary.deferred
                    )
                    summaryGroup(
                        title: LocalizedStringResource("Still needed", comment: "Summary heading."),
                        items: summary.unconfirmed
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.guidanceSummary)
    }

    private func summaryGroup(title: LocalizedStringResource, items: [UnderstandingSummaryItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.headline)
            if items.isEmpty {
                Text("Nothing here yet.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TripContentResolver.summaryTitle(item))
                            .font(DesignTokens.Typography.footnote)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                        DisplayTextLabel(text: TripContentResolver.summaryValue(item))
                            .font(DesignTokens.Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.md)
                    .background(
                        DesignTokens.Color.elevated,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    )
                }
            }
        }
    }

    private func question(_ model: GuidanceFlowModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(model.answeredQuestions(), id: \.id) { answered in
                    CollapsedAnswerRow(
                        title: TripContentResolver.questionPrompt(answered),
                        value: model.answerValue(for: answered)
                    )
                }
                if let question = model.currentQuestion {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text(TripContentResolver.questionPrompt(question))
                            .font(DesignTokens.Typography.title)
                            .fixedSize(horizontal: false, vertical: true)
                        QuestionAnswerView(
                            question: question,
                            selectedDate: Bindable(model).selectedDate,
                            isBusy: model.isProcessing,
                            onConfirmDate: { Task { await model.confirmDate() } },
                            onChoice: { value in Task { await model.confirmChoice(value) } },
                            onSkip: (question.id == .ticketStatus || question.id == .luggagePresence)
                                ? { Task { await model.skipCurrent() } }
                                : nil
                        )
                    }
                    .padding(DesignTokens.Spacing.lg)
                    .opaqueSurface()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.guidanceQuestion)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var ready: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "sparkle")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.tint)
                .symbolEffect(.bounce, value: reduceMotion ? false : true)
            Text("We know what matters now")
                .font(DesignTokens.Typography.title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.guidanceReady)
    }

    private func failed(_ model: GuidanceFlowModel) -> some View {
        ContentUnavailableView {
            Label("Couldn’t save that", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Try again without losing the rest of this journey.")
        } actions: {
            PrimaryCTA(
                title: LocalizedStringResource("Retry", comment: "Retry button after a trip failed to load."),
                action: { Task { await model.retryLastStep() } }
            )
            .accessibilityIdentifier(AccessibilityID.guidanceRetry)
        }
    }

    private func fallback(_ model: GuidanceFlowModel) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("We couldn’t read that as a confirmed fact")
                .font(DesignTokens.Typography.title)
                .fixedSize(horizontal: false, vertical: true)
            Text("Nothing was saved. Answer a few questions instead.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(DesignTokens.Spacing.lg)
        .accessibilityIdentifier(AccessibilityID.guidanceFallback)
    }

    private func showsFooterCTA(_ model: GuidanceFlowModel) -> Bool {
        switch model.stage {
        case .compose, .summary, .structuredFallback:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private func footer(_ model: GuidanceFlowModel) -> some View {
        switch model.stage {
        case .compose:
            PrimaryCTA(
                title: LocalizedStringResource("Use this answer", comment: "Primary action to interpret free-text journey input."),
                isEnabled: !model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                isBusy: model.isProcessing,
                accessibilityID: AccessibilityID.guidanceSubmit,
                action: { Task { await model.submitCompose() } }
            )
        case .summary:
            PrimaryCTA(
                title: LocalizedStringResource("Continue", comment: "Fallback primary action on a concern detail."),
                accessibilityID: AccessibilityID.guidanceContinue,
                action: { model.continueFromSummary() }
            )
        case .structuredFallback:
            PrimaryCTA(
                title: LocalizedStringResource("Answer a few questions", comment: "Fallback action when free text cannot be interpreted."),
                action: { model.beginStructuredQuestions() }
            )
        default:
            EmptyView()
        }
    }
}
