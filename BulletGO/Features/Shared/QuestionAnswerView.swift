import SwiftUI

struct QuestionAnswerView: View {
    let question: QuestionSpec
    @Binding var selectedDate: Date
    var isBusy: Bool
    var onConfirmDate: () -> Void
    var onChoice: (String) -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            switch question.uiKind {
            case .dateTime:
                GuidedAddCard {
                    VStack(alignment: .leading, spacing: 16) {
                        DatePicker(
                            selection: $selectedDate,
                            displayedComponents: .date
                        ) {
                            Text("Suggested date")
                        }
                        .datePickerStyle(.compact)
                        .disabled(isBusy)
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        PrimaryCTA(
                            title: LocalizedStringResource(
                                "Use this date",
                                comment: "Primary action confirming the suggested travel date."
                            ),
                            isBusy: isBusy,
                            accessibilityID: AccessibilityID.dateConfirm,
                            action: onConfirmDate
                        )
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }
                }
            case .singleChoice:
                VStack(spacing: 8) {
                    ForEach(question.choices, id: \.value) { choice in
                        Button {
                            onChoice(choice.value)
                        } label: {
                            HStack {
                                Text(TripContentResolver.questionChoiceTitle(choice))
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundStyle(DesignTokens.Color.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("›")
                                    .foregroundStyle(DesignTokens.Color.secondaryText)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: GuidedAddMetrics.howHeight, alignment: .leading)
                            .background(
                                DesignTokens.Color.grouped,
                                in: RoundedRectangle(cornerRadius: GuidedAddMetrics.howRadius, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                        .accessibilityIdentifier(AccessibilityID.questionChoice(choice.value))
                    }
                }
            case .dimensions:
                EmptyView()
            }

            if let onSkip {
                Button(action: onSkip) {
                    HStack {
                        Text("I’ll answer later")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Color.primaryText)
                        Spacer()
                        Text("→")
                    }
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
                }
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.questionSkip(question.id))
            }
        }
    }
}
