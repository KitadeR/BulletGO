import SwiftUI

struct CreateTripSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    var tripID: TripID? = nil
    @State private var name = "Japan trip"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $name)
                        .accessibilityIdentifier(AccessibilityID.createTripName)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle(tripID == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.dismissPresentation() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryCTA(
                    title: tripID == nil ? "Create trip" : "Save",
                    isEnabled: canSave,
                    isBusy: isSaving,
                    accessibilityID: AccessibilityID.createTripSave,
                    action: { Task { await save() } }
                )
                .padding(DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.createTripSheet)
        .onAppear(perform: loadExisting)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startDate <= endDate
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let timeZone = TimeZone.current
        do {
            let start = try LocalDate(date: startDate, timeZone: timeZone)
            let end = try LocalDate(date: endDate, timeZone: timeZone)
            if let tripID {
                let mutations: [TripMutation] = [
                    .setTripName(name.trimmingCharacters(in: .whitespacesAndNewlines)),
                    .setTripStartDate(start),
                    .setTripEndDate(end),
                ]
                if session.trip?.id != tripID {
                    await session.selectTrip(id: tripID)
                }
                if await session.process(.applyMutations(mutations)) != nil {
                    router.dismissPresentation()
                }
            } else {
                let created = try await session.createTrip(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    startDate: start,
                    endDate: end
                )
                if created {
                    router.dismissPresentation()
                }
            }
        } catch {
            isSaving = false
        }
    }

    private func loadExisting() {
        guard !didLoad else { return }
        didLoad = true
        guard let tripID, let trip = session.trips.first(where: { $0.id == tripID }) ?? session.trip else {
            return
        }
        name = trip.name.value ?? name
        if let start = trip.startDate.value?.date(in: TimeZone.current) {
            startDate = start
        }
        if let end = trip.endDate.value?.date(in: TimeZone.current) {
            endDate = end
        }
    }
}
