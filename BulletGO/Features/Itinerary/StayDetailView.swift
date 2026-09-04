import SwiftUI

struct StayDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let stayID: StayID
    @State private var place = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var confirmDateChange = false
    @State private var pendingDate: Date?
    @State private var didLoad = false

    private var stay: Stay? {
        session.trip.flatMap { trip in trip.stays.first { $0.id == stayID } }
    }

    var body: some View {
        Form {
            Section {
                TextField("Place", text: $place)
                Toggle("Has a check-in date", isOn: $hasDate)
                if hasDate {
                    DatePicker("Check-in", selection: $date, displayedComponents: .date)
                }
            }
            Section {
                Button("Move to Unscheduled", role: .none) {
                    Task { _ = await session.process(.applyMutation(.unscheduleStay(stayID))) }
                }
                .disabled(stay?.checkIn.status != .confirmed)
                Button("Delete stay", role: .destructive) {
                    Task {
                        _ = await session.process(.applyMutation(.removeStay(stayID)))
                        router.pop()
                    }
                }
            }
        }
        .navigationTitle("Stay")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            load()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                didLoad = true
            }
        }
        .onChange(of: place) { _, newValue in
            guard didLoad else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != stay?.place.value else { return }
            Task { _ = await session.process(.applyMutation(.updateStayPlace(stayID, trimmed))) }
        }
        .onChange(of: hasDate) { _, newValue in
            guard didLoad else { return }
            if !newValue {
                Task { _ = await session.process(.applyMutation(.unscheduleStay(stayID))) }
            }
        }
        .onChange(of: date) { _, newValue in
            guard didLoad, hasDate else { return }
            if stay?.checkIn.status == .confirmed {
                pendingDate = newValue
                confirmDateChange = true
            } else {
                Task { await saveDate(newValue) }
            }
        }
        .alert("Change this stay’s date?", isPresented: $confirmDateChange) {
            Button("Change") {
                if let pendingDate {
                    Task { await saveDate(pendingDate) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDate = nil }
        } message: {
            Text("Confirmed check-in times are not changed by dragging. This updates the stay date.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Talk") {
                    router.present(.itineraryTalk(tripID, .stay(stayID)))
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.stayDetail)
    }

    private func load() {
        place = stay?.place.value ?? ""
        if let checkIn = stay?.checkIn.value,
           let dateValue = checkIn.date.date(in: TimeZone(identifier: checkIn.timeZoneIdentifier) ?? .current) {
            hasDate = true
            date = dateValue
        }
    }

    private func saveDate(_ value: Date) async {
        let timeZone = TimeZone.current
        guard let local = try? LocalDate(date: value, timeZone: timeZone),
              let moment = try? ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier) else {
            return
        }
        _ = await session.process(.applyMutation(.updateStayCheckIn(stayID, moment)))
    }
}
