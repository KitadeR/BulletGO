import SwiftUI

struct TaskDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.featureRegistry) private var registry

    let tripID: TripID
    let taskID: TaskID

    var body: some View {
        Group {
            if let trip, let task, let leg {
                detail(trip: trip, task: task, leg: leg)
            } else {
                ContentUnavailableView("This concern isn’t available", systemImage: "questionmark")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.Color.canvas)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.taskDetail)
    }

    private var trip: Trip? {
        guard let trip = session.trip, trip.id == tripID else { return nil }
        return trip
    }

    private var task: TripTask? {
        trip?.tasks.first { $0.id == taskID }
    }

    private var leg: Leg? {
        guard let trip, let task, case .leg(let id) = task.scope else { return nil }
        return trip.legs.first { $0.id == id }
    }

    private var navigationTitle: LocalizedStringResource {
        guard let task else {
            return LocalizedStringResource("Something to check", comment: "Fallback Coming Up task title when the content key is unknown.")
        }
        return TripContentResolver.task(contentKey: task.contentKey).title
    }

    private func detail(trip: Trip, task: TripTask, leg: Leg) -> some View {
        let content = TripContentResolver.task(contentKey: task.contentKey)
        return ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                JourneyArtwork(kind: JourneyVisualProvider.kind(for: leg), isCompact: true)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))

                labeled(
                    title: LocalizedStringResource("Why this matters now", comment: "Task detail heading explaining timing."),
                    value: .localized(TripContentResolver.taskWhyNow(task.contentKey))
                )
                labeled(
                    title: LocalizedStringResource("Which journey", comment: "Task detail heading for the related leg."),
                    value: .verbatim(TripContentResolver.legTitle(trip: trip, legID: leg.id))
                )
                labeled(
                    title: LocalizedStringResource("What to do", comment: "Task detail heading for the next action."),
                    value: content.subtitle.map(DisplayText.localized) ?? .localized(content.title)
                )

                if let pack = session.pack, task.contentKey == ActionPurpose.captureDimensions {
                    Link(destination: pack.sourceURL) {
                        Text("JR Central oversized baggage")
                            .font(DesignTokens.Typography.caption)
                    }
                }

                PrimaryCTA(
                    title: TripContentResolver.taskPrimaryAction(task.contentKey),
                    systemImage: content.systemImage,
                    accessibilityID: AccessibilityID.taskPrimaryAction,
                    action: { openAction(for: task, leg: leg) }
                )
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private func labeled(title: LocalizedStringResource, value: DisplayText) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.secondaryText)
            DisplayTextLabel(text: value)
                .font(DesignTokens.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openAction(for task: TripTask, leg: Leg) {
        guard let feature = TripContentResolver.feature(forTask: task.contentKey) else {
            return
        }
        let context = FeatureContext(tripID: tripID, legID: leg.id, taskID: task.id)
        if let route = registry.resolve(feature, in: context) {
            router.push(route)
        }
    }
}
