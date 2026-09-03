import SwiftUI

struct BaggageCheckView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let tripID: TripID
    let legID: LegID
    let taskID: TaskID

    @State private var lengthText = ""
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var showingHelp = false
    @FocusState private var focusedField: DimensionField?

    private enum DimensionField: Hashable {
        case length
        case width
        case height
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    bagDiagram
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

                    Button("How to measure") {
                        showingHelp = true
                    }
                    .frame(minHeight: DesignTokens.TapTarget.minimum)

                    if let requirement {
                        ResultPanel(
                            title: TripContentResolver.policyResultTitle(requirement),
                            bodyText: TripContentResolver.policyResultBody(requirement),
                            footnote: sourceFootnote,
                            tone: TripContentResolver.policyTone(requirement),
                            accessibilityID: AccessibilityID.baggageResult
                        )
                        .id("baggage-result-panel")
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
        .navigationTitle("Measure your bag")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryCTA(
                title: LocalizedStringResource("Check this bag", comment: "Primary action submitting bag dimensions."),
                isEnabled: parsedDimensions != nil,
                isBusy: session.processState == .processing,
                accessibilityID: AccessibilityID.baggageSubmit,
                action: { Task { await submit() } }
            )
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
        .alert("How to measure", isPresented: $showingHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Measure the longest side, the width, and the height in centimetres, including wheels and handles. Add the three numbers.")
        }
        .animation(DesignTokens.Motion.content(reduceMotion), value: requirement?.rawValue)
    }

    private var bagDiagram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Color.grouped)
                .frame(height: 160)
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "suitcase")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(DesignTokens.Color.tint)
                Text("Three sides, in cm")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
            }
        }
        .accessibilityHidden(true)
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

    private func submit() async {
        guard let dimensions = parsedDimensions else {
            return
        }
        focusedField = nil
        if session.trip?.focusLegID != legID {
            _ = await session.process(.focusLeg(legID))
        }
        _ = await session.process(.answerQuestion(.baggageDimensions, .dimensions(dimensions)))
    }
}
