import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let activityID: ActivityID
    @State private var draft: ActivityEditDraft?
    @State private var search = MapKitPlaceSearch()
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var showDiscard = false

    private var activity: Activity? {
        session.trip.flatMap { trip in trip.activities.first { $0.id == activityID } }
    }

    private var isDirty: Bool {
        guard let activity, let draft else { return false }
        return draft.isDirty(comparedTo: activity)
    }

    var body: some View {
        Form {
            if let draftBinding = Binding($draft) {
                Section {
                    TextField("Title", text: draftBinding.title)
                    Toggle("Add to a day", isOn: draftBinding.hasDate)
                    if draftBinding.wrappedValue.hasDate {
                        DatePicker("Date", selection: draftBinding.date, displayedComponents: .date)
                    }
                    Picker("Time", selection: draftBinding.timing) {
                        ForEach(ActivityTimingChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    if draftBinding.wrappedValue.timing == .start || draftBinding.wrappedValue.timing == .range {
                        DatePicker("Starts", selection: draftBinding.startTime, displayedComponents: .hourAndMinute)
                    }
                    if draftBinding.wrappedValue.timing == .range {
                        DatePicker("Ends", selection: draftBinding.endTime, displayedComponents: .hourAndMinute)
                    }
                }
                PlaceSearchField(
                    title: "Place",
                    text: draftBinding.placeText,
                    search: search,
                    onSelect: { reference in
                        draft?.placeReference = reference
                        draft?.placeText = reference.name
                    },
                    onClear: { draft?.placeReference = nil }
                )
            }
            ItemRecordsView(tripID: tripID, scope: .activity(activityID))
            Section {
                Button("Move to Unscheduled") {
                    Task { _ = await session.process(.applyMutation(.unscheduleActivity(activityID))) }
                }
                .disabled(activity?.scheduledAt.value?.date == nil)
                Button("Delete activity", role: .destructive) {
                    Task {
                        if await session.process(.applyMutation(.removeActivity(activityID))) != nil {
                            router.pop()
                        } else {
                            saveFailed = true
                        }
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
        guard !didLoad, let activity else { return }
        didLoad = true
        draft = ActivityEditDraft.from(activity, now: session.now)
    }

    private func attemptCancel() {
        if isDirty {
            showDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() async {
        guard let draft else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let mutations = try draft.mutations(activityID: activityID)
            if await session.process(.applyMutations(mutations)) == nil {
                saveFailed = true
            }
        } catch {
            saveFailed = true
        }
    }
}
