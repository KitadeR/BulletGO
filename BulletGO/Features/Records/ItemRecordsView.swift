import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ItemRecordsView: View {
    @Environment(TripSessionModel.self) private var session

    var tripID: TripID
    var scope: DomainScope

    @State private var noteBody = ""
    @State private var didLoad = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImportingFile = false
    @State private var renaming: AttachmentRecord?
    @State private var renameText = ""
    @State private var attachmentFailed = false
    @State private var noteFailed = false

    var body: some View {
        Group {
            ReservationEditor(scope: scope)
            notesSection
            attachmentsSection
        }
        .onAppear(perform: loadNote)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await importFile(url) }
            }
        }
        .alert("Couldn’t save file", isPresented: $attachmentFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("Couldn’t save note", isPresented: $noteFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("Rename file", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("File name", text: $renameText)
            Button("Save") {
                guard let renaming else { return }
                Task {
                    if await session.process(.applyMutation(.renameAttachment(renaming.id, renameText))) == nil {
                        attachmentFailed = true
                    }
                    self.renaming = nil
                }
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Note", text: $noteBody, axis: .vertical)
                .lineLimit(3...8)
            Button("Save note") {
                Task { await saveNote() }
            }
        }
        .accessibilityIdentifier(AccessibilityID.notesEditor)
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            ForEach(attachments) { record in
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: record.fileName)
                        Text(verbatim: record.utType)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.secondaryText)
                    }
                    Spacer()
                    Button("Rename") {
                        renaming = record
                        renameText = record.fileName
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { await deleteAttachment(record) }
                    }
                }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add photo", systemImage: "photo")
            }
            Button("Add file") { isImportingFile = true }
        }
        .accessibilityIdentifier(AccessibilityID.attachmentsEditor)
    }

    private var attachments: [AttachmentRecord] {
        (session.trip?.attachments ?? []).filter { $0.scope == scope }
    }

    private func loadNote() {
        guard !didLoad else { return }
        didLoad = true
        noteBody = session.trip?.notes.first(where: { $0.scope == scope })?.body ?? ""
    }

    private func saveNote() async {
        let body = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = session.trip?.notes.first(where: { $0.scope == scope })
        if body.isEmpty {
            if let existing, await session.process(.applyMutation(.removeNote(existing.id))) == nil {
                noteFailed = true
            }
            return
        }
        let note = ScopedNote(
            id: existing?.id ?? NoteID(),
            scope: scope,
            body: body,
            updatedAt: session.now
        )
        if await session.process(.applyMutation(.upsertNote(note))) == nil {
            noteFailed = true
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            attachmentFailed = true
            return
        }
        if await session.importAttachment(data: data, fileName: "photo.jpg", utType: .jpeg, scope: scope) == nil {
            attachmentFailed = true
        }
    }

    private func importFile(_ url: URL) async {
        if await session.importAttachment(
            from: url,
            fileName: url.lastPathComponent,
            utType: UTType(filenameExtension: url.pathExtension) ?? .data,
            scope: scope
        ) == nil {
            attachmentFailed = true
        }
    }

    private func deleteAttachment(_ record: AttachmentRecord) async {
        if await session.removeAttachment(id: record.id) == nil {
            attachmentFailed = true
        }
    }
}

struct ReservationEditor: View {
    @Environment(TripSessionModel.self) private var session
    var scope: DomainScope

    @State private var status: ReservationStatus = .unknown
    @State private var confirmation = ""
    @State private var provider = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var trainName = ""
    @State private var car = ""
    @State private var seat = ""
    @State private var didLoad = false
    @State private var saveFailed = false

    var body: some View {
        Section("Reservation") {
            Picker("Status", selection: $status) {
                Text("Unknown").tag(ReservationStatus.unknown)
                Text("Not booked").tag(ReservationStatus.notBooked)
                Text("Booked").tag(ReservationStatus.booked)
                Text("Cancelled").tag(ReservationStatus.cancelled)
            }
            TextField("Confirmation number", text: $confirmation)
            TextField("Provider", text: $provider)
            TextField("Location", text: $location)
            if isTransport {
                TextField("Origin", text: $origin)
                TextField("Destination", text: $destination)
                TextField("Train or flight", text: $trainName)
                TextField("Car", text: $car)
                TextField("Seat", text: $seat)
            }
            TextField("Notes", text: $notes, axis: .vertical)
            Button("Save reservation") {
                Task { await save() }
            }
        }
        .accessibilityIdentifier(AccessibilityID.reservationEditor)
        .onAppear(perform: load)
        .alert("Couldn’t save reservation", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var isTransport: Bool {
        if case .leg = scope { return true }
        return false
    }

    private var reservation: Reservation? {
        guard let trip = session.trip else { return nil }
        switch scope {
        case .trip:
            return nil
        case .leg(let id):
            return trip.legs.first { $0.id == id }?.reservation
        case .stay(let id):
            return trip.stays.first { $0.id == id }?.reservation
        case .activity(let id):
            return trip.activities.first { $0.id == id }?.reservation
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let reservation else { return }
        status = reservation.status.value ?? .unknown
        let details = reservation.details
        confirmation = details.confirmationNumber ?? ""
        provider = details.providerName ?? ""
        location = details.location ?? ""
        notes = details.notes ?? ""
        origin = details.origin ?? ""
        destination = details.destination ?? ""
        trainName = details.trainName ?? ""
        car = details.car ?? ""
        seat = details.seat ?? ""
    }

    private func save() async {
        let details = ReservationDetails(
            origin: trimmed(origin),
            destination: trimmed(destination),
            departureDate: reservation?.details.departureDate,
            departureTime: reservation?.details.departureTime,
            arrivalTime: reservation?.details.arrivalTime,
            trainName: trimmed(trainName),
            car: trimmed(car),
            seat: trimmed(seat),
            confirmationNumber: trimmed(confirmation),
            providerName: trimmed(provider),
            location: trimmed(location),
            notes: trimmed(notes),
            startDate: reservation?.details.startDate,
            startTime: reservation?.details.startTime,
            endDate: reservation?.details.endDate,
            endTime: reservation?.details.endTime
        )
        let slotStatus: SlotStatus = status == .unknown ? .skipped : .confirmed
        let mutations: [TripMutation] = [
            .updateReservationDetails(scope, details),
            .updateScopedReservationStatus(scope, status, slotStatus),
        ]
        if await session.process(.applyMutations(mutations)) == nil {
            saveFailed = true
        }
    }

    private func trimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
