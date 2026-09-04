import SwiftUI

struct AddItineraryItemSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    @State private var kind: Kind = .transport
    @State private var origin = ""
    @State private var destination = ""
    @State private var place = ""
    @State private var title = ""
    @State private var date = Date()
    @State private var includeDate = true
    @State private var isSaving = false

    private enum Kind: String, CaseIterable, Identifiable {
        case transport
        case stay
        case activity

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Transport").tag(Kind.transport)
                    Text("Stay").tag(Kind.stay)
                    Text("Activity").tag(Kind.activity)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.addItineraryKind)

                switch kind {
                case .transport:
                    TextField("From", text: $origin)
                        .accessibilityIdentifier(AccessibilityID.addItineraryOrigin)
                    TextField("To", text: $destination)
                        .accessibilityIdentifier(AccessibilityID.addItineraryDestination)
                    Toggle("Has a date", isOn: $includeDate)
                    if includeDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                case .stay:
                    TextField("Place", text: $place)
                    Toggle("Has a check-in date", isOn: $includeDate)
                    if includeDate {
                        DatePicker("Check-in", selection: $date, displayedComponents: .date)
                    }
                case .activity:
                    TextField("Title", text: $title)
                    TextField("Place", text: $place)
                    Toggle("Has a date", isOn: $includeDate)
                    if includeDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Add to trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.dismissPresentation() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryCTA(
                    title: "Add",
                    isEnabled: canSave,
                    isBusy: isSaving,
                    accessibilityID: AccessibilityID.addItinerarySave,
                    action: { Task { await save() } }
                )
                .padding(DesignTokens.Spacing.md)
            }
        }
        .accessibilityIdentifier(AccessibilityID.addItinerarySheet)
    }

    private var canSave: Bool {
        switch kind {
        case .transport:
            !origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .stay:
            !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .activity:
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let now = Date()
        let timeZone = TimeZone.current
        do {
            let moment: ScheduledMoment? = includeDate
                ? try ScheduledMoment(date: LocalDate(date: date, timeZone: timeZone), timeZoneIdentifier: timeZone.identifier)
                : nil
            let mutation: TripMutation
            switch kind {
            case .transport:
                let leg = try ItineraryItemFactory.makeLeg(
                    origin: origin.trimmingCharacters(in: .whitespacesAndNewlines),
                    destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                    scheduledAt: moment,
                    at: now
                )
                mutation = .addLeg(leg, atTimelineIndex: nil)
            case .stay:
                let stay = try ItineraryItemFactory.makeStay(
                    place: place.trimmingCharacters(in: .whitespacesAndNewlines),
                    checkIn: moment,
                    at: now
                )
                mutation = .addStay(stay, atTimelineIndex: nil)
            case .activity:
                let activity = try ItineraryItemFactory.makeActivity(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    place: place.trimmingCharacters(in: .whitespacesAndNewlines),
                    scheduledAt: moment,
                    at: now
                )
                mutation = .addActivity(activity, atTimelineIndex: nil)
            }
            _ = await session.process(.applyMutation(mutation))
            router.dismissPresentation()
        } catch {
            isSaving = false
        }
    }
}
