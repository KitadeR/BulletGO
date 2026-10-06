import SwiftUI

nonisolated enum BookingMethodID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case smartEX
    case klook
    case jrWestOnline
    case station
    case japanRailPass

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .smartEX:
            LocalizedStringResource("SmartEX", comment: "Booking method card for SmartEX.")
        case .klook:
            LocalizedStringResource("Klook", comment: "Confirmed Klook booking service.")
        case .jrWestOnline:
            LocalizedStringResource(
                "JR-WEST online",
                comment: "Booking method card for JR-WEST online reservation."
            )
        case .station:
            LocalizedStringResource("At the station", comment: "Booking method card for buying at the station.")
        case .japanRailPass:
            LocalizedStringResource(
                "JAPAN RAIL PASS",
                comment: "Booking method card for a Japan Rail Pass."
            )
        }
    }

    var advances: Bool { self == .smartEX }

    var detail: LocalizedStringResource {
        switch self {
        case .smartEX: "東海道・山陽・九州新幹線の公式予約サービス。会員登録が必要です。"
        case .klook: "取扱区間・受取方法・荷物条件をKlookの画面で確認してください。"
        case .jrWestOnline: "JR-WESTの対象区間と受取条件を公式画面で確認してください。"
        case .station: "JRの窓口・指定席券売機で購入。駅と営業時間を確認してください。"
        case .japanRailPass: "パスの利用対象列車を確認。のぞみ・みずほは別の専用券が必要です。"
        }
    }

    var externalURL: URL? {
        let value: String
        switch self {
        case .smartEX: value = "https://smart-ex.jp/reservation/reserve_smart/sp/"
        case .klook: value = "https://www.klook.com/ja/japan-rail/shinkansen/"
        case .jrWestOnline: value = "https://www.jr-odekake.net/goyoyaku/e5489/reservation/"
        case .station: value = "https://railway.jr-central.co.jp/support-atvm/"
        case .japanRailPass: value = "https://japanrailpass.net/use/reserved-seat-reservation/"
        }
        return URL(string: value)
    }

    func route(tripID: TripID, legID: LegID) -> AppRoute {
        if advances {
            .bookingMethodSmartEX(tripID, legID)
        } else {
            .bookingMethodComingSoon(tripID, legID, self)
        }
    }
}

