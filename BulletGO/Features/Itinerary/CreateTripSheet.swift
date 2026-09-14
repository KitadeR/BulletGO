import SwiftUI

struct CreateTripSheet: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    var tripID: TripID? = nil
    @State private var draft = TripEditDraft(
        name: "Japan trip",
        startDate: Date(),
        endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    )
    @State private var isSaving = false
    @State private var didLoad = false
    @State private var saveFailed = false
    @State private var saveFailedMessage = "Check the trip name and dates, then try again."
    @State private var showRangeConfirm = false
    @State private var pendingImpact = TripDateRangeImpact(items: [])

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $draft.name)
                        .accessibilityIdentifier(AccessibilityID.createTripName)
                    DatePicker("Start", selection: $draft.startDate, displayedComponents: .date)
                    DatePicker("End", selection: $draft.endDate, displayedComponents: .date)
                }
                if !pendingImpact.isEmpty {
                    Section("Plans outside these dates") {
                        ForEach(pendingImpact.items, id: \.self) { item in
                            Text(verbatim: displayName(for: item))
                        }
                    }
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
                    isEnabled: draft.canSave,
                    isBusy: isSaving,
                    accessibilityID: AccessibilityID.createTripSave,
                    action: { Task { await save(confirmedMove: false) } }
                )
                .padding(DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.createTripSheet)
        .onAppear(perform: loadExisting)
        .onChange(of: draft.startDate) { _, _ in refreshImpact() }
        .onChange(of: draft.endDate) { _, _ in refreshImpact() }
        .confirmationDialog(
            "Move plans off these dates?",
            isPresented: $showRangeConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Unscheduled") {
                Task { await save(confirmedMove: true) }
            }
            .accessibilityIdentifier(AccessibilityID.createTripDateRangeConfirm)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("These plans fall outside the new dates. Continuing keeps their times and order, and moves them to Unscheduled.")
        }
        .alert("Couldn’t save", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveFailedMessage)
        }
    }

    private func save(confirmedMove: Bool) async {
        isSaving = true
        defer { isSaving = false }
        do {
            if let tripID {
                if session.trip?.id != tripID {
                    await session.selectTrip(id: tripID)
                }
                guard let trip = session.trip else {
                    failSave(from: nil)
                    return
                }
                let impact = try draft.impact(in: trip)
                if !impact.isEmpty, !confirmedMove {
                    pendingImpact = impact
                    showRangeConfirm = true
                    return
                }
                let handling: TripDateRangeHandling = impact.isEmpty
                    ? .rejectOutOfRange
                    : .moveOutOfRangeToUnscheduledPreservingTiming
                let mutations = try draft.mutations(handling: handling)
                if await session.process(.applyMutations(mutations)) != nil {
                    router.dismissPresentation()
                } else if case .itemsOutsideDateRange(let items) = session.lastProcessError {
                    pendingImpact = TripDateRangeImpact(items: items)
                    showRangeConfirm = true
                } else {
                    failSave(from: session.lastProcessError)
                }
            } else {
                let dates = try draft.localDates()
                let created = try await session.createTrip(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    startDate: dates.0,
                    endDate: dates.1
                )
                if created {
                    router.dismissPresentation()
                } else {
                    failSave(from: session.lastProcessError)
                }
            }
        } catch let TripValidationError.itemsOutsideDateRange(items) {
            pendingImpact = TripDateRangeImpact(items: items)
            showRangeConfirm = true
        } catch {
            failSave(from: nil)
        }
    }

    private func loadExisting() {
        guard !didLoad else { return }
        didLoad = true
        guard let tripID, let trip = session.trips.first(where: { $0.id == tripID }) ?? session.trip else {
            return
        }
        draft = TripEditDraft.from(trip, now: session.now)
        refreshImpact()
    }

    private func refreshImpact() {
        guard let trip = session.trip ?? session.trips.first(where: { $0.id == tripID }) else {
            pendingImpact = TripDateRangeImpact(items: [])
            return
        }
        pendingImpact = (try? draft.impact(in: trip)) ?? TripDateRangeImpact(items: [])
    }

    private func failSave(from error: TripSessionModel.SessionProcessFailure?) {
        switch error {
        case .itemsOutsideDateRange:
            saveFailedMessage = "These plans fall outside the new dates. Move them to Unscheduled, or keep editing."
        case .failed, nil:
            saveFailedMessage = "Check the trip name and dates, then try again."
        }
        saveFailed = true
    }

    private func displayName(for item: TripTimelineItem) -> String {
        guard let trip = session.trip else { return "" }
        return TripDateRangeImpact.displayName(for: item, in: trip)
    }
}
