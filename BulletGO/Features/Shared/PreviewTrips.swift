#if DEBUG
import Foundation

enum PreviewTrips {
    static let reference: Trip = {
        do {
            return try ReferenceTripFactory(now: { Date(timeIntervalSince1970: 1_788_393_600) }).makeReferenceTrip()
        } catch {
            preconditionFailure("Failed to make preview trip: \(error)")
        }
    }()

    static let withComingUpAndRemembered: Trip = {
        do {
            let now = Date(timeIntervalSince1970: 1_788_393_600)
            var trip = try ReferenceTripFactory(now: { now }).makeReferenceTrip()
            trip = try TripMutationApplier.apply(
                .setSeatPreference(trip.legs[0].id, .mountFujiView),
                to: trip,
                at: now
            )
            let focus = trip.legs[0].id
            trip.tasks = [
                previewTask(contentKey: ActionPurpose.captureDimensions, importance: .required, scope: focus),
                previewTask(contentKey: ActionPurpose.selectBookingMethod, importance: .important, scope: focus),
                previewTask(contentKey: ActionPurpose.reserveOversizedSeat, importance: .recommended, scope: focus),
                previewTask(contentKey: ActionPurpose.verifyReservationMeetsBaggage, importance: .optional, scope: focus),
            ]
            return trip
        } catch {
            preconditionFailure("Failed to make remembered preview trip: \(error)")
        }
    }()