struct BookingMethodListView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let legID: LegID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("この移動の予約方法")
                    .font(.largeTitle.bold())
                Text("各サービスの条件を確認して選んでください。予約と決済はサービス側で行います。")
                    .font(.subheadline)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                if let routeTitle {
                    Text(verbatim: routeTitle)
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(GuidedAddPalette.primaryText)
                }
                ForEach(BookingMethodID.allCases) { method in
                    Button {
                        router.push(method.route(tripID: tripID, legID: legID))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(method.title)
                                    .font(DesignTokens.Typography.headline)
                                    .foregroundStyle(GuidedAddPalette.primaryText)
                                Text(method.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(GuidedAddPalette.secondaryText)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            Text("›")
                                .font(.system(size: 22))
                                .foregroundStyle(GuidedAddPalette.secondaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                        .background(
                            GuidedAddPalette.card,
                            in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityID.bookingMethod(method.rawValue))
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidedAddPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.bookingMethods)
    }

    private var routeTitle: String? {
        guard let leg = session.trip?.legs.first(where: { $0.id == legID }),
              session.trip?.id == tripID
        else {
            return nil
        }
        let origin = leg.origin.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let destination = leg.destination.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !origin.isEmpty || !destination.isEmpty else { return nil }
        return "\(origin) → \(destination)"
    }
}

nonisolated struct SmartEXGuidance: Equatable, Sendable {
    var routeTitle: String?
    var dateText: String?
    var needsOversizedSeat: Bool

    static let officialURL = URL(string: "https://smart-ex.jp/")!
    static let guideURL = URL(string: "https://smart-ex.jp/reservation/reserve_smart/sp/")!

    static func unavailablePack(trip: Trip, leg: Leg) -> SmartEXGuidance {
        SmartEXGuidance(
            routeTitle: BookingMethodRouteTitle.make(trip: trip, tripID: trip.id, legID: leg.id),
            dateText: dateText(for: leg),
            needsOversizedSeat: false
        )
    }

    static func make(trip: Trip, leg: Leg, pack: BaggagePolicyPack) -> SmartEXGuidance {
        SmartEXGuidance(
            routeTitle: BookingMethodRouteTitle.make(trip: trip, tripID: trip.id, legID: leg.id),
            dateText: dateText(for: leg),
            needsOversizedSeat: needsOversizedSeat(trip: trip, leg: leg, pack: pack)
        )
    }

    private static func dateText(for leg: Leg) -> String? {
        guard leg.scheduledAt.status == .confirmed, let date = leg.scheduledAt.value?.date else {
            return nil
        }
        return date.displayString
    }

    static func needsOversizedSeat(trip: Trip, leg: Leg, pack: BaggagePolicyPack) -> Bool {
        leg.bagIDs.contains { bagID in
            guard let bag = trip.baggageInventory.first(where: { $0.id == bagID }),
                  bag.dimensions.status == .confirmed,
                  let dimensions = bag.dimensions.value
            else {
                return false
            }
            return pack.requirement(forTotalCM: dimensions.totalCM) == .required
        }
    }
}

nonisolated enum BookingRecord {
    static func mutations(legID: LegID, details: ReservationDetails, service: BookingService?) -> [TripMutation] {
        var values: [TripMutation] = [
            .setReservationStatus(legID, .booked, .confirmed),
            .updateReservationDetails(.leg(legID), details)
        ]
        if let service { values.append(.setBookingService(legID, service)) }
        return values
    }

    static func hasRideDetails(_ details: ReservationDetails) -> Bool {
        !trim(details.trainName).isEmpty
            && !trim(details.car).isEmpty
            && !trim(details.seat).isEmpty
    }

    static func canSave(trainName: String, car: String, seat: String) -> Bool {
        !trim(trainName).isEmpty || !trim(car).isEmpty || !trim(seat).isEmpty
    }

    static func savedDetails(
        existing: ReservationDetails,
        trainName: String,
        car: String,
        seat: String,
        confirmationNumber: String
    ) -> ReservationDetails? {
        var details = existing
        details.trainName = emptyAsNil(trainName)
        details.car = emptyAsNil(car)
        details.seat = emptyAsNil(seat)
        details.confirmationNumber = emptyAsNil(confirmationNumber)
        return details
    }

    static func rideSummary(_ details: ReservationDetails) -> String {
        [details.trainName, details.car, details.seat]
            .compactMap { value in
                let text = trim(value)
                return text.isEmpty ? nil : text
            }
            .joined(separator: " · ")
    }

    private static func emptyAsNil(_ value: String?) -> String? {
        let text = trim(value)
        return text.isEmpty ? nil : text
    }

    private static func trim(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct BookingConfirmationView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let legID: LegID

    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Check the booking")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                Text("Look at the completion email, or the reservation screen in SmartEX.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryCTA(
                    title: LocalizedStringResource(
                        "The booking is done",
                        comment: "Button that records this journey as booked from the traveler’s own confirmation."
                    ),
                    isBusy: isSaving,
                    accessibilityID: AccessibilityID.bookingConfirmationDone
                ) {
                    Task { await confirm() }
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidedAddPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.bookingConfirmation)
    }

    private func confirm() async {
        router.push(.bookingRecordSmartEX(tripID, legID))
    }
}

struct BookingRecordView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router

    let tripID: TripID
    let legID: LegID
    var bookingService: BookingService? = nil

    @State private var trainName = ""
    @State private var car = ""
    @State private var seat = ""
    @State private var confirmationNumber = ""
    @State private var providerName = ""
    @State private var oversizedSeatReserved: Bool?
    @State private var didLoad = false
    @State private var isSaving = false
    @State private var saveFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Record the booking")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                Text("Check the confirmation from the service you used. You can save only what you know.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 16) {
                    field(
                        "Booking service (optional)",
                        text: $providerName,
                        identifier: "booking-record-service"
                    )
                    field(
                        "Train",
                        text: $trainName,
                        identifier: AccessibilityID.bookingRecordTrain
                    )
                    field(
                        "Car number",
                        text: $car,
                        identifier: AccessibilityID.bookingRecordCar
                    )
                    field(
                        "Seat number",
                        text: $seat,
                        identifier: AccessibilityID.bookingRecordSeat
                    )
                    field(
                        "Confirmation number",
                        text: $confirmationNumber,
                        identifier: AccessibilityID.bookingRecordReference
                    )
                    if requiresOversizedSeat {
                        Text("予約内容に特大荷物用座席がありますか？")
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Button("ある") { oversizedSeatReserved = true }
                            Button("ない") { oversizedSeatReserved = false }
                            Button("不明") { oversizedSeatReserved = nil }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GuidedAddPalette.card,
                    in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous)
                )
                if saveFailed {
                    Text("Couldn’t save that. Try this step again.")
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryCTA(
                    title: LocalizedStringResource(
                        "Record it",
                        comment: "Saves the train, car, and seat the traveler read on the completion screen."
                    ),
                    isEnabled: true,
                    isBusy: isSaving,
                    accessibilityID: AccessibilityID.bookingRecordSave
                ) {
                    Task { await save() }
                }
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidedAddPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.bookingRecord)
        .onAppear(perform: load)
    }

    private func field(
        _ title: LocalizedStringResource,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DesignTokens.Typography.footnote)
                .foregroundStyle(GuidedAddPalette.secondaryText)
            TextField("", text: text)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(GuidedAddPalette.primaryText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: GuidedAddMetrics.inputHeight)
                .background(
                    GuidedAddPalette.canvas,
                    in: RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: GuidedAddMetrics.inputRadius, style: .continuous)
                        .stroke(GuidedAddPalette.inputStroke, lineWidth: 1)
                }
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(title))
        }
    }

    private var reservation: Reservation? {
        guard session.trip?.id == tripID else { return nil }
        return session.trip?.legs.first { $0.id == legID }?.reservation
    }

    private var requiresOversizedSeat: Bool {
        guard let trip = session.trip,
              let leg = trip.legs.first(where: { $0.id == legID }),
              let pack = session.pack else { return false }
        return SmartEXGuidance.needsOversizedSeat(trip: trip, leg: leg, pack: pack)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let details = reservation?.details
        trainName = details?.trainName ?? ""
        car = details?.car ?? ""
        seat = details?.seat ?? ""
        confirmationNumber = details?.confirmationNumber ?? ""
        providerName = details?.providerName ?? (bookingService == .smartEX ? "SmartEX" : "")
        oversizedSeatReserved = details?.oversizedSeatReserved
    }

    private func save() async {
        guard !isSaving,
              let existing = reservation?.details,
              let details = BookingRecord.savedDetails(
                existing: existing,
                trainName: trainName,
                car: car,
                seat: seat,
                confirmationNumber: confirmationNumber
              )
        else { return }
        isSaving = true
        var recorded = details
        let trimmedProvider = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        recorded.providerName = trimmedProvider.isEmpty ? nil : trimmedProvider
        recorded.oversizedSeatReserved = oversizedSeatReserved
        let saved = await session.process(.applyMutations(
            BookingRecord.mutations(legID: legID, details: recorded, service: bookingService)
        ))
        isSaving = false
        guard saved != nil else {
            saveFailed = true
            return
        }
        router.popToLegDetail()
    }
}

