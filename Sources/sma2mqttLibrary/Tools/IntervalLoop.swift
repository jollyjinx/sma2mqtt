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

        let timeToWait = nextWorkDate.timeIntervalSinceNow

        if timeToWait > 0
        {
            try await Task.sleep(for: .seconds(timeToWait))
        }
        lastWorkDate = Date()
    }
}
