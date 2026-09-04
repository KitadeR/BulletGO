import SwiftUI

struct BaggageCheckView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tripID: TripID
    let legID: LegID
    let taskID: TaskID

    @State private var lengthText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var stepIndex = 0
    @FocusState private var focusedField: DimensionField?
    private let procedure = try? ProcedureCatalog.loadProduction(from: .main)

    private enum DimensionField: Hashable {
        case length
        case width
        case height
    }

    var body: some View {
        let steps = procedure?.steps ?? fallbackSteps
        let step = steps[min(stepIndex, max(steps.count - 1, 0))]
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Text(localizedProcedureCopy(step.title))
                        .font(DesignTokens.Typography.title)
                        .accessibilityIdentifier(AccessibilityID.baggageGuide)
                    Text(localizedProcedureCopy(step.body))
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    switch step.kind {
                    case .illustration:
                        BaggageMeasurementDiagram()
                    case .instruction:
                        BaggageMeasurementDiagram()
                    case .dimensionInput:
                        inputFields
                    case .policyResult:
                        resultContent
                    }

                    if let url = procedure?.sourceURL {
                        Link(destination: url) {
                            Text("JR Central oversized baggage")
                                .font(DesignTokens.Typography.caption)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: requirement?.rawValue) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(DesignTokens.Motion.content(reduceMotion)) {
                    proxy.scrollTo("baggage-result-panel", anchor: .center)
                }
            }
        }
        .background(DesignTokens.Color.canvas)
        .navigationTitle(
            procedure.map { localizedProcedureCopy($0.title) }
                ?? LocalizedStringResource("Measure your bag", comment: "Primary action to open baggage measurement.")
        )
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomAction(steps: steps)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(DesignTokens.Color.canvas)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .accessibilityIdentifier(AccessibilityID.keyboardDone)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.baggageCheck)
        .animation(DesignTokens.Motion.content(reduceMotion), value: stepIndex)
        .animation(DesignTokens.Motion.content(reduceMotion), value: requirement?.rawValue)
    }

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            BaggageMeasurementDiagram()
            dimensionField(
                title: LocalizedStringResource("Length", comment: "Bag length field label."),
                text: $lengthText,
                field: .length,
                identifier: AccessibilityID.baggageLength
            )
            dimensionField(
                title: LocalizedStringResource("Width", comment: "Bag width field label."),
                text: $widthText,
                field: .width,
                identifier: AccessibilityID.baggageWidth
            )
            dimensionField(
                title: LocalizedStringResource("Height", comment: "Bag height field label."),
                text: $heightText,
                field: .height,
                identifier: AccessibilityID.baggageHeight
            )
            Text("Total \(formattedTotal) cm")
                .font(DesignTokens.Typography.title)
                .accessibilityIdentifier("baggage-total")
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if let requirement {
            ResultPanel(
                title: TripContentResolver.policyResultTitle(requirement),
                bodyText: TripContentResolver.policyResultBody(requirement),
                footnote: sourceFootnote,
                tone: TripContentResolver.policyTone(requirement),
                accessibilityID: AccessibilityID.baggageResult
            )
            .id("baggage-result-panel")
        } else {
            Text("Enter the three sides to see the JR Central result.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.secondaryText)
        }
    }

    @ViewBuilder
    private func bottomAction(steps: [ProcedureStep]) -> some View {
        let step = steps[min(stepIndex, max(steps.count - 1, 0))]
        switch step.kind {
        case .illustration, .instruction:
            PrimaryCTA(
                title: LocalizedStringResource("Next", comment: "Advance to the next baggage-guide step."),
                accessibilityID: AccessibilityID.baggageGuideNext,
                action: { stepIndex = min(stepIndex + 1, steps.count - 1) }
            )
        case .dimensionInput:
            PrimaryCTA(
                title: LocalizedStringResource("Check this bag", comment: "Primary action submitting bag dimensions."),
                isEnabled: parsedDimensions != nil,
                isBusy: session.processState == .processing,
                accessibilityID: AccessibilityID.baggageSubmit,
                action: { Task { await submit(steps: steps) } }
            )
        case .policyResult:
            PrimaryCTA(
                title: LocalizedStringResource("Back to Home", comment: "Return to Home after baggage measurement."),
                accessibilityID: AccessibilityID.baggageGuideDone,
                action: { router.showHome(reset: true) }
            )
        }
    }

    private func dimensionField(
        title: LocalizedStringResource,
        text: Binding<String>,
        field: DimensionField,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
                .frame(minHeight: DesignTokens.TapTarget.minimum)
                .accessibilityIdentifier(identifier)
        }
    }

    private var parsedDimensions: BaggageDimensions? {
        guard let length = Double(lengthText),
              let width = Double(widthText),
              let height = Double(heightText)
        else {
            return nil
        }
        return try? BaggageDimensions(lengthCM: length, widthCM: width, heightCM: height)
    }

    private var formattedTotal: String {
        guard let parsedDimensions else {
            return "—"
        }
        return String(Int(parsedDimensions.totalCM.rounded()))
    }

    private var requirement: BaggagePolicyPack.ReservationRequirement? {
        guard let trip = session.trip,
              let pack = session.pack,
              let leg = trip.legs.first(where: { $0.id == legID }),
              let evaluation = leg.policyEvaluations.first(where: {
                  $0.policyID == pack.id && $0.status == .evaluated
              }),
              let raw = evaluation.resultFields[pack.resultKey]
        else {
            return nil
        }
        return BaggagePolicyPack.ReservationRequirement(rawValue: raw)
    }

    private var sourceFootnote: LocalizedStringResource? {
        guard session.pack != nil else {
            return nil
        }
        return LocalizedStringResource(
            "Based on JR Central oversized-baggage rules. 160 cm is the threshold; 161 cm needs a reserved space.",
            comment: "Official-source footnote under a baggage rule result."
        )
    }

    private func submit(steps: [ProcedureStep]) async {
        guard let dimensions = parsedDimensions else {
            return
        }
        focusedField = nil
        if session.trip?.focusLegID != legID {
            _ = await session.process(.focusLeg(legID))
        }
        _ = await session.process(.answerQuestion(.baggageDimensions, .dimensions(dimensions)))
        if let resultIndex = steps.firstIndex(where: { $0.kind == .policyResult }) {
            stepIndex = resultIndex
        }
    }

    private func localizedProcedureCopy(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(stringLiteral: key))
    }

    private var fallbackSteps: [ProcedureStep] {
        [
            ProcedureStep(
                id: "input",
                kind: .dimensionInput,
                title: "Enter the three numbers",
                body: "Measure length, width, and height in centimetres, including wheels and handles."
            ),
        ]
    }
}

#if DEBUG
#Preview("Guide") {
    NavigationStack {
        BaggageCheckView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto,
            taskID: TaskID()
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
}

#Preview("Japanese") {
    NavigationStack {
        BaggageCheckView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto,
            taskID: TaskID()
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("Dark") {
    NavigationStack {
        BaggageCheckView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto,
            taskID: TaskID()
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .preferredColorScheme(.dark)
}

#Preview("XL Dynamic Type") {
    NavigationStack {
        BaggageCheckView(
            tripID: PreviewTrips.readyForNow.id,
            legID: ReferenceTripIdentity.tokyoKyoto,
            taskID: TaskID()
        )
    }
    .environment(AppRouter())
    .environment(TripSessionModel(previewState: .loaded, trip: PreviewTrips.readyForNow))
    .dynamicTypeSize(.accessibility3)
}
#endif
