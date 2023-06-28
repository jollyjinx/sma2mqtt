//
//  File.swift
//
//
//  Created by Patrick Stein on 13.06.22.
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
        self.index = data.startIndex
        JLog.debug("init")
    }

    mutating func next() -> Data?
    {
        guard self.index != self.data.endIndex else { return nil }

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
    func value(forArgument argument: String) -> String?
    {
        var lastTestArgument: String?

        return arguments.compactMap
        {
            guard lastTestArgument == argument
            else
            {
                lastTestArgument = $0
                return nil
            }
            return $0
        }.first
    }
}
