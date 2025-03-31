//
//  TestHelpers.swift
//

import XCTest

import class Foundation.Bundle

@testable import BinaryCoder
@testable import JLog
@testable import sma2mqttLibrary

struct DataSplitter: Sequence, IteratorProtocol
{
    let data: Data
    var index: Data.Index
    let splitData: Data

    init(data: Data, splitData: Data)
    {
        self.data = data
        self.splitData = splitData
        index = data.startIndex
        JLog.debug("init")
    }

    mutating func next() -> Data?
    {
        guard index != data.endIndex else { return nil }

        guard let range = data[index ..< data.endIndex].range(of: splitData)
        else
        {
            if index == data.startIndex
            {
                index = data.endIndex
                return nil
            }

            let returnData = data[(index - splitData.count) ..< data.endIndex]
            index = data.endIndex
            return returnData
        }
        if index == data.startIndex
        {
            index = range.endIndex
            return next()
        }

        let returnData = data[(index - splitData.count) ..< range.startIndex]
        index = range.endIndex

        return returnData
    }
}

extension Data
{
    func split(separator: Data) -> [Data]
    {
        var chunks: [Data] = []
        var pos = startIndex
        // Find next occurrence of separator after current position:
        while let matchedRange = self[pos...].range(of: separator)
        {
            // Append if non-empty:
            if matchedRange.lowerBound > pos
            {
                chunks.append(self[(pos - separator.count) ..< matchedRange.lowerBound])
            }
            // Update current position:
            pos = matchedRange.upperBound
        }
        // Append final chunk, if non-empty:
        if pos < endIndex
        {
            chunks.append(self[pos ..< endIndex])
        }
        return chunks
    }
}

extension ProcessInfo
{
    func value(forArgument matchingArgument: String) -> String?
    {
        var previousMatched = false

        for argument in arguments
        {
            if previousMatched
            {
                return argument
            }
            if argument == matchingArgument
            {
                previousMatched = true
            }
        }
        return nil
    }
}
