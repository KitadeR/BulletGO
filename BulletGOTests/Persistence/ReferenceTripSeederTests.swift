import Foundation
import Testing
@testable import BulletGO

@MainActor
struct ReferenceTripSeederTests {
    private let timestamp = DomainTestSupport.timestamp

    @Test func seedsThreeLegsAndThreeActivitiesOnce() async throws {
        let stack = try PersistenceStack.inMemory()
        let seeder = ReferenceTripSeeder(factory: ReferenceTripFactory(now: { timestamp }))

        try await seeder.seedIfNeeded(using: stack.repository)
        try await seeder.seedIfNeeded(using: stack.repository)

        let trips = try await stack.repository.fetchAll()
        #expect(trips.count == 1)
        let trip = try #require(trips.first)
        #expect(trip.id == ReferenceTripIdentity.trip)
        #expect(trip.createdAt == timestamp)
        #expect(trip.legs.map(\.origin.value) == ["Tokyo", "Kyoto", "Osaka"])
        #expect(trip.legs.map(\.destination.value) == ["Kyoto", "Osaka", "Hakata"])
        #expect(trip.activities.map(\.title.value) == ["Kinkaku-ji", "Dotonbori", "Hakata sightseeing"])
        #expect(trip.timeline == [
            .leg(ReferenceTripIdentity.tokyoKyoto),
            .activity(ReferenceTripIdentity.kinkakuji),
            .leg(ReferenceTripIdentity.kyotoOsaka),
            .activity(ReferenceTripIdentity.dotonbori),
            .leg(ReferenceTripIdentity.osakaHakata),
            .activity(ReferenceTripIdentity.hakataSightseeing),
        ])
        #expect(trip.currentContext.focus == .leg(ReferenceTripIdentity.tokyoKyoto))
        let openingDate = try LocalDate(year: 2026, month: 10, day: 1)
        let openingTime = try LocalTime(hour: 10, minute: 0)
        #expect(trip.legs[0].scheduledAt.status == .confirmed)
        #expect(trip.legs[0].scheduledAt.value?.date == openingDate)
        #expect(trip.legs[0].scheduledAt.value?.time == openingTime)
        #expect(trip.legs[1].scheduledAt.status == .unknown)
        #expect(trip.legs[2].scheduledAt.status == .unknown)
        #expect(trip.activities.allSatisfy { $0.scheduledAt.status == .unknown })
        #expect(trip.legs[0].transportMode.status == .unknown)
        #expect(trip.legs[0].transportMode.value == nil)
        #expect(trip.traveler.preferredLanguage.value == "en")
        #expect(trip.tasks.isEmpty)
        #expect(trip.baggageInventory.isEmpty)
        #expect(trip.readinessChecks.isEmpty)
        #expect(trip.changeEvents.isEmpty)
    }

    @Test func placesAnAlreadyInstalledUnscheduledOpeningLegOnTheFirstMorning() async throws {
        let stack = try PersistenceStack.inMemory()
        let seeder = ReferenceTripSeeder(factory: ReferenceTripFactory(now: { timestamp }))
        try await seeder.seedIfNeeded(using: stack.repository)

        var trip = try #require(try await stack.repository.fetch(id: ReferenceTripIdentity.trip))
        trip.legs[0].scheduledAt = try Slot.unknown(updatedAt: timestamp)
        try await stack.repository.save(trip)

        try await seeder.placeOpeningLegIfStillUnscheduled(using: stack.repository)

        let loaded = try #require(try await stack.repository.fetch(id: ReferenceTripIdentity.trip))
        let openingDate = try LocalDate(year: 2026, month: 10, day: 1)
        let openingTime = try LocalTime(hour: 10, minute: 0)
        #expect(loaded.legs[0].scheduledAt.status == .confirmed)
        #expect(loaded.legs[0].scheduledAt.value?.date == openingDate)
        #expect(loaded.legs[0].scheduledAt.value?.time == openingTime)
        #expect(loaded.legs[1].scheduledAt.status == .unknown)
        #expect(loaded.legs[2].scheduledAt.status == .unknown)
        #expect(loaded.legs[0].transportMode.status == .unknown)
    }

    @Test func leavesAChosenOpeningDateAlone() async throws {
        let stack = try PersistenceStack.inMemory()
        let seeder = ReferenceTripSeeder(factory: ReferenceTripFactory(now: { timestamp }))
        try await seeder.seedIfNeeded(using: stack.repository)

        var trip = try #require(try await stack.repository.fetch(id: ReferenceTripIdentity.trip))
        let chosen = try ScheduledMoment(
            date: LocalDate(year: 2026, month: 10, day: 3),
            timeZoneIdentifier: TripCalendar.timeZoneIdentifier
        )
        trip.legs[0].scheduledAt = try Slot.confirmed(
            value: chosen,
            source: .userStated,
            updatedAt: timestamp
        )
        try await stack.repository.save(trip)

        try await seeder.placeOpeningLegIfStillUnscheduled(using: stack.repository)

        let loaded = try #require(try await stack.repository.fetch(id: ReferenceTripIdentity.trip))
        #expect(loaded.legs[0].scheduledAt.value == chosen)
    }

    @Test func doesNotOverwriteAnExistingUserTrip() async throws {
        let stack = try PersistenceStack.inMemory()
        let seeder = ReferenceTripSeeder(factory: ReferenceTripFactory(now: { timestamp }))
        let userTrip = try DomainTestSupport.sampleTrip()

        try await stack.repository.save(userTrip)
        try await seeder.seedIfNeeded(using: stack.repository)

        let trips = try await stack.repository.fetchAll()
        #expect(trips.count == 2)
        let loadedUserTrip = try #require(trips.first { $0.id == userTrip.id })
        #expect(loadedUserTrip == userTrip)
    }

    @Test func doesNotResurrectADeletedReferenceTrip() async throws {
        let stack = try PersistenceStack.inMemory()
        let seeder = ReferenceTripSeeder(factory: ReferenceTripFactory(now: { timestamp }))

        try await seeder.seedIfNeeded(using: stack.repository)
        try await stack.repository.delete(id: ReferenceTripIdentity.trip)
        try await seeder.seedIfNeeded(using: stack.repository)

        #expect(try await stack.repository.fetchAll().isEmpty)
        #expect(try await stack.repository.fetch(id: ReferenceTripIdentity.trip) == nil)
    }
}
