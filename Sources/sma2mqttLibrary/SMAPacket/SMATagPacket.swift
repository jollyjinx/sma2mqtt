//
//  SMATagPacket.swift
//  
//
//  Created by Patrick Stein on 18.06.23.
//

import Foundation
import JLog
import BinaryCoder

public struct SMATagPacket
{
    let length: UInt16
    let tag: UInt16
    let data: Data

    enum TagType: Int
    {
        case end = 0x0000
        case net = 0x0010
        case group = 0x02A0 // tag 0x02a == 42, version 0x0

        case unknown = 0xFFFF_FFFF
    }

    public init(fromBinary decoder: BinaryDecoder) throws
    {
        length = try decoder.decode(UInt16.self).bigEndian
        tag = try decoder.decode(UInt16.self).bigEndian

        if let type = TagType(rawValue: Int(tag))
        {
            JLog.debug("SMATagPacket tagtype: \(type) \(String(format: "(0x%x == %d)", tag, tag)) length:\(length) )")
        }
        else
        {
            JLog.error("SMATagPacket tagtype:UNKNOWN \(String(format: "0x%x == %d", tag, tag)) length:\(length) )")
        }

        guard Int(length) <= decoder.countToEnd
        else
        {
            throw SMAPacket.SMAPacketError.prematureEndOfSMAContentData("SMATagPacket content too short expected length:\(length) has:\(decoder.countToEnd)")
        }
        data = try decoder.decode(Data.self, length: Int(length))
    }

    var type: TagType { TagType(rawValue: Int(tag)) ?? .unknown }
}

