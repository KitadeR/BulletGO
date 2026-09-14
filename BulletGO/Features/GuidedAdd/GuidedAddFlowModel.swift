import Foundation
import Observation

@MainActor
@Observable
final class GuidedAddFlowModel {
    let tripID: TripID
    let kind: ItineraryAddKind
    let timeZoneIdentifier: String
    let steps: [GuidedAddStep]
    var draft: GuidedAddDraft
    var stepIndex: Int = 0
    var isSaving = false
    var saveFailed = false
    var showDiscardConfirmation = false

    init(tripID: TripID, kind: ItineraryAddKind, initialDate: LocalDate?, now: Date, seedPlace: PlaceReference? = nil) {
        self.tripID = tripID
        self.kind = kind
        self.timeZoneIdentifier = TripCalendar.timeZoneIdentifier
        self.steps = GuidedAddComposer.steps(for: kind)
        self.draft = GuidedAddComposer.seedDraft(kind: kind, initialDate: initialDate, now: now, seedPlace: seedPlace)
    }

    var currentStep: GuidedAddStep { steps[stepIndex] }
    var isFirstStep: Bool { stepIndex == 0 }
    var isReview: Bool { currentStep.isReview }
    var canAdvance: Bool { validate(currentStep) }

    var isDirty: Bool {
        switch draft {
        case .activity(let value):
            !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !value.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .travel(let value):
            !value.origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !value.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || value.mode != nil
        case .stay(let value):
            !value.place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func advance() {
        guard canAdvance, stepIndex < steps.count - 1 else { return }
        stepIndex += 1
    }

    func back() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
    }

    func skipOptional() {
        switch currentStep {
        case .travelMode:
            if case .travel(var value) = draft {
                value.skipMode = true
                value.mode = nil
                draft = .travel(value)
            }
            advance()
        case .activityTiming:
            if case .activity(var value) = draft {
                value.timing = .none
                draft = .activity(value)
            }
            advance()
        case .stayCheckIn:
            if case .stay(var value) = draft {
                value.hasCheckIn = false
                value.hasCheckOut = false
                draft = .stay(value)
            }
            advance()
        case .stayCheckOut:
            if case .stay(var value) = draft {
                value.hasCheckOut = false
                draft = .stay(value)
            }
            advance()
        default:
            break
        }
    }

    func commit(session: TripSessionModel) async -> Bool {
        guard session.trip?.id == tripID else { return false }
        isSaving = true
        saveFailed = false
        defer { isSaving = false }
        do {
            let mutations = try makeMutations(now: session.now)
            let result = await session.process(.applyMutations(mutations))
            if result == nil {
                saveFailed = true
                return false
            }
            return true
        } catch {
            saveFailed = true
            return false
        }
    }

    func validate(_ step: GuidedAddStep) -> Bool {
        switch (step, draft) {
        case (.activityWhat, .activity(let value)):
            return !trimmed(value.title).isEmpty || !trimmed(value.place).isEmpty
        case (.activityDate, .activity):
            return true
        case (.activityTiming, .activity(let value)):
            return value.timing != .range || value.endTime >= value.startTime
        case (.activityReview, .activity(let value)):
            return !trimmed(value.title).isEmpty || !trimmed(value.place).isEmpty
        case (.travelOrigin, .travel(let value)):
            return !trimmed(value.origin).isEmpty
        case (.travelDestination, .travel(let value)):
            return !trimmed(value.destination).isEmpty
        case (.travelMode, .travel):
            return true
        case (.travelSchedule, .travel):
            return true
        case (.travelReview, .travel(let value)):
            return !trimmed(value.origin).isEmpty && !trimmed(value.destination).isEmpty
        case (.stayPlace, .stay(let value)):
            return !trimmed(value.place).isEmpty
        case (.stayCheckIn, .stay):
            return true
        case (.stayCheckOut, .stay(let value)):
            if value.hasCheckIn, value.hasCheckOut {
                return value.checkOut >= value.checkIn
            }
            return true
        case (.stayReview, .stay(let value)):
            return !trimmed(value.place).isEmpty
        default:
            return false
        }
    }

    func makeMutations(now: Date) throws -> [TripMutation] {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        switch draft {
        case .activity(let value):
            let title = trimmed(value.title).isEmpty ? trimmed(value.place) : trimmed(value.title)
            let place = trimmed(value.place).isEmpty ? title : trimmed(value.place)
            let scheduled = try activityMoment(value, timeZone: timeZone)
            var activity = try ItineraryItemFactory.makeActivity(
                title: title,
                place: place,
                scheduledAt: scheduled,
                at: now
            )
            activity.placeReference = value.placeReference
            if value.timing == .range {
                let endDate = value.hasDate ? try ScheduledMomentComposer.localDate(from: value.date, timeZone: timeZone) : nil
                let endTime = try ScheduledMomentComposer.localTime(from: value.endTime, timeZone: timeZone)
                activity.endsAt = try Slot.confirmed(
                    value: try ScheduledMomentComposer.start(date: endDate, time: endTime),
                    source: .userStated,
                    updatedAt: now
                )
            }
            return [.addActivity(activity, atTimelineIndex: nil)]
        case .travel(let value):
            let scheduled = value.hasDate
                ? try composeMoment(
                    datePicker: value.date,
                    timePicker: value.hasDepartureTime ? value.departureTime : nil,
                    includeTime: value.hasDepartureTime,
                    timeZone: timeZone
                )
                : nil
            var leg = try ItineraryItemFactory.makeLeg(
                origin: trimmed(value.origin),
                destination: trimmed(value.destination),
                scheduledAt: scheduled,
                at: now
            )
            leg.originPlace = value.originPlace
            leg.destinationPlace = value.destinationPlace
            var mutations: [TripMutation] = [.addLeg(leg, atTimelineIndex: nil)]
            if let mode = value.mode, !value.skipMode {
                mutations.append(.setTransportMode(leg.id, mode))
            }
            if value.hasArrivalTime {
                mutations.append(.updateLegArrivesAt(leg.id, try composeMoment(
                    datePicker: value.hasDate ? value.date : value.arrivalTime,
                    timePicker: value.arrivalTime,
                    includeTime: true,
                    includeDate: value.hasDate,
                    timeZone: timeZone
                )))
            }
            return mutations
        case .stay(let value):
            let checkIn = value.hasCheckIn ? try composeMoment(datePicker: value.checkIn, timePicker: nil, includeTime: false, timeZone: timeZone) : nil
            let checkOut = value.hasCheckOut ? try composeMoment(datePicker: value.checkOut, timePicker: nil, includeTime: false, timeZone: timeZone) : nil
            var stay = try ItineraryItemFactory.makeStay(
                place: trimmed(value.place),
                checkIn: checkIn,
                checkOut: checkOut,
                at: now
            )
            stay.placeReference = value.placeReference
            return [.addStay(stay, atTimelineIndex: nil)]
        }
    }

    private func activityMoment(_ value: ActivityAddDraft, timeZone: TimeZone) throws -> ScheduledMoment? {
        let localDate = value.hasDate ? try ScheduledMomentComposer.localDate(from: value.date, timeZone: timeZone) : nil
        switch value.timing {
        case .none:
            guard let localDate else { return nil }
            return try ScheduledMomentComposer.dateOnly(date: localDate, timeZoneIdentifier: timeZone.identifier)
        case .allDay:
            return try ScheduledMomentComposer.allDay(date: localDate, timeZoneIdentifier: timeZone.identifier)
        case .start, .range:
            let time = try ScheduledMomentComposer.localTime(from: value.startTime, timeZone: timeZone)
            return try ScheduledMomentComposer.start(date: localDate, time: time, timeZoneIdentifier: timeZone.identifier)
        }
    }

    private func composeMoment(
        datePicker: Date,
        timePicker: Date?,
        includeTime: Bool,
        includeDate: Bool = true,
        timeZone: TimeZone
    ) throws -> ScheduledMoment {
        let localDate = includeDate ? try ScheduledMomentComposer.localDate(from: datePicker, timeZone: timeZone) : nil
        if includeTime {
            let time = try ScheduledMomentComposer.localTime(from: timePicker ?? datePicker, timeZone: timeZone)
            return try ScheduledMomentComposer.start(date: localDate, time: time, timeZoneIdentifier: timeZone.identifier)
        }
        guard let localDate else {
            throw DomainError.invalidScheduledMoment
        }
        return try ScheduledMomentComposer.dateOnly(date: localDate, timeZoneIdentifier: timeZone.identifier)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
