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
