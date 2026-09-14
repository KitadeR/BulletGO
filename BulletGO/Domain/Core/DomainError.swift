import Foundation

nonisolated enum DomainError: Error, Equatable, Sendable {
    case invalidDate(year: Int, month: Int, day: Int)
    case invalidTime(hour: Int, minute: Int, second: Int)
    case invalidTimeZone(String)
    case invalidScheduledMoment
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
    case invertedItemSchedule
    case invalidCoordinate
    case itemsOutsideDateRange([TripTimelineItem])
    case orphanScopedNote(NoteID)
    case orphanScopedAttachment(AttachmentID)
    case orphanTaskScope(TaskID)
    case orphanReadinessScope(ReadinessCheckID)
    case orphanConnectorEstimate
    case duplicateNoteIDs
    case duplicateAttachmentIDs
    case duplicateSavedPlaceIDs
    case duplicateConnectorEstimates
}
