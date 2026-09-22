import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let tripID: TripID
    let activityID: ActivityID
    @State private var draft: ActivityEditDraft?
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let draftBinding = Binding($draft) {
                    GuidedAddCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("予定")
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Color.primaryText)
                            TextField("Title", text: draftBinding.title)
                                .font(DesignTokens.Typography.headline)
                                .padding(.horizontal, 14)
                                .frame(height: GuidedAddMetrics.inputHeight)
                                .background(
                                    DesignTokens.Color.canvas,
                                    in: RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
                                )
                        }
                        .padding(18)
                    }
                    GuidedAddPlaceEditor(
                        title: "場所",
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
                            Toggle("Add to a day", isOn: draftBinding.hasDate)
                            if draftBinding.wrappedValue.hasDate {
                                DatePicker("Date", selection: draftBinding.date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                            }
                            Text("時刻")
                                .font(DesignTokens.Typography.headline)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                                ForEach(ActivityTimingChoice.allCases) { choice in
                                    GuidedAddTimeChip(
                                        title: choice.title,
                                        isSelected: draftBinding.wrappedValue.timing == choice
                                    ) {
                                        draft?.timing = choice
                                    }
                                }
                            }
                            if draftBinding.wrappedValue.timing == .start || draftBinding.wrappedValue.timing == .range {
                                DatePicker("Starts", selection: draftBinding.startTime, displayedComponents: .hourAndMinute)
                            }
                            if draftBinding.wrappedValue.timing == .range {
                                DatePicker("Ends", selection: draftBinding.endTime, displayedComponents: .hourAndMinute)
                            }
                        }
                        .padding(18)
                    }
                }
                GuidedAddCard {
                    Form {
                        ItemRecordsView(tripID: tripID, scope: .activity(activityID))
                    }
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 8) {
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
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.bottom, 24)
        }
        .background(DesignTokens.Color.canvas)
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
        }
        .safeAreaInset(edge: .bottom) {
            if isDirty {
                PrimaryCTA(
                    title: LocalizedStringResource("Save", comment: "Save activity edits."),
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
