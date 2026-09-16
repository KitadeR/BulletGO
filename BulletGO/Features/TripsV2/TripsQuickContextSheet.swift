import SwiftUI

struct TripsQuickContextSheet: View {
    var snapshot: TripsQuickContextSnapshot
    var onOpen: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if let heading = snapshot.heading, !snapshot.items.isEmpty {
                        Text(heading)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Color.primaryText)
                    }
                    if !snapshot.items.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.xs) {
                            ForEach(snapshot.items) { item in
                                itemRow(item)
                            }
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PrimaryCTA(
                title: LocalizedStringResource(
                    "View details",
                    comment: "Quick Context action that opens the full journey, stay, or activity detail."
                ),
                prominent: true,
                accessibilityID: AccessibilityID.tripsQuickContextDetails
            ) {
                onOpen(snapshot.detail)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.height(Self.sheetHeight)])
        .presentationDragIndicator(.visible)
        .modifier(QuickContextSheetChrome())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.tripsQuickContext)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(verbatim: snapshot.title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let metaText = snapshot.metaText {
                Text(verbatim: metaText)
                    .font(DesignTokens.Typography.footnote)
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func itemRow(_ item: TripsQuickContextItem) -> some View {
        Button {
            guard let destination = item.destination else {
                return
            }
            onOpen(destination)
        } label: {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let why = item.why {
                        Text(why)
                            .font(DesignTokens.Typography.footnote)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: DesignTokens.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.footnote.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.TapTarget.minimum, alignment: .center)
            .opaqueSurface(cornerRadius: DesignTokens.Radius.md)
        }
        .buttonStyle(.plain)
        .disabled(item.destination == nil)
        .accessibilityIdentifier(AccessibilityID.tripsQuickContextItem(item.id))
    }

    private static let sheetHeight: CGFloat = 336
}

private struct QuickContextSheetChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            content.presentationBackground(.regularMaterial)
        }
    }
}

#if DEBUG
#Preview("Quick Context") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TripsQuickContextSheet(
                snapshot: TripsQuickContextSnapshot(
                    title: "東京 → 京都",
                    metaText: "10:03 · 予約済み",
                    heading: LocalizedStringResource(
                        "Before departure",
                        comment: "Quick Context heading for a journey that is still ahead."
                    ),
                    items: [
                        TripsQuickContextItem(
                            id: "setup-preview",
                            title: LocalizedStringResource(
                                "Continue setting this up",
                                comment: "Home card title when setup questions were skipped or left unfinished."
                            ),
                            why: LocalizedStringResource(
                                "Finish a few details so we know what matters now.",
                                comment: "Home card subtitle for resuming unfinished guidance."
                            ),
                            destination: nil
                        ),
                    ],
                    detail: .legDetail(TripID(), LegID())
                ),
                onOpen: { _ in }
            )
        }
}
#endif
