import SwiftUI

enum GlassChrome {
    static func allowsGlass(
        reduceTransparency: Bool,
        increaseContrast: Bool
    ) -> Bool {
        !reduceTransparency && !increaseContrast
    }
}

struct ChromeIconButton: View {
    var systemImage: String
    var accessibilityLabel: LocalizedStringResource
    var action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .frame(width: DesignTokens.TapTarget.minimum, height: DesignTokens.TapTarget.minimum)
        }
        .accessibilityLabel(Text(accessibilityLabel))

        if #available(iOS 26, *), GlassChrome.allowsGlass(
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased
        ) {
            button.buttonStyle(.glass)
        } else {
            button
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
    }
}

struct PrimaryCTA: View {
    var title: LocalizedStringResource
    var systemImage: String?
    var isEnabled: Bool = true
    var isBusy: Bool = false
    var prominent: Bool = true
    var accessibilityID: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isBusy {
                    ProgressView()
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: GuidedAddMetrics.ctaHeight)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
        }
        .disabled(!isEnabled || isBusy)
        .accessibilityIdentifier(accessibilityID)
    }

    private var foreground: Color {
        if !prominent {
            return DesignTokens.Color.primaryText
        }
        return isEnabled ? DesignTokens.Color.ctaText : DesignTokens.Color.ctaDisabledText
    }

    private var background: Color {
        if !prominent {
            return DesignTokens.Color.grouped
        }
        return isEnabled ? DesignTokens.Color.ctaFill : DesignTokens.Color.ctaDisabledFill
    }
}

extension View {
    func opaqueSurface(cornerRadius: CGFloat = DesignTokens.Radius.lg) -> some View {
        background(
            DesignTokens.Color.elevated,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
