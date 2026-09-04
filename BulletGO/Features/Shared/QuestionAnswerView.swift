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
                DatePicker(
                    selection: $selectedDate,
                    displayedComponents: .date
                ) {
                    Text("Suggested date")
                }
                .datePickerStyle(.compact)
                .disabled(isBusy)
                PrimaryCTA(
                    title: LocalizedStringResource(
                        "Use this date",
                        comment: "Primary action confirming the suggested travel date."
                    ),
                    isBusy: isBusy,
                    accessibilityID: AccessibilityID.dateConfirm,
                    action: onConfirmDate
                )
            case .singleChoice:
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(question.choices, id: \.value) { choice in
                        Button {
                            onChoice(choice.value)
                        } label: {
                            Text(TripContentResolver.questionChoiceTitle(choice))
                                .font(DesignTokens.Typography.headline)
                                .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                        .accessibilityIdentifier(AccessibilityID.questionChoice(choice.value))
                    }
                }
            case .dimensions:
                EmptyView()
            }

            if let onSkip {
                Button(action: onSkip) {
                    Text("I’ll answer later")
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.TapTarget.minimum)
                }
                .disabled(isBusy)
                .accessibilityIdentifier(AccessibilityID.questionSkip(question.id))
            }
        }
    }
}
