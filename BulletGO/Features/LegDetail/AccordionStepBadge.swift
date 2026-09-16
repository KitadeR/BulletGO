import SwiftUI

struct AccordionStepBadge: View {
    enum Tone {
        case completed
        case current
        case upcoming
        case deferred
    }

    var number: Int
    var tone: Tone

    var body: some View {
        Text(verbatim: "\(number)")
            .font(DesignTokens.Typography.callout.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: 28, height: 28)
            .background(background, in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var foreground: Color {
        switch tone {
        case .completed, .current:
            .white
        case .upcoming, .deferred:
            DesignTokens.Color.secondaryText
        }
    }

    private var background: Color {
        switch tone {
        case .completed:
            DesignTokens.Color.success
        case .current:
            DesignTokens.Color.tint
        case .upcoming:
            DesignTokens.Color.quietFill
        case .deferred:
            DesignTokens.Color.remembered.opacity(0.18)
        }
    }

    private var stroke: Color {
        switch tone {
        case .completed, .current:
            Color.clear
        case .upcoming:
            DesignTokens.Color.stroke
        case .deferred:
            DesignTokens.Color.remembered.opacity(0.35)
        }
    }
}
