//
//  Extensions.swift
//

import Foundation

public extension UInt32 { var ipv4String: String { "\(self >> 24).\(self >> 16 & 0xFF).\(self >> 8 & 0xFF).\(self & 0xFF)" } }

#if os(Linux)
    public let NSEC_PER_SEC: Int64 = 1_000_000_000
#endif

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
        var string = ""

        for (offset, value) in enumerated()
        {
            string += String(format: "%02x", value)
            if (offset + 1) % 2 == 0 { string += " " }
        }
        return string
    }

    func toHexString(octetGrouped: Bool = false) -> String
    {
        let formatString = octetGrouped ? "%02hhx " : "%02hhx"
        let string = map { String(format: formatString, $0) }.joined()
        return string
    }
}

extension String
{
    func hexStringToData() -> Data
    {
        let stringWithoutSpaces = replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")

        let uInt8Array = stride(from: 0, to: stringWithoutSpaces.count, by: 2)
            .map
            {
                stringWithoutSpaces[
                    stringWithoutSpaces.index(stringWithoutSpaces.startIndex, offsetBy: $0) ... stringWithoutSpaces.index(stringWithoutSpaces.startIndex, offsetBy: $0 + 1)
                ]
            }
            .map { UInt8($0, radix: 16)! }
        return Data(uInt8Array)
    }
}

public extension Encodable
{
    var json: String
    {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.sortedKeys]
        let jsonData = try? jsonEncoder.encode(self)
        return jsonData != nil ? String(data: jsonData!, encoding: .utf8) ?? "" : ""
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
