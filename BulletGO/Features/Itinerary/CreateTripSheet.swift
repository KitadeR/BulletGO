import SwiftUI

struct CreateTripSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    @State private var name = "Japan trip"
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isSaving = false

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
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { router.dismissPresentation() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryCTA(
                    title: "Create trip",
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
            let created = try await session.createTrip(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: start,
                endDate: end
            )
            if created {
                router.dismissPresentation()
            }
        } catch {
            isSaving = false
        }
    }
}
