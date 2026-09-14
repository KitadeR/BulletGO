import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let activityID: ActivityID
    @State private var title = ""
    @State private var place = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var timing: ActivityTimingChoice = .none
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var showDiscard = false

    private var activity: Activity? {
        session.trip.flatMap { trip in trip.activities.first { $0.id == activityID } }
    }

    private var isDirty: Bool {
        guard let activity else { return false }
        return title != (activity.title.value ?? "")
            || place != (activity.place.value ?? "")
            || hasDate != (activity.scheduledAt.status == .confirmed)
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextField("Place", text: $place)
                Toggle("Add to a day", isOn: $hasDate)
                if hasDate {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Time", selection: $timing) {
                        ForEach(ActivityTimingChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    if timing == .start || timing == .range {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                    }
                    if timing == .range {
                        DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            ItemRecordsView(tripID: tripID, scope: .activity(activityID))
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
        .navigationBarBackButtonHidden(isDirty)
        .onAppear(perform: load)
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { attemptCancel() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!isDirty || isSaving)
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Couldn’t save", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier(AccessibilityID.activityDetail)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        title = activity?.title.value ?? ""
        place = activity?.place.value ?? ""
        if let scheduled = activity?.scheduledAt.value,
           let dateValue = scheduled.date.date(in: TimeZone(identifier: scheduled.timeZoneIdentifier) ?? .current) {
            hasDate = activity?.scheduledAt.status == .confirmed
            date = dateValue
            if scheduled.isAllDay {
                timing = .allDay
            } else if scheduled.time != nil, scheduled.endTime != nil {
                timing = .range
            } else if scheduled.time != nil {
                timing = .start
            } else {
                timing = .none
            }
            if let time = scheduled.time {
                startTime = combine(dateValue, time)
            }
            if let end = activity?.endsAt.value?.time ?? scheduled.endTime {
                endTime = combine(dateValue, end)
            }
        }
    }

    private func combine(_ date: Date, _ time: LocalTime) -> Date {
        var components = Calendar.current.dateComponents(in: .current, from: date)
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components) ?? date
    }

    private func attemptCancel() {
        if isDirty {
            showDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedPlace.isEmpty else {
            saveFailed = true
            return
        }
        var mutations: [TripMutation] = [
            .updateActivityTitle(activityID, trimmedTitle.isEmpty ? trimmedPlace : trimmedTitle),
            .updateActivityPlace(activityID, trimmedPlace.isEmpty ? trimmedTitle : trimmedPlace),
        ]
        if hasDate {
            do {
                let moment = try makeMoment()
                mutations.append(.updateActivityScheduledAt(activityID, moment))
                if timing == .range {
                    let end = try ScheduledMoment(
                        date: moment.date,
                        time: try LocalTime(
                            hour: Calendar.current.component(.hour, from: endTime),
                            minute: Calendar.current.component(.minute, from: endTime)
                        ),
                        timeZoneIdentifier: moment.timeZoneIdentifier
                    )
                    mutations.append(.updateActivityEndsAt(activityID, end))
                } else {
                    mutations.append(.updateActivityEndsAt(activityID, nil))
                }
            } catch {
                saveFailed = true
                return
            }
        } else {
            mutations.append(.unscheduleActivity(activityID))
        }
        if await session.process(.applyMutations(mutations)) == nil {
            saveFailed = true
        }
    }

    private func makeMoment() throws -> ScheduledMoment {
        let timeZone = TimeZone.current
        let local = try LocalDate(date: date, timeZone: timeZone)
        switch timing {
        case .none:
            return try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier)
        case .allDay:
            return try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier, isAllDay: true)
        case .start, .range:
            let time = try LocalTime(
                hour: Calendar.current.component(.hour, from: startTime),
                minute: Calendar.current.component(.minute, from: startTime)
            )
            let endTimeValue: LocalTime?
            if timing == .range {
                endTimeValue = try LocalTime(
                    hour: Calendar.current.component(.hour, from: endTime),
                    minute: Calendar.current.component(.minute, from: endTime)
                )
            } else {
                endTimeValue = nil
            }
            return try ScheduledMoment(
                date: local,
                time: time,
                timeZoneIdentifier: timeZone.identifier,
                endTime: endTimeValue
            )
        }
    }
}
