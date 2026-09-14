import SwiftUI

struct StayDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let stayID: StayID
    @State private var draft: StayEditDraft?
    @State private var search = MapKitPlaceSearch()
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var showDiscard = false

    private var stay: Stay? {
        session.trip.flatMap { trip in trip.stays.first { $0.id == stayID } }
    }

    private var isDirty: Bool {
        guard let stay, let draft else { return false }
        return draft.isDirty(comparedTo: stay)
    }

    var body: some View {
        Form {
            if let draftBinding = Binding($draft) {
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
                Section {
                    Toggle("Check-in date known", isOn: draftBinding.hasCheckIn)
                    if draftBinding.wrappedValue.hasCheckIn {
                        DatePicker("Check-in", selection: draftBinding.checkIn, displayedComponents: .date)
                    }
                    Toggle("Check-out date known", isOn: draftBinding.hasCheckOut)
                    if draftBinding.wrappedValue.hasCheckOut {
                        DatePicker("Check-out", selection: draftBinding.checkOut, displayedComponents: .date)
                    }
                }
            }
            ItemRecordsView(tripID: tripID, scope: .stay(stayID))
            Section {
                Button("Move to Unscheduled") {
                    Task { _ = await session.process(.applyMutation(.unscheduleStay(stayID))) }
                }
                .disabled(stay?.checkIn.value?.date == nil)
                Button("Delete stay", role: .destructive) {
                    Task {
                        if await session.process(.applyMutation(.removeStay(stayID))) != nil {
                            router.pop()
                        } else {
                            saveFailed = true
                        }
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
                    .disabled(!isDirty || isSaving || !(draft?.canSave ?? false))
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

    private func load() {
        guard !didLoad, let stay else { return }
        didLoad = true
        draft = StayEditDraft.from(stay, now: session.now)
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
            let mutations = try draft.mutations(stayID: stayID)
            if await session.process(.applyMutations(mutations)) == nil {
                saveFailed = true
            }
        } catch {
            saveFailed = true
        }
    }
}
