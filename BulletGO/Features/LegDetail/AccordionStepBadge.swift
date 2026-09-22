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
        Group {
            if tone == .completed {
                GuidedAddCheck()
                    .frame(width: 28, height: 28)
            } else {
                Text(verbatim: "\(number)")
                    .font(DesignTokens.Typography.callout.weight(.semibold))
                    .foregroundStyle(foreground)
                    .frame(width: 28, height: 28)
                    .background(background, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(stroke, lineWidth: 1)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var foreground: Color {
        switch tone {
        case .current:
            DesignTokens.Color.ctaText
        case .upcoming, .deferred, .completed:
            DesignTokens.Color.secondaryText
        }
    }

    private var background: Color {
        switch tone {
        case .current:
            DesignTokens.Color.ctaFill
        case .upcoming, .deferred, .completed:
            DesignTokens.Color.grouped
        }
    }

    private var stroke: Color {
        switch tone {
        case .current:
            Color.clear
        case .upcoming, .deferred, .completed:
            DesignTokens.Color.stroke
        }
    }
}
