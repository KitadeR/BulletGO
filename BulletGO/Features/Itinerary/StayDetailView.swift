import SwiftUI

struct StayDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let stayID: StayID
    @State private var draft: StayEditDraft?
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let draftBinding = Binding($draft) {
                    GuidedAddPlaceEditor(
                        title: "どこに泊まる？",
                        fieldTitle: "Place",
                        text: draftBinding.placeText,
                        selected: draft?.placeReference,
                        onSelect: { reference in
                            draft?.placeReference = reference
                            draft?.placeText = reference.name
                        },
                        onClear: { draft?.placeReference = nil }
                    )
                    GuidedAddCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle("Check-in date known", isOn: draftBinding.hasCheckIn)
                            if draftBinding.wrappedValue.hasCheckIn {
                                DatePicker("Check-in", selection: draftBinding.checkIn, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                            Toggle("Check-out date known", isOn: draftBinding.hasCheckOut)
                            if draftBinding.wrappedValue.hasCheckOut {
                                DatePicker("Check-out", selection: draftBinding.checkOut, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                        }
                        .padding(18)
                    }
                }
                GuidedAddCard {
                    Form {
                        ItemRecordsView(tripID: tripID, scope: .stay(stayID))
                    }
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.bottom, 24)
        }
        .background(DesignTokens.Color.canvas)
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
        }
        .safeAreaInset(edge: .bottom) {
            if isDirty {
                PrimaryCTA(
                    title: LocalizedStringResource("Save", comment: "Save stay edits."),
                    isEnabled: draft?.canSave ?? false,
                    isBusy: isSaving,
                    action: { Task { await save() } }
                )
                .padding(DesignTokens.Spacing.md)
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