    static let readyForNow: Trip = {
        do {
            let now = Date(timeIntervalSince1970: 1_788_393_600)
            let catalog = try QuestionCatalogLoader.loadProduction(from: .main)
            let pack = try PackLoader.loadProduction(from: .main)
            let brain = TripBrain(catalog: catalog, pack: pack, clock: .fixed(now))
            var trip = try ReferenceTripFactory(now: { now }).makeReferenceTrip()
            let focus = ReferenceTripIdentity.tokyoKyoto
            trip = try brain.process(
                trip: trip,
                command: .applyMutations([
                    .setTransportMode(focus, .shinkansen),
                    .setSeatPreference(focus, .mountFujiView),
                ])
            ).updatedTrip
            guard let start = trip.startDate.value else {
                preconditionFailure("Reference trip is missing a start date.")
            }
            let moment = try ScheduledMoment(
                date: start,
                timeZoneIdentifier: "Asia/Tokyo"
            )
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.legDate, .scheduledMoment(moment))
            ).updatedTrip
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.ticketStatus, .choice("notBooked"))
            ).updatedTrip
            trip = try brain.process(
                trip: trip,
                command: .answerQuestion(.luggagePresence, .choice("yes"))
            ).updatedTrip
            return trip
        } catch {
            preconditionFailure("Failed to make ready-now preview trip: \(error)")
        }
    }()

    private static func previewTask(
        contentKey: String,
        importance: TaskImportance,
        scope: LegID
    ) -> TripTask {
        TripTask(
            id: TaskID(),
            contentKey: contentKey,
            type: .check,
            state: .notStarted,
            importance: importance,
            relevantPhases: [.planning, .booking],
            deadline: nil,
            dependencies: [],
            evidence: .none,
            scope: .leg(scope),
            relatedActionID: nil,
            relatedPolicyID: .jrShinkansenOversizedBaggage,
            relatedGuideID: nil,
            completionCondition: .userConfirmsDone
        )
    }

    static let phaseClockNow = Date(timeIntervalSince1970: 1_788_393_600)

    static let beforeTrip: Trip = {
        dated(readyForNow, startOffset: 27, endOffset: 34, phase: .beforeTrip)
    }()

    static let inTrip: Trip = {
        dated(readyForNow, startOffset: -1, endOffset: 6, phase: .inTrip)
    }()

    static let finished: Trip = {
        dated(readyForNow, startOffset: -20, endOffset: -12, phase: .finished)
    }()

    static let planning: Trip = {
        do {
            var trip = readyForNow
            trip.startDate = try Slot.unknown(updatedAt: phaseClockNow)
            trip.endDate = try Slot.unknown(updatedAt: phaseClockNow)
            trip.currentContext.tripPhase = .planning
            return trip
        } catch {
            preconditionFailure("Failed to make planning preview trip: \(error)")
        }
    }()

    static let japaneseTraveler: Trip = {
        var trip = readyForNow
        do {
            trip.traveler.preferredLanguage = try Slot.confirmed(
                value: "ja",
                source: .userStated,
                updatedAt: phaseClockNow
            )
            return trip
        } catch {
            preconditionFailure("Failed to make Japanese traveler preview: \(error)")
        }
    }()

    static let setupPaused: Trip = {
        do {
            let now = phaseClockNow
            var trip = reference
            try trip.updateLeg(id: ReferenceTripIdentity.tokyoKyoto) { leg in
                leg.scheduledAt = try Slot.confirmed(
                    value: try ScheduledMoment(
                        date: LocalDate(year: 2026, month: 10, day: 1),
                        timeZoneIdentifier: "Asia/Tokyo"
                    ),
                    source: .userStated,
                    updatedAt: now
                )
                leg.transportMode = try Slot.confirmed(value: .shinkansen, source: .userStated, updatedAt: now)
                leg.reservation.status = try Slot.skipped(updatedAt: now)
                leg.baggagePresence = try Slot.skipped(updatedAt: now)
            }
            return trip
        } catch {
            preconditionFailure("Failed to make paused setup preview trip: \(error)")
        }
    }()

    static let airplaneSetup: Trip = {
        do {
            let now = phaseClockNow
            var trip = reference
            try trip.updateLeg(id: ReferenceTripIdentity.tokyoKyoto) { leg in
                leg.scheduledAt = try Slot.confirmed(
                    value: try ScheduledMoment(
                        date: LocalDate(year: 2026, month: 10, day: 1),
                        timeZoneIdentifier: "Asia/Tokyo"
                    ),
                    source: .userStated,
                    updatedAt: now
                )
                leg.transportMode = try Slot.confirmed(value: .airplane, source: .userStated, updatedAt: now)
            }
            return trip
        } catch {
            preconditionFailure("Failed to make airplane setup preview trip: \(error)")
        }
    }()

    static let withBags: Trip = {
        do {
            var trip = readyForNow
            if trip.baggageInventory.isEmpty {
                trip.baggageInventory = [
                    Bag(
                        id: BagID(),
                        kind: try Slot.confirmed(value: .suitcase, source: .userStated, updatedAt: phaseClockNow),
                        userDescription: try Slot.unknown(updatedAt: phaseClockNow),
                        perceivedSize: try Slot.unknown(updatedAt: phaseClockNow),
                        dimensions: try Slot.unknown(updatedAt: phaseClockNow),
                        weightKilograms: try Slot.unknown(updatedAt: phaseClockNow),
                        createdAt: phaseClockNow
                    ),
                ]
            }
            return trip
        } catch {
            preconditionFailure("Failed to make bags preview: \(error)")
        }
    }()

    static let multiDayNow: Date = {
        do {
            guard let value = try LocalDate(year: 2026, month: 10, day: 2)
                .date(in: TripPhaseResolver.calendarTimeZone)
            else {
                preconditionFailure("Failed to make multi-day now")
            }
            return value
        } catch {
            preconditionFailure("Failed to make multi-day now: \(error)")
        }
    }()

    static let multiDayEmptyDayNow: Date = {
        do {
            guard let value = try LocalDate(year: 2026, month: 10, day: 3)
                .date(in: TripPhaseResolver.calendarTimeZone)
            else {
                preconditionFailure("Failed to make empty-day now")
            }
            return value
        } catch {
            preconditionFailure("Failed to make empty-day now: \(error)")
        }
    }()

    static let multiDay: Trip = {
        do {
            return try makeMultiDayTrip()
        } catch {
            preconditionFailure("Failed to make multi-day preview trip: \(error)")
        }
    }()

    static let multiDayInTrip: Trip = {
        do {
            var trip = try makeMultiDayTrip()
            trip.currentContext.tripPhase = .inTrip
            return trip
        } catch {
            preconditionFailure("Failed to make in-trip multi-day preview: \(error)")
        }
    }()

    private static func makeMultiDayTrip() throws -> Trip {
        let now = phaseClockNow
        let timeZone = "Asia/Tokyo"
        var trip = try EmptyTripFactory.make(
            name: "Japan trip",
            startDate: try LocalDate(year: 2026, month: 10, day: 1),
            endDate: try LocalDate(year: 2026, month: 10, day: 8),
            now: now
        )
        let oct1 = try LocalDate(year: 2026, month: 10, day: 1)
        let oct2 = try LocalDate(year: 2026, month: 10, day: 2)
        let morning = try ScheduledMoment(
            date: oct1,
            time: try LocalTime(hour: 10, minute: 3),
            timeZoneIdentifier: timeZone
        )
        let checkIn = try ScheduledMoment(
            date: oct2,
            time: try LocalTime(hour: 16, minute: 0),
            timeZoneIdentifier: timeZone
        )
        var datedLeg = try ItineraryItemFactory.makeLeg(
            origin: "Tokyo",
            destination: "Kyoto",
            scheduledAt: morning,
            at: now
        )
        datedLeg.transportMode = try Slot.confirmed(value: .shinkansen, source: .userStated, updatedAt: now)
        let temple = try ItineraryItemFactory.makeActivity(
            title: "Kinkaku-ji",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(date: oct1, timeZoneIdentifier: timeZone),
            at: now
        )
        let stay = try ItineraryItemFactory.makeStay(place: "Kyoto Hotel", checkIn: checkIn, at: now)
        let sightseeing = try ItineraryItemFactory.makeActivity(
            title: "Kyoto sightseeing",
            place: "Kyoto",
            scheduledAt: try ScheduledMoment(date: oct2, timeZoneIdentifier: timeZone),
            at: now
        )
        let unscheduled = try ItineraryItemFactory.makeActivity(title: "Souvenir shopping", place: "Osaka", at: now)
        trip = try TripMutationApplier.apply(.addLeg(datedLeg, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(temple, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addStay(stay, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(sightseeing, atTimelineIndex: nil), to: trip, at: now)
        trip = try TripMutationApplier.apply(.addActivity(unscheduled, atTimelineIndex: nil), to: trip, at: now)
        trip.currentContext.focus = .leg(datedLeg.id)
        try trip.validate()
        return trip
    }

    private static func dated(_ base: Trip, startOffset: Int, endOffset: Int, phase: TripPhase) -> Trip {
        do {
            var trip = base
            let today = try LocalDate(date: phaseClockNow, timeZone: TripPhaseResolver.calendarTimeZone)
            trip.startDate = try Slot.confirmed(
                value: shifted(today, by: startOffset),
                source: .userStated,
                updatedAt: phaseClockNow
            )
            trip.endDate = try Slot.confirmed(
                value: shifted(today, by: endOffset),
                source: .userStated,
                updatedAt: phaseClockNow
            )
            trip.currentContext.tripPhase = phase
            return trip
        } catch {
            preconditionFailure("Failed to date preview trip: \(error)")
        }
    }

    private static func shifted(_ date: LocalDate, by days: Int) throws -> LocalDate {
        let utc = TimeZone(secondsFromGMT: 0)!
        guard let value = date.date(in: utc),
              let moved = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: value)
        else {
            return date
        }
        return try LocalDate(date: moved, timeZone: utc)
    }
}
#endif
