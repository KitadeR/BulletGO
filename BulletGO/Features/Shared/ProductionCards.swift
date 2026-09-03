import SwiftUI

struct NowConcernCard: View {
    var title: DisplayText
    var subtitle: DisplayText?
    var systemImage: String
    var accessibilityID: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Color.tint)
                    .frame(width: DesignTokens.TapTarget.minimum, height: DesignTokens.TapTarget.minimum)
                    .background(DesignTokens.Color.tintSoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    DisplayTextLabel(text: title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        DisplayTextLabel(text: subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
            .opaqueSurface(cornerRadius: DesignTokens.Radius.lg)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(DesignTokens.Color.now)
                    .frame(width: 5)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}

struct QuietComingUpRow: View {
    var title: DisplayText
    var subtitle: DisplayText?
    var systemImage: String
    var showsChevron: Bool
    var accessibilityID: String = ""
    var action: (() -> Void)?

    var body: some View {
        let content = HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(DesignTokens.Color.remembered)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                DisplayTextLabel(text: title)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    DisplayTextLabel(text: subtitle)
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(accessibilityID)
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}

struct CollapsedAnswerRow: View {
    var title: LocalizedStringResource
    var value: DisplayText
    var action: (() -> Void)?

    var body: some View {
        let row = HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DesignTokens.Color.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                DisplayTextLabel(text: value)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.TapTarget.minimum)
        .background(
            DesignTokens.Color.grouped,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

struct ResultPanel: View {
    var title: LocalizedStringResource
    var bodyText: LocalizedStringResource
    var footnote: LocalizedStringResource?
    var tone: PolicyResultTone
    var accessibilityID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label {
                Text(title)
                    .font(DesignTokens.Typography.title)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            Text(bodyText)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote {
                Text(footnote)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            color.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityID)
    }

    private var color: Color {
        switch tone {
        case .calm:
            DesignTokens.Color.success
        case .caution:
            DesignTokens.Color.caution
        case .blocked:
            DesignTokens.Color.danger
        }
    }

    private var icon: String {
        switch tone {
        case .calm:
            "checkmark.seal.fill"
        case .caution:
            "info.circle.fill"
        case .blocked:
            "exclamationmark.triangle.fill"
        }
    }
}

struct RouteRailRow: View {
    var title: String
    var subtitle: DisplayText
    var kind: JourneyVisualKind
    var isCurrent: Bool
    var isLeg: Bool
    var accessibilityID: String
    var action: (() -> Void)?

    var body: some View {
        let row = HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? DesignTokens.Color.tint : DesignTokens.Color.secondaryText.opacity(0.35))
                    .frame(width: isLeg ? 12 : 8, height: isLeg ? 12 : 8)
                Rectangle()
                    .fill(DesignTokens.Color.stroke)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 16)

            if isLeg {
                JourneyArtwork(kind: kind, isCompact: true)
                    .frame(width: 72, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
            } else {
                Image(systemName: "mappin.and.ellipse")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.remembered)
                    .frame(width: 72, height: 56)
                    .background(
                        DesignTokens.Color.grouped,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(isCurrent ? DesignTokens.Typography.headline : DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                DisplayTextLabel(text: subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Spacing.xs)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(minHeight: DesignTokens.TapTarget.minimum)

        if let action {
            Button(action: action) { row }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityIdentifier(accessibilityID)
        } else {
            row
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
