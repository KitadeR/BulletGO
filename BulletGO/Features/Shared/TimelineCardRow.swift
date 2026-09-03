import SwiftUI

struct DisplayTextLabel: View {
    var text: DisplayText

    var body: some View {
        switch text {
        case .localized(let resource):
            Text(resource)
        case .verbatim(let value):
            Text(verbatim: value)
        }
    }
}

struct TimelineCardRow: View {
    enum Kind {
        case standard
        case remembered
        case current
    }

    var title: DisplayText
    var subtitle: DisplayText?
    var systemImage: String
    var kind: Kind
    var showsChevron: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(iconStyle)
                .frame(
                    width: DesignTokens.TapTarget.minimum,
                    height: DesignTokens.TapTarget.minimum
                )
                .background(iconBackground, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DisplayTextLabel(text: title)
                    .font(kind == .current ? DesignTokens.Typography.headline : DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    DisplayTextLabel(text: subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, kind == .current ? DesignTokens.Spacing.md : DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
        .background(cardFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var cardFill: Color {
        switch kind {
        case .remembered:
            DesignTokens.Color.quietFill
        case .standard, .current:
            DesignTokens.Color.grouped
        }
    }

    private var iconBackground: Color {
        switch kind {
        case .remembered:
            DesignTokens.Color.grouped
        case .standard, .current:
            DesignTokens.Color.canvas
        }
    }

    private var iconStyle: Color {
        switch kind {
        case .remembered:
            DesignTokens.Color.secondaryText
        case .standard, .current:
            DesignTokens.Color.tint
        }
    }
}
