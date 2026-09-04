import Foundation
import Testing
@testable import BulletGO

struct ProcedureCatalogTests {
    @Test func productionProcedureLoadsWithHTTPSSourceAndInputStep() throws {
        let procedure = try ProcedureCatalog.loadProduction(from: .main)
        #expect(procedure.id == .shinkansenBaggageMeasurement)
        #expect(procedure.taskContentKey == ActionPurpose.captureDimensions)
        #expect(procedure.sourceURL.scheme == "https")
        #expect(procedure.steps.contains(where: { $0.kind == .dimensionInput }))
        #expect(procedure.illustrationKind == .includeWheelsAndHandles)
    }

    @Test func captureDimensionsTaskGetsTheMeasurementProcedure() throws {
        let pack = try EngineTestSupport.pack()
        var trip = try PolicyScenarioSupport.trip(
            reservation: .notBooked,
            baggagePresence: .yes,
            bags: [(PolicyScenarioSupport.bagA, nil)]
        )
        trip = try ShinkansenBaggageRuleEngine.evaluate(trip, pack: pack, at: EngineTestSupport.now)
        let actions = ActionResolver.resolve(trip: trip, pack: pack)
        let tasks = try TripTaskGenerator.generate(actions: actions, trip: trip, pack: pack)
        let capture = try #require(tasks.first { $0.contentKey == ActionPurpose.captureDimensions })
        #expect(capture.relatedGuideID == .shinkansenBaggageMeasurement)
    }

    @Test func primaryNowOpensTheBaggageGuideWhenTheProcedureIsAttached() throws {
        var trip = try DomainTestSupport.sampleTrip()
        let focus = trip.legs[0].id
        let task = TripTask(
            id: TaskID(),
            contentKey: ActionPurpose.captureDimensions,
            type: .check,
            state: .notStarted,
            importance: .required,
            relevantPhases: [.planning, .booking],
            deadline: nil,
            dependencies: [],
            evidence: .none,
            scope: .leg(focus),
            relatedActionID: nil,
            relatedPolicyID: .jrShinkansenOversizedBaggage,
            relatedGuideID: .shinkansenBaggageMeasurement,
            completionCondition: .userConfirmsDone
        )
        trip.tasks = [task]
        trip.legs[0].phase = .booking
        let catalog = try EngineTestSupport.catalog()
        trip.legs[0].scheduledAt = try Slot.confirmed(
            value: EngineTestSupport.moment(try LocalDate(year: 2026, month: 10, day: 1)),
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.legs[0].transportMode = try Slot.confirmed(
            value: .shinkansen,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.legs[0].reservation.status = try Slot.confirmed(
            value: .notBooked,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        trip.legs[0].baggagePresence = try Slot.confirmed(
            value: .yes,
            source: .userStated,
            updatedAt: DomainTestSupport.timestamp
        )
        try trip.validate()
        let primary = HomePrimaryActionComposer.primary(for: trip, catalog: catalog, tripPhase: .inTrip)
        #expect(primary?.destination == .baggageCheck(trip.id, focus, task.id))
    }
}
