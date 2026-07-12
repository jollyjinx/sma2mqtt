//
//  MQTTPublicationGateTests.swift
//

import Foundation
@testable import sma2mqttLibrary
import Testing

struct MQTTPublicationGateTests
{
    private let topic = "inverter/ac-power"
    private let initialDate = Date(timeIntervalSinceReferenceDate: 1000)

    @Test
    func initialValuePublishes()
    {
        let gate = MQTTPublicationGate()

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: false,
                                   at: initialDate,
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15))
    }

    @Test
    func changedValuePublishesAfterMinimumEmitInterval()
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "101",
                                   retained: false,
                                   at: date(secondsAfterInitial: 1.001),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15))
    }

    @Test
    func changedValueInsideMinimumEmitIntervalIsSkipped()
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "101",
                                   retained: false,
                                   at: date(secondsAfterInitial: 1),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15) == false)
    }

    @Test
    func unchangedValueBeforeHeartbeatIsSkipped()
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: false,
                                   at: date(secondsAfterInitial: 14.999),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15) == false)
    }

    @Test(arguments: [15.0, 16.0])
    func unchangedValueAtOrAfterHeartbeatPublishes(elapsed: TimeInterval)
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: false,
                                   at: date(secondsAfterInitial: elapsed),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15))
    }

    @Test
    func retainedUnchangedValueIsSuppressed()
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: true,
                                   at: date(secondsAfterInitial: 60),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15) == false)
    }

    @Test
    func zeroHeartbeatIntervalPreservesEmitIntervalBehavior()
    {
        let gate = recordedGate(payload: "100")

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: false,
                                   at: date(secondsAfterInitial: 1.001),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 0))
    }

    @Test
    func recordingHeartbeatRestartsInterval()
    {
        var gate = recordedGate(payload: "100")
        gate.recordPublication(topic: topic,
                               payload: "100",
                               at: date(secondsAfterInitial: 15))

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: false,
                                   at: date(secondsAfterInitial: 29.999),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15) == false)
    }

    @Test
    func resetForcesRetainedValueToPublishAgain()
    {
        var gate = recordedGate(payload: "100")
        gate.reset()

        #expect(gate.shouldPublish(topic: topic,
                                   payload: "100",
                                   retained: true,
                                   at: date(secondsAfterInitial: 1),
                                   minimumEmitInterval: 1,
                                   unchangedPublishInterval: 15))
    }

    private func recordedGate(payload: String) -> MQTTPublicationGate
    {
        var gate = MQTTPublicationGate()
        gate.recordPublication(topic: topic, payload: payload, at: initialDate)
        return gate
    }

    private func date(secondsAfterInitial seconds: TimeInterval) -> Date
    {
        initialDate.addingTimeInterval(seconds)
    }
}
