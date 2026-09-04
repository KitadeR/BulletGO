import SwiftUI

struct LegSetupStepView: View {
    let step: LegSetupStep
    var isExpanded: Bool
    @Binding var selectedDate: Date
    var isBusy: Bool
    var hasError: Bool
    var onConfirmDate: () -> Void
    var onChoice: (String) -> Void
    var onSkip: (() -> Void)?
    var onReopen: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            header
            if isExpanded {
                Text(step.prompt)
                    .font(DesignTokens.Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
                QuestionAnswerView(
                    question: step.question,
                    selectedDate: $selectedDate,
                    isBusy: isBusy,
                    onConfirmDate: onConfirmDate,
                    onChoice: onChoice,
                    onSkip: onSkip
                )
                if hasError {
                    Text("Couldn’t save that. Try this step again.")
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: isExpanded ? .contain : .combine)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(accessibilityValue)
        .modifier(DeferredHint(isDeferred: step.kind == .deferred && !isExpanded))
        .accessibilityIdentifier(
            step.kind == .current && isExpanded
                ? AccessibilityID.legSetupCurrent
                : AccessibilityID.setupStep(step.question.id)
        )
    }

    @ViewBuilder
    private var header: some View {
        let row = HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: iconName)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                if !isExpanded, let valueText = step.valueText {
                    DisplayTextLabel(text: valueText)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else if step.kind == .upcoming {
                    Text(
                        LocalizedStringResource(
                            "Coming up",
                            comment: "Collapsed upcoming setup step caption."
                        )
                    )
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
        }
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)

        if let onReopen, !isExpanded {
            Button(action: onReopen) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var iconName: String {
        switch step.kind {
        case .completed:
            "checkmark.circle.fill"
        case .deferred:
            "clock"
        case .current:
            step.systemImage
        case .upcoming:
            "circle"
        }
    }

    private var iconColor: Color {
        switch step.kind {
        case .completed:
            DesignTokens.Color.success
        case .deferred:
            DesignTokens.Color.remembered
        case .current:
            DesignTokens.Color.tint
        case .upcoming:
            DesignTokens.Color.secondaryText
        }
    }

    private var accessibilityName: Text {
        Text("Step \(step.stepNumber), \(step.title)")
    }

    private var accessibilityValue: Text {
        switch step.kind {
        case .completed:
            Text("Completed")
        case .deferred:
            Text("Confirm later")
        case .current:
            Text("Current")
        case .upcoming:
            Text("Not started")
        }
    }
}

private struct DeferredHint: ViewModifier {
    var isDeferred: Bool

    func body(content: Content) -> some View {
        if isDeferred {
            content.accessibilityHint(Text("Reconfirm this when you are ready."))
        } else {
            content
        }
    }
}
