//
//  File.swift
//  File
//
//  Created by Patrick Stein on 07.08.21.
//

import Foundation


public extension UInt32
{
    var ipv4String:String { "\(self>>24).\(self>>16 & 0xFF).\(self>>8 & 0xFF).\(self & 0xFF)" }
}

public extension Data
{
    var fullDump:String
        {
            var string:String = hexDump + "\n"


            for (offset,value) in self.enumerated()
            {
                string += String(format:"%04d: 0x%02x %03d c:%c\n",offset,value,value,(value > 31 && value < 127 ? value : 32) )
            }
            return string
        }
}
public extension Data
{
    var hexDump:String
        {
            var string:String = ""

            for (offset,value) in self.enumerated()
            {
                string += String(format:"%02x",value)
                if (offset+1) % 2 == 0 { string += " " }
            }
            return string
        }
    func toHexString(octetGrouped:Bool = false) -> String
    {
        let formatString = octetGrouped ? "%02hhx " : "%02hhx"
        let string = map { String(format: formatString, $0) }.joined()
        return string
    }
}

extension Encodable
{
    public var json:String
    {
        let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .sortedKeys
        let jsonData = try! jsonEncoder.encode(self)
        return String(data: jsonData, encoding: .utf8)!
    }
}
