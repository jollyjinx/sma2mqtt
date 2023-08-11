//
//  IntervalLoop.swift
//

import Foundation

public class IntervalLoop
{
    public let loopTime: Double
    private var lastWorkDate: Date = .distantPast

    init(loopTime: Double)
    {
        self.loopTime = loopTime
    }

    public func waitForNextIteration() async throws
    {
        let nextWorkDate = lastWorkDate + loopTime

        try await Task.sleep(until: nextWorkDate)

        lastWorkDate = Date()
    }
}