struct BookingMethodSmartEXView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    let tripID: TripID
    let legID: LegID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                rideCard
                if guidance.needsOversizedSeat {
                    oversizedBaggageNote
                }
                bookingSteps
                Link(destination: SmartEXGuidance.guideURL) {
                    HStack(spacing: 8) {
                        Text("See the official booking guide")
                        Image(systemName: "arrow.up.right")
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, GuidedAddMetrics.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidedAddPalette.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActions
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.bookingMethodSmartEX)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Book with SmartEX")
                .font(.largeTitle.bold())
                .foregroundStyle(GuidedAddPalette.primaryText)
            Text("Booking and payment happen on SmartEX. Use these details as you go.")
                .font(.subheadline)
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rideCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("YOUR JOURNEY")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(GuidedAddPalette.secondaryText)
            if let routeTitle = guidance.routeTitle {
                Text(verbatim: routeTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let dateText = guidance.dateText {
                Label {
                    Text(verbatim: dateText)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
                .foregroundStyle(GuidedAddPalette.secondaryText)
            } else {
                Button {
                    router.popToLegDetail()
                } label: {
                    Label("Set the travel date before booking", systemImage: "calendar.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GuidedAddPalette.card, in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius))
    }

    private var oversizedBaggageNote: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "suitcase.rolling")
                .font(.title3.weight(.medium))
                .frame(width: 25)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose an oversized-baggage seat")
                    .font(.subheadline.weight(.semibold))
                Text("Select “Seat with Oversized Baggage Area” in SmartEX. Check the seat map before purchase.")
                    .font(.subheadline)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(GuidedAddPalette.mutedFill, in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.bookingMethodSmartEXOversized)
    }

    private var bookingSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IN SMARTEX")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .padding(.bottom, 14)
            bookingStep(1, title: "Log in and search", detail: "A SmartEX account is needed. Enter the stations, date, time and number of travelers.")
            bookingStep(2, title: "Choose a train and seat", detail: "Check the fare and seat conditions before continuing.")
            bookingStep(3, title: "Review and purchase", detail: "Payment completes in SmartEX. Check My Trips or the completion email.", isLast: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bookingStep(
        _ number: Int,
        title: LocalizedStringResource,
        detail: LocalizedStringResource,
        isLast: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(verbatim: String(number))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(GuidedAddPalette.ctaText)
                    .frame(width: 30, height: 30)
                    .background(GuidedAddPalette.ctaFill, in: Circle())
                if !isLast {
                    Rectangle()
                        .fill(GuidedAddPalette.inputStroke)
                        .frame(width: 1, height: 40)
                        .padding(.vertical, 5)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(GuidedAddPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var bottomActions: some View {
        VStack(spacing: 2) {
            PrimaryCTA(
                title: LocalizedStringResource("Open SmartEX to book", comment: "Open the external SmartEX booking website."),
                accessibilityID: AccessibilityID.bookingMethodSmartEXOpen
            ) {
                openURL(SmartEXGuidance.officialURL)
            }
            Button {
                router.push(.bookingRecordSmartEX(tripID, legID))
            } label: {
                Text("Already booked? Record the details")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.bookingMethodSmartEXConfirm)
        }
        .padding(.horizontal, GuidedAddMetrics.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            GuidedAddPalette.canvas
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var guidance: SmartEXGuidance {
        guard let trip = session.trip, trip.id == tripID,
              let leg = trip.legs.first(where: { $0.id == legID })
        else {
            return SmartEXGuidance(routeTitle: nil, dateText: nil, needsOversizedSeat: false)
        }
        guard let pack = try? PackLoader.loadProduction(from: .main) else {
            return SmartEXGuidance.unavailablePack(trip: trip, leg: leg)
        }
        return SmartEXGuidance.make(trip: trip, leg: leg, pack: pack)
    }

}

struct BookingMethodComingSoonView: View {
    @Environment(TripSessionModel.self) private var session

    let tripID: TripID
    let legID: LegID
    let method: BookingMethodID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(method.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(GuidedAddPalette.primaryText)
            if let routeTitle {
                Text(verbatim: routeTitle)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(GuidedAddPalette.primaryText)
            }
            Text("This way of booking is not in this version yet.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(GuidedAddPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(method.detail)
                .font(.body)
            if let url = method.externalURL {
                Link("外部サービスの案内を開く", destination: url)
                    .font(.body.weight(.semibold))
            }
            Spacer()
        }
        .padding(.horizontal, GuidedAddMetrics.horizontal)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GuidedAddPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityID.bookingMethodComingSoon)
    }

    private var routeTitle: String? {
        BookingMethodRouteTitle.make(trip: session.trip, tripID: tripID, legID: legID)
    }
}

enum BookingMethodRouteTitle {
    static func make(trip: Trip?, tripID: TripID, legID: LegID) -> String? {
        guard let trip, trip.id == tripID, let leg = trip.legs.first(where: { $0.id == legID }) else {
            return nil
        }
        let origin = leg.origin.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let destination = leg.destination.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !origin.isEmpty || !destination.isEmpty else { return nil }
        return "\(origin) → \(destination)"
    }
}
