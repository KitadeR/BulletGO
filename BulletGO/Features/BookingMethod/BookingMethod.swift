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
                            Text(method.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(GuidedAddPalette.primaryText)
                            Spacer(minLength: 8)
                            Text("›")
                                .font(.system(size: 22))
                                .foregroundStyle(GuidedAddPalette.secondaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
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

struct SmartEXGuidance: Equatable, Sendable {
    var routeTitle: String?
    var dateText: String?
    var needsOversizedSeat: Bool

    static let officialURL = URL(string: "https://smart-ex.jp/")!

    static let flow: [LocalizedStringResource] = [
        LocalizedStringResource("Set the conditions", comment: "SmartEX flow line for setting search conditions."),
        LocalizedStringResource("Choose a train", comment: "SmartEX flow line for choosing a train."),
        LocalizedStringResource("Choose a seat", comment: "SmartEX flow line for choosing a seat."),
        LocalizedStringResource("Purchase", comment: "SmartEX flow line for purchasing the reservation.")
    ]

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

    private static func needsOversizedSeat(trip: Trip, leg: Leg, pack: BaggagePolicyPack) -> Bool {
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

struct BookingMethodSmartEXView: View {
    @Environment(TripSessionModel.self) private var session
    @Environment(\.openURL) private var openURL

    let tripID: TripID
    let legID: LegID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(BookingMethodID.smartEX.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(GuidedAddPalette.primaryText)
                guidanceCard(
                    title: LocalizedStringResource(
                        "Before you start",
                        comment: "Card title for what is needed before opening SmartEX."
                    )
                ) {
                    Text("A SmartEX membership is required.")
                    Text("Use the EX app if you book in the app.")
                }
                guidanceCard(
                    title: LocalizedStringResource(
                        "For this ride",
                        comment: "Card title for facts about this journey on the SmartEX screen."
                    )
                ) {
                    if let routeTitle = guidance.routeTitle {
                        Text(verbatim: routeTitle)
                    }
                    if let dateText = guidance.dateText {
                        Text(verbatim: dateText)
                    }
                    if guidance.needsOversizedSeat {
                        Text("On the condition screen, choose an oversized-baggage seat. Non-reserved seats are not shown.")
                            .accessibilityIdentifier(AccessibilityID.bookingMethodSmartEXOversized)
                    }
                }
                guidanceCard(
                    title: LocalizedStringResource(
                        "In SmartEX",
                        comment: "Card title for the large SmartEX booking flow."
                    )
                ) {
                    ForEach(Array(SmartEXGuidance.flow.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
                PrimaryCTA(
                    title: LocalizedStringResource(
                        "Open SmartEX",
                        comment: "Button that opens the official SmartEX website."
                    ),
                    accessibilityID: AccessibilityID.bookingMethodSmartEXOpen
                ) {
                    openURL(SmartEXGuidance.officialURL)
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
        .accessibilityIdentifier(AccessibilityID.bookingMethodSmartEX)
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

    private func guidanceCard(
        title: LocalizedStringResource,
        @ViewBuilder lines: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(GuidedAddPalette.primaryText)
            VStack(alignment: .leading, spacing: 6) {
                lines()
            }
            .font(DesignTokens.Typography.body)
            .foregroundStyle(GuidedAddPalette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GuidedAddPalette.card,
            in: RoundedRectangle(cornerRadius: GuidedAddMetrics.cardRadius, style: .continuous)
        )
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
