import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let activityID: ActivityID
    @State private var title = ""
    @State private var place = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var confirmDateChange = false
    @State private var pendingDate: Date?
    @State private var didLoad = false

    private var activity: Activity? {
        session.trip.flatMap { trip in trip.activities.first { $0.id == activityID } }
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextField("Place", text: $place)
                Toggle("Has a date", isOn: $hasDate)
                if hasDate {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            Section {
                Button("Move to Unscheduled") {
                    Task { _ = await session.process(.applyMutation(.unscheduleActivity(activityID))) }
                }
                .disabled(activity?.scheduledAt.status != .confirmed)
                Button("Delete activity", role: .destructive) {
                    Task {
                        _ = await session.process(.applyMutation(.removeActivity(activityID)))
                        router.pop()
                    }
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            load()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                didLoad = true
            }
        }
        .onChange(of: title) { _, newValue in
            guard didLoad else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != activity?.title.value else { return }
            Task { _ = await session.process(.applyMutation(.updateActivityTitle(activityID, trimmed))) }
        }
        .onChange(of: place) { _, newValue in
            guard didLoad else { return }
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != activity?.place.value else { return }
            Task { _ = await session.process(.applyMutation(.updateActivityPlace(activityID, trimmed))) }
        }
        .onChange(of: hasDate) { _, newValue in
            guard didLoad else { return }
            if !newValue {
                Task { _ = await session.process(.applyMutation(.unscheduleActivity(activityID))) }
            }
        }
        .onChange(of: date) { _, newValue in
            guard didLoad, hasDate else { return }
            if activity?.scheduledAt.status == .confirmed {
                pendingDate = newValue
                confirmDateChange = true
            } else {
                Task { await saveDate(newValue) }
            }
        }
        .alert("Change this activity’s date?", isPresented: $confirmDateChange) {
            Button("Change") {
                if let pendingDate {
                    Task { await saveDate(pendingDate) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDate = nil }
        } message: {
            Text("Dragging does not change dates. This updates the scheduled day.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Talk") {
                    router.present(.itineraryTalk(tripID, .activity(activityID)))
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.activityDetail)
    }

    private func load() {
        title = activity?.title.value ?? ""
        place = activity?.place.value ?? ""
        if let scheduled = activity?.scheduledAt.value,
           let dateValue = scheduled.date.date(in: TimeZone(identifier: scheduled.timeZoneIdentifier) ?? .current) {
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
        _ = await session.process(.applyMutation(.updateActivityScheduledAt(activityID, moment)))
    }
}
