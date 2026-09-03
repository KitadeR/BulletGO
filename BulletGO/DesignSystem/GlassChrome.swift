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

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let label = HStack(spacing: DesignTokens.Spacing.xs) {
            if isBusy {
                ProgressView()
            } else if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .font(DesignTokens.Typography.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: DesignTokens.TapTarget.minimum)

        let button = Button(action: action) { label }
            .disabled(!isEnabled || isBusy)
            .opacity(isEnabled ? 1 : 0.45)
            .accessibilityIdentifier(accessibilityID)

        if #available(iOS 26, *),
           prominent,
           GlassChrome.allowsGlass(
            reduceTransparency: reduceTransparency,
            increaseContrast: contrast == .increased
           )
        {
            button.buttonStyle(.glassProminent)
        } else if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

extension View {
    func opaqueSurface(cornerRadius: CGFloat = DesignTokens.Radius.lg) -> some View {
        background(
            DesignTokens.Color.elevated,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(DesignTokens.Color.stroke, lineWidth: 1)
        }
        .shadow(
            color: DesignTokens.Shadow.cardColor,
            radius: DesignTokens.Shadow.cardRadius,
            y: DesignTokens.Shadow.cardY
        )
    }
}
