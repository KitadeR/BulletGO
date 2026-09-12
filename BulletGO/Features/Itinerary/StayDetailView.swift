import SwiftUI

struct StayDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let stayID: StayID
    @State private var place = ""
    @State private var hasCheckIn = false
    @State private var checkIn = Date()
    @State private var hasCheckOut = false
    @State private var checkOut = Date().addingTimeInterval(86_400)
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var showDiscard = false

    private var stay: Stay? {
        session.trip.flatMap { trip in trip.stays.first { $0.id == stayID } }
    }

    private var isDirty: Bool {
        guard let stay else { return false }
        return place != (stay.place.value ?? "")
            || hasCheckIn != (stay.checkIn.status == .confirmed)
            || hasCheckOut != (stay.checkOut.status == .confirmed)
    }

    var body: some View {
        Form {
            Section {
                TextField("Place", text: $place)
                Toggle("Check-in date known", isOn: $hasCheckIn)
                if hasCheckIn {
                    DatePicker("Check-in", selection: $checkIn, displayedComponents: .date)
                }
                Toggle("Check-out date known", isOn: $hasCheckOut)
                if hasCheckOut {
                    DatePicker("Check-out", selection: $checkOut, displayedComponents: .date)
                }
            }
            ItemRecordsView(tripID: tripID, scope: .stay(stayID))
            Section {
                Button("Move to Unscheduled") {
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
                    .disabled(!isDirty || isSaving || !canSave)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Talk") {
                    router.present(.itineraryTalk(tripID, .stay(stayID)))
                }
            }
        }
        .confirmationDialog("Discard changes?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Couldn’t save", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .accessibilityIdentifier(AccessibilityID.stayDetail)
    }

    private var canSave: Bool {
        !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!hasCheckIn || !hasCheckOut || checkOut >= checkIn)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        place = stay?.place.value ?? ""
        if let value = stay?.checkIn.value,
           let dateValue = value.date.date(in: TimeZone(identifier: value.timeZoneIdentifier) ?? .current) {
            hasCheckIn = stay?.checkIn.status == .confirmed
            checkIn = dateValue
        }
        if let value = stay?.checkOut.value,
           let dateValue = value.date.date(in: TimeZone(identifier: value.timeZoneIdentifier) ?? .current) {
            hasCheckOut = stay?.checkOut.status == .confirmed
            checkOut = dateValue
        }
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
        let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            saveFailed = true
            return
        }
        var mutations: [TripMutation] = [.updateStayPlace(stayID, trimmed)]
        let timeZone = TimeZone.current
        do {
            if hasCheckIn {
                let local = try LocalDate(date: checkIn, timeZone: timeZone)
                mutations.append(.updateStayCheckIn(stayID, try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier)))
            } else {
                mutations.append(.unscheduleStay(stayID))
            }
            if hasCheckOut {
                let local = try LocalDate(date: checkOut, timeZone: timeZone)
                mutations.append(.updateStayCheckOut(stayID, try ScheduledMoment(date: local, timeZoneIdentifier: timeZone.identifier)))
            }
        } catch {
            saveFailed = true
            return
        }
        if await session.process(.applyMutations(mutations)) == nil {
            saveFailed = true
        }
    }
}
