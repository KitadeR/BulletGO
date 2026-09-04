import Foundation

nonisolated enum DomainError: Error, Equatable, Sendable {
    case invalidDate(year: Int, month: Int, day: Int)
    case invalidTime(hour: Int, minute: Int, second: Int)
    case invalidTimeZone(String)
    case invalidBaggageDimension
    case invalidSlotCombination(status: SlotStatus, source: SlotSource?, hasValue: Bool)
    case confirmedSlotRequiresNonInferredSource
}

nonisolated enum TripValidationError: Error, Equatable, Sendable {
    case duplicateLegIDs
    case duplicateStayIDs
    case duplicateActivityIDs
    case duplicateBagIDs
    case duplicateTaskIDs
    case duplicateReadinessCheckIDs
    case duplicateChangeEventIDs
    case unresolvedTimelineItem(TripTimelineItem)
    case orphanItineraryItem
    case bagNotInInventory(BagID)
    case currentContextTripMismatch
    case unresolvedCurrentFocus
    case invertedTravelDates
}
