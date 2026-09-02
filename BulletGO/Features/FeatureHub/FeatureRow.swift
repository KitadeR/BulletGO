import SwiftUI

struct FeatureRow: View {
    let registration: FeatureRegistration

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: registration.systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.tint)
                .frame(
                    width: DesignTokens.TapTarget.minimum,
                    height: DesignTokens.TapTarget.minimum
                )
                .background(DesignTokens.Color.grouped, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(registration.title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(registration.summary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    FeatureRow(registration: FeatureRegistry.production.registration(for: .baggageCheck))
        .padding()
}
