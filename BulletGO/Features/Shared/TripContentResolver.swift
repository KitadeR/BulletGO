import Foundation

nonisolated struct ResolvedContent: Equatable, Sendable {
    var title: LocalizedStringResource
    var subtitle: LocalizedStringResource?
    var systemImage: String

    static func == (lhs: ResolvedContent, rhs: ResolvedContent) -> Bool {
        lhs.title.key == rhs.title.key
            && lhs.subtitle?.key == rhs.subtitle?.key
            && lhs.systemImage == rhs.systemImage
    }
}

nonisolated enum PolicyResultTone: Equatable, Sendable {
    case calm
    case caution
    case blocked
}

nonisolated enum TripContentResolver {
    static func remembered(
        _ item: DeferredPresentationItem,
        trip: Trip
    ) -> ResolvedContent {
        switch item.contentKey {
        case DeferredPresentationProjector.seatPreferenceContentKey:
            return seatPreferenceContent(item: item, trip: trip)
        default:
            return unknownRemembered
        }
    }

    static func task(contentKey: String) -> ResolvedContent {
        switch contentKey {
        case ActionPurpose.captureDimensions:
            ResolvedContent(
                title: LocalizedStringResource(
                    "Confirm luggage size",
                    comment: "NEXT task title for capturing bag dimensions."
                ),
                subtitle: LocalizedStringResource(
                    "Check whether oversized-baggage rules apply.",
                    comment: "NEXT task subtitle for capturing bag dimensions."
                ),
                systemImage: "suitcase"
            )
        case ActionPurpose.selectBookingMethod:
            ResolvedContent(
                title: LocalizedStringResource(
                    "Choose how to book",
                    comment: "NEXT task title for selecting a booking service."
                ),
                subtitle: LocalizedStringResource(
                    "Pick the option that fits this journey.",
                    comment: "NEXT task subtitle for selecting a booking service."
                ),
                systemImage: "ticket"
            )
        case ActionPurpose.reserveOversizedSeat:
            ResolvedContent(
                title: LocalizedStringResource(
                    "Reserve an oversized-baggage seat",
                    comment: "NEXT task title for reserving an oversized-baggage seat."
                ),
                subtitle: LocalizedStringResource(
                    "Your luggage needs a reserved space.",
                    comment: "NEXT task subtitle for reserving an oversized-baggage seat."
                ),
                systemImage: "tram.fill"
            )
        case ActionPurpose.verifyReservationMeetsBaggage:
            ResolvedContent(
                title: LocalizedStringResource(
                    "Check your reservation against luggage rules",
                    comment: "NEXT task title for verifying an existing reservation."
                ),
                subtitle: LocalizedStringResource(
                    "Make sure the booking still fits your bags.",
                    comment: "NEXT task subtitle for verifying an existing reservation."
                ),
                systemImage: "checkmark.seal"
            )
        default:
            ResolvedContent(
                title: LocalizedStringResource(
                    "Something to check",
                    comment: "Fallback Coming Up task title when the content key is unknown."
                ),
                subtitle: nil,
                systemImage: "clock"
            )
        }
    }

    static func transportSummary(for leg: Leg) -> LocalizedStringResource {
        guard leg.transportMode.status == .confirmed, let mode = leg.transportMode.value else {
            return LocalizedStringResource(
                "Not decided yet",
                comment: "Leg row subtitle when transport mode is not confirmed."
            )
        }
        switch mode {
        case .shinkansen:
            return LocalizedStringResource(
                "Shinkansen",
                comment: "Confirmed Shinkansen transport label on a leg row."
            )
        case .airplane:
            return LocalizedStringResource(
                "Flight",
                comment: "Confirmed airplane transport label on a leg row."
            )
        case .localTrain:
            return LocalizedStringResource(
                "Local train",
                comment: "Confirmed local-train transport label on a leg row."
            )
        case .other:
            return LocalizedStringResource(
                "Other transport",
                comment: "Confirmed other-transport label on a leg row."
            )
        }
    }

    static func resumeGuidance(trip: Trip, legID: LegID) -> ResolvedContent {
        _ = (trip, legID)
        return ResolvedContent(
            title: LocalizedStringResource(
                "Continue setting this up",
                comment: "Home card title when setup questions were skipped or left unfinished."
            ),
            subtitle: LocalizedStringResource(
                "Finish a few details so we know what matters now.",
                comment: "Home card subtitle for resuming unfinished guidance."
            ),
            systemImage: "ellipsis.circle"
        )
    }

    static func tripDatesText(_ trip: Trip) -> String? {
        guard let start = trip.startDate.value, let end = trip.endDate.value else {
            return nil
        }
        return "\(start.displayString) – \(end.displayString)"
    }

    static func staySubtitle(_ stay: Stay) -> String {
        if let checkIn = stay.checkIn.value?.date {
            return checkIn.displayString
        }
        return ""
    }

    static func legTitle(trip: Trip, legID: LegID) -> String {
        guard let leg = trip.legs.first(where: { $0.id == legID }) else {
            return ""
        }
        return "\(leg.origin.value ?? "") → \(leg.destination.value ?? "")"
    }

    static func summaryTitle(_ item: UnderstandingSummaryItem) -> LocalizedStringResource {
        switch item.contentKey {
        case "leg.transportMode", QuestionID.transport.rawValue:
            LocalizedStringResource("How you’re traveling", comment: "Summary heading for confirmed transport.")
        case "leg.seatPreference":
            LocalizedStringResource("Remembered for later", comment: "Summary heading for deferred seat preference.")
        case "leg.scheduledAt", QuestionID.legDate.rawValue:
            LocalizedStringResource("Travel date", comment: "Summary heading for the journey date.")
        case "leg.reservationStatus", QuestionID.ticketStatus.rawValue:
            LocalizedStringResource("Booking status", comment: "Summary heading for reservation status.")
        case "leg.baggagePresence", QuestionID.luggagePresence.rawValue:
            LocalizedStringResource("Luggage", comment: "Summary heading for luggage presence.")
        default:
            LocalizedStringResource("Still needed", comment: "Fallback summary heading.")
        }
    }

    static func summaryValue(_ item: UnderstandingSummaryItem) -> DisplayText {
        switch item.value {
        case .transportMode(let mode):
            .localized(transportLabel(mode))
        case .seatPreference(.mountFujiView):
            .localized(LocalizedStringResource(
                "Mt. Fuji view seat",
                comment: "Remembered seat preference for a Mount Fuji view."
            ))
        case .scheduledMoment(let moment):
            .verbatim("\(moment.date.year)/\(moment.date.month)/\(moment.date.day)")
        case .reservationStatus(let status):
            .localized(reservationLabel(status))
        case .baggagePresence(let presence):
            .localized(luggageLabel(presence))
        case .bookingService(let service):
            .verbatim(service.rawValue)
        case .baggageDimensions(let dimensions):
            .verbatim("\(Int(dimensions.totalCM)) cm")
        case .none:
            .localized(LocalizedStringResource(
                "We’ll ask this next.",
                comment: "Summary value when a fact is still missing."
            ))
        }
    }

    static func setupStepTitle(_ question: QuestionSpec) -> LocalizedStringResource {
        switch question.id {
        case .legDate:
            LocalizedStringResource("Travel date", comment: "Summary heading for the journey date.")
        case .transport:
            LocalizedStringResource("Transport", comment: "Leg detail label for the transport mode.")
        case .ticketStatus:
            LocalizedStringResource("Booking", comment: "Leg cockpit label for reservation status.")
        case .luggagePresence:
            LocalizedStringResource("Luggage", comment: "Summary heading for luggage presence.")
        default:
            questionPrompt(question)
        }
    }

    static func setupQuestionPrompt(_ question: QuestionSpec, leg: Leg) -> LocalizedStringResource {
        if question.id == .ticketStatus {
            return bookingQuestionPrompt(for: leg)
        }
        return questionPrompt(question)
    }

    static func bookingQuestionPrompt(for leg: Leg) -> LocalizedStringResource {
        guard leg.transportMode.status == .confirmed, let mode = leg.transportMode.value else {
            return LocalizedStringResource(
                "Have you booked this journey yet?",
                comment: "Setup question prompt for reservation status."
            )
        }
        switch mode {
        case .shinkansen:
            return LocalizedStringResource(
                "Have you already booked the Shinkansen?",
                comment: "Booking setup prompt after Shinkansen is confirmed."
            )
        case .airplane:
            return LocalizedStringResource(
                "Have you already booked the flight?",
                comment: "Booking setup prompt after airplane is confirmed."
            )
        case .localTrain:
            return LocalizedStringResource(
                "Have you already booked the local train?",
                comment: "Booking setup prompt after local train is confirmed."
            )
        case .other:
            return LocalizedStringResource(
                "Have you already booked this transport?",
                comment: "Booking setup prompt after other transport is confirmed."
            )
        }
    }

    static func setupStepSystemImage(_ question: QuestionSpec, leg: Leg) -> String {
        switch question.id {
        case .legDate:
            "calendar"
        case .transport:
            if leg.transportMode.status == .confirmed, leg.transportMode.value == .airplane {
                "airplane"
            } else {
                "tram.fill"
            }
        case .ticketStatus:
            "calendar.badge.clock"
        case .luggagePresence:
            "suitcase"
        default:
            "questionmark.circle"
        }
    }

    static func setupStepValue(question: QuestionSpec, trip: Trip, leg: Leg) -> DisplayText {
        switch question.target {
        case .legScheduledAt:
            if let date = leg.scheduledAt.value?.date {
                return .verbatim(date.displayString)
            }
        case .legTransportMode:
            return .localized(transportSummary(for: leg))
        case .legReservationStatus:
            if let status = leg.reservation.status.value {
                return summaryValue(
                    UnderstandingSummaryItem(
                        contentKey: "leg.reservationStatus",
                        scope: .leg(leg.id),
                        path: .leg(leg.id, .reservation),
                        value: .reservationStatus(status),
                        relatedQuestionID: .ticketStatus,
                        relatedDecisionPointID: nil
                    )
                )
            }
        case .legBaggagePresence:
            if let presence = leg.baggagePresence.value {
                return summaryValue(
                    UnderstandingSummaryItem(
                        contentKey: "leg.baggagePresence",
                        scope: .leg(leg.id),
                        path: .leg(leg.id, .baggagePresence),
                        value: .baggagePresence(presence),
                        relatedQuestionID: .luggagePresence,
                        relatedDecisionPointID: nil
                    )
                )
            }
        default:
            break
        }
        return .localized(
            LocalizedStringResource(
                "Saved",
                comment: "Collapsed answer fallback when a value is deferred."
            )
        )
    }

    static func deferredSetupValue() -> DisplayText {
        .localized(
            LocalizedStringResource(
                "Not sure — confirm later",
                comment: "Deferred setup step value when the traveler skipped a question."
            )
        )
    }

    static func questionPrompt(_ question: QuestionSpec) -> LocalizedStringResource {
        switch question.id {
        case .legDate:
            LocalizedStringResource(
                "When do you take this journey?",
                comment: "Setup question prompt for the travel date."
            )
        case .transport:
            LocalizedStringResource(
                "How are you traveling?",
                comment: "Setup question prompt for transport mode."
            )
        case .ticketStatus:
            LocalizedStringResource(
                "Have you booked this journey yet?",
                comment: "Setup question prompt for reservation status."
            )
        case .luggagePresence:
            LocalizedStringResource(
                "Are you bringing luggage?",
                comment: "Setup question prompt for luggage presence."
            )
        case .selectService:
            LocalizedStringResource(
                "How would you like to book?",
                comment: "Action question prompt for booking service."
            )
        case .baggageDimensions:
            LocalizedStringResource(
                "What are your bag’s dimensions?",
                comment: "Action question prompt for bag dimensions."
            )
        default:
            LocalizedStringResource(
                "A few details will help.",
                comment: "Fallback prompt when a question has no dedicated copy."
            )
        }
    }

    static func questionChoiceTitle(_ choice: QuestionChoice) -> LocalizedStringResource {
        switch choice.labelKey {
        case "transport.shinkansen":
            LocalizedStringResource("Shinkansen", comment: "Confirmed Shinkansen transport label on a leg row.")
        case "transport.airplane":
            LocalizedStringResource("Flight", comment: "Confirmed airplane transport label on a leg row.")
        case "transport.localTrain":
            LocalizedStringResource("Local train", comment: "Confirmed local-train transport label on a leg row.")
        case "transport.other":
            LocalizedStringResource("Other transport", comment: "Confirmed other-transport label on a leg row.")
        case "ticket.purchased":
            LocalizedStringResource("Already booked", comment: "Choice for a purchased reservation.")
        case "ticket.notPurchased":
            LocalizedStringResource("Not yet", comment: "Choice for a reservation that is not booked.")
        case "ticket.unsure":
            LocalizedStringResource("Not sure", comment: "Choice when the traveler does not know booking status.")
        case "luggage.yes":
            LocalizedStringResource("Yes, I have luggage", comment: "Choice confirming luggage is present.")
        case "luggage.no":
            LocalizedStringResource("No luggage", comment: "Choice confirming there is no luggage.")
        case "luggage.skip":
            LocalizedStringResource("I’ll answer later", comment: "Choice to defer luggage presence.")
        default:
            LocalizedStringResource("Choose this option", comment: "Fallback choice label.")
        }
    }

    static func taskWhyNow(_ contentKey: String) -> LocalizedStringResource {
        switch contentKey {
        case ActionPurpose.captureDimensions:
            LocalizedStringResource(
                "Oversized-baggage rules depend on the total of three sides.",
                comment: "Explanation of why luggage size matters now."
            )
        case ActionPurpose.selectBookingMethod:
            LocalizedStringResource(
                "This Shinkansen journey is not booked yet, so the booking path comes first.",
                comment: "Explanation of why choosing a booking method matters now."
            )
        case ActionPurpose.reserveOversizedSeat:
            LocalizedStringResource(
                "Your bag is over 160 cm, so it needs a reserved oversized-baggage space.",
                comment: "Explanation of why an oversized seat is needed now."
            )
        default:
            LocalizedStringResource(
                "This is the next thing that changes what you should do.",
                comment: "Fallback explanation of why a concern appears now."
            )
        }
    }

    static func taskPrimaryAction(_ contentKey: String) -> LocalizedStringResource {
        switch contentKey {
        case ActionPurpose.captureDimensions:
            LocalizedStringResource("Measure your bag", comment: "Primary action to open baggage measurement.")
        case ActionPurpose.selectBookingMethod:
            LocalizedStringResource("See booking methods", comment: "Primary action to open booking-method guidance.")
        default:
            LocalizedStringResource("Continue", comment: "Fallback primary action on a concern detail.")
        }
    }

    static func feature(forTask contentKey: String) -> AppFeature? {
        switch contentKey {
        case ActionPurpose.captureDimensions:
            .baggageCheck
        case ActionPurpose.selectBookingMethod, ActionPurpose.verifyReservationMeetsBaggage:
            .bookingMethod
        case ActionPurpose.reserveOversizedSeat:
            .vehicleEquipment
        default:
            nil
        }
    }

    static func policyResultTitle(_ requirement: BaggagePolicyPack.ReservationRequirement) -> LocalizedStringResource {
        switch requirement {
        case .notRequired:
            LocalizedStringResource(
                "No oversized-baggage seat needed",
                comment: "Calm result title when total size is 160 cm or less."
            )
        case .required:
            LocalizedStringResource(
                "Reserve an oversized-baggage space",
                comment: "Calm result title when total size is 161 to 250 cm."
            )
        case .notAllowed:
            LocalizedStringResource(
                "This bag is over the limit",
                comment: "Calm result title when total size is over 250 cm."
            )
        }
    }

    static func policyResultBody(_ requirement: BaggagePolicyPack.ReservationRequirement) -> LocalizedStringResource {
        switch requirement {
        case .notRequired:
            LocalizedStringResource(
                "The three sides add up to 160 cm or less, so the usual oversized-baggage reservation does not apply.",
                comment: "Result explanation for bags at or under 160 cm."
            )
        case .required:
            LocalizedStringResource(
                "The three sides add up to 161–250 cm. On Tokaido-Sanyo Shinkansen, reserve an oversized-baggage area when you book.",
                comment: "Result explanation for bags between 161 and 250 cm."
            )
        case .notAllowed:
            LocalizedStringResource(
                "The three sides add up to more than 250 cm, which is over the JR Central limit for this service.",
                comment: "Result explanation for bags over 250 cm."
            )
        }
    }

    static func policyTone(_ requirement: BaggagePolicyPack.ReservationRequirement) -> PolicyResultTone {
        switch requirement {
        case .notRequired:
            .calm
        case .required:
            .caution
        case .notAllowed:
            .blocked
        }
    }

    private static func transportLabel(_ mode: TransportMode) -> LocalizedStringResource {
        switch mode {
        case .shinkansen:
            LocalizedStringResource("Shinkansen", comment: "Confirmed Shinkansen transport label on a leg row.")
        case .airplane:
            LocalizedStringResource("Flight", comment: "Confirmed airplane transport label on a leg row.")
        case .localTrain:
            LocalizedStringResource("Local train", comment: "Confirmed local-train transport label on a leg row.")
        case .other:
            LocalizedStringResource("Other transport", comment: "Confirmed other-transport label on a leg row.")
        }
    }

    static func reservationStatusText(_ reservation: Reservation) -> LocalizedStringResource {
        reservationLabel(reservation.status.status == .confirmed ? (reservation.status.value ?? .unknown) : .unknown)
    }

    static func bookingServiceText(_ reservation: Reservation) -> LocalizedStringResource? {
        guard reservation.service.status == .confirmed, let service = reservation.service.value else {
            return nil
        }
        return switch service {
        case .smartEX:
            LocalizedStringResource("Smart EX", comment: "Confirmed Smart EX booking service.")
        case .klook:
            LocalizedStringResource("Klook", comment: "Confirmed Klook booking service.")
        case .ticketMachine:
            LocalizedStringResource("Ticket machine", comment: "Confirmed ticket-machine booking service.")
        case .other:
            LocalizedStringResource("Other booking service", comment: "Confirmed other booking service.")
        }
    }

    private static func reservationLabel(_ status: ReservationStatus) -> LocalizedStringResource {
        switch status {
        case .booked:
            LocalizedStringResource("Already booked", comment: "Choice for a purchased reservation.")
        case .notBooked:
            LocalizedStringResource("Not yet", comment: "Choice for a reservation that is not booked.")
        case .unknown, .cancelled:
            LocalizedStringResource("Not sure", comment: "Choice when the traveler does not know booking status.")
        }
    }

    private static func luggageLabel(_ presence: BaggagePresence) -> LocalizedStringResource {
        switch presence {
        case .yes:
            LocalizedStringResource("Yes, I have luggage", comment: "Choice confirming luggage is present.")
        case .no:
            LocalizedStringResource("No luggage", comment: "Choice confirming there is no luggage.")
        case .unknown:
            LocalizedStringResource("I’ll answer later", comment: "Choice to defer luggage presence.")
        }
    }

    private static func seatPreferenceContent(
        item: DeferredPresentationItem,
        trip: Trip
    ) -> ResolvedContent {
        let preference: SeatPreference?
        if case .leg(let id, .seatPreference) = item.field {
            preference = trip.legs.first { $0.id == id }?.seatPreference.value
        } else {
            preference = nil
        }
        let title: LocalizedStringResource
        switch preference {
        case .mountFujiView:
            title = LocalizedStringResource(
                "Mt. Fuji view seat",
                comment: "Remembered seat preference for a Mount Fuji view."
            )
        case .none:
            title = unknownRemembered.title
        }
        let subtitle: LocalizedStringResource?
        if case .deferred = item.presentationTiming {
            subtitle = LocalizedStringResource(
                "We’ll mention this when you choose seats.",
                comment: "Deferred seat-preference subtitle on Coming Up and remembered lists."
            )
        } else {
            subtitle = LocalizedStringResource(
                "Saved for this journey.",
                comment: "Remembered seat-preference subtitle after it is no longer deferred."
            )
        }
        return ResolvedContent(
            title: title,
            subtitle: subtitle,
            systemImage: "bookmark"
        )
    }

    private static let unknownRemembered = ResolvedContent(
        title: LocalizedStringResource(
            "Saved detail",
            comment: "Fallback remembered-item title when the content key is unknown."
        ),
        subtitle: LocalizedStringResource(
            "We’ll bring this up at the right time.",
            comment: "Fallback remembered-item subtitle when the content key is unknown."
        ),
        systemImage: "bookmark"
    )
}
