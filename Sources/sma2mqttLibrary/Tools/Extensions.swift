//
//  Extensions.swift
//

import Foundation

public extension UInt32 { var ipv4String: String { "\(self >> 24).\(self >> 16 & 0xFF).\(self >> 8 & 0xFF).\(self & 0xFF)" } }

#if os(Linux)
    public let NSEC_PER_SEC: Int64 = 1_000_000_000
    public let USEC_PER_SEC: Int64 = 1_000_000
#endif

public extension Date
{
    func isWithin(_ timeInterval: TimeInterval) -> Bool
    {
        timeIntervalSinceNow > -timeInterval
    }

    var isInFuture: Bool { timeIntervalSinceNow > 0 }
}

extension Task where Success == Never, Failure == Never
{
    static func sleep(seconds: Double) async throws
    {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }

    static func sleep(until date: Date) async throws
    {
        let distance = date.timeIntervalSinceNow

        if distance < 0
        {
            return
        }
        let nanoseconds = UInt64(distance * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

public extension Data
{
    var fullDump: String
    {
        var string: String = hexDump + "\n"

        for (offset, value) in enumerated() { string += String(format: "%04d: 0x%02x %03d c:%c\n", offset, value, value, value > 31 && value < 127 ? value : 32) }
        return string
    }
}

public extension Data
{
    var hexDump: String
    {
        toHexString(octetGrouped: true)
    }

    private static let hexAlphabet = Array("0123456789abcdef".utf8)
    func toHexString(octetGrouped: Bool = false) -> String
    {
        let returnString = String(unsafeUninitializedCapacity: 2 * count)
        { ptr -> Int in
            var p = ptr.baseAddress!
            for byte in self
            {
                p[0] = Self.hexAlphabet[Int(byte / 16)]
                p[1] = Self.hexAlphabet[Int(byte % 16)]
                p += 2
            }
            return 2 * self.count
        }
        if !octetGrouped
        {
            return returnString
        }

        var counter = 0
        return returnString.map { counter += 1; return counter % 4 == 0 ? "\($0) " : "\($0)" }.joined()
    }
}

extension String
{
    static let hex2UInt8: [UInt8: UInt8] = Dictionary(uniqueKeysWithValues: "0123456789abcdefABCDEF".utf8.map { ($0, UInt8(String(format: "%c", $0), radix: 16)!) })

    func hexStringToData() -> Data
    {
        var second = true
        var last: UInt8 = 0
        return Data(utf8.compactMap
        {
            if let nibble = Self.hex2UInt8[$0]
            {
                second.toggle()
                if second
                {
                    return last << 4 | nibble
                }
                last = nibble
            }
            return nil
        }
        )
    }
}

public extension Encodable
{
    var json: String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        jsonEncoder.dateEncodingStrategy = .iso8601
        let jsonData = try? jsonEncoder.encode(self)
        return jsonData != nil ? "\n" + (String(data: jsonData!, encoding: .utf8) ?? "") : ""
    }

    var description: String
    {
        json
    }
}

public extension URL
{
    func byAppendingQueryItems(_ queryItems: [URLQueryItem]) -> URL?
    {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false)
        else
        {
            return nil
        }

        var items: [URLQueryItem] = urlComponents.queryItems ?? []
        items.append(contentsOf: queryItems)

        urlComponents.queryItems = items

        return urlComponents.url
    }
}
