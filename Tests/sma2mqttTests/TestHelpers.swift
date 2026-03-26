//
//  TestHelpers.swift
//

import Foundation
import JLog
import Testing

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

        while let matchedRange = self[pos...].range(of: separator)
        {
            if matchedRange.lowerBound > pos
            {
                chunks.append(self[(pos - separator.count) ..< matchedRange.lowerBound])
            }

            pos = matchedRange.upperBound
        }

        if pos < endIndex
        {
            chunks.append(self[pos ..< endIndex])
        }
        return chunks
    }
}

extension ProcessInfo
{
    static let defaultPcapFixturePath = "/Users/jolly/Documents/GitHub/sma2mqtt/Temp/Reverseengineering/pcaps/vlan2.20220618-1.pcap"

    var shouldRunIntegrationTests: Bool
    {
        hasArgument("--run-integration-tests") || environment["SMA_INTEGRATION_TESTS"] == "1"
    }

    var pcapFixturePath: String
    {
        value(forArgument: "--pcap-file") ?? Self.defaultPcapFixturePath
    }

    var hasPcapFixture: Bool
    {
        FileManager.default.fileExists(atPath: pcapFixturePath)
    }

    func hasArgument(_ matchingArgument: String) -> Bool
    {
        arguments.contains(matchingArgument)
    }

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
