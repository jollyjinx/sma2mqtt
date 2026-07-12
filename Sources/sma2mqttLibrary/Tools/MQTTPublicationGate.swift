//
//  MQTTPublicationGate.swift
//

import Foundation

struct MQTTPublicationGate
{
    private struct Publication
    {
        let payload: String
        let date: Date
    }

    private var publications = [String: Publication]()

    func shouldPublish(topic: String,
                       payload: String,
                       retained: Bool,
                       at date: Date,
                       minimumEmitInterval: TimeInterval,
                       unchangedPublishInterval: TimeInterval) -> Bool
    {
        guard let publication = publications[topic]
        else
        {
            return true
        }

        let elapsed = date.timeIntervalSince(publication.date)
        guard elapsed > minimumEmitInterval
        else
        {
            return false
        }

        if publication.payload != payload
        {
            return true
        }

        if retained
        {
            return false
        }

        if unchangedPublishInterval <= 0
        {
            return true
        }

        return elapsed >= unchangedPublishInterval
    }

    mutating func recordPublication(topic: String, payload: String, at date: Date)
    {
        publications[topic] = Publication(payload: payload, date: date)
    }

    mutating func reset()
    {
        publications.removeAll(keepingCapacity: true)
    }
}
