//
//  SMATagPacket.swift
//

import BinaryCoder
import Foundation
import JLog

public struct SMATagPacket: Codable, Sendable
{
    let tag: UInt16
    let data: Data

    private var _group: UInt32? = nil
    private var _netPacket: SMANetPacket? = nil
    private var _obisPacket: ObisPacket? = nil
    private var _ipaddress: String? = nil
}

extension SMATagPacket
{
    public enum TagType: UInt16
    {
        case end = 0x0000
        case net = 0x0010 // sma net v2
        case ipaddress = 0x0030
        case discovery = 0x0200
        case group = 0x02A0 // tag 0x02a == 42, version 0x0
        case unknown = 0xFFFF
    }

    var type: TagType { TagType(rawValue: tag) ?? .unknown }
}

enum SMATagPacketNetSubtype: UInt16
{
    case emeterPacket = 0x6069 // Energy Meter Protocol
    case netPacket = 0x6065 // SMANet Plus Packet
    case extendedEmeterPacket = 0x6081 // Extended Energy Meter Protocol
}

extension SMATagPacket: BinaryCodable
{
    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.trace("")

        do
        {
            let length = try decoder.decode(UInt16.self).bigEndian
            tag = try decoder.decode(UInt16.self).bigEndian
            data = try decoder.decode(Data.self, length: Int(length))

            let tagType = TagType(rawValue: tag) ?? .unknown
            JLog.trace("retrieved: \(tagType) \(String(format: "0x%04x", tag)) length:\(length)")

            switch tagType
            {
                case .group:
                    let groupDecoder = BinaryDecoder(data: [UInt8](data))
                    _group = try groupDecoder.decode(UInt32.self).bigEndian
                    guard groupDecoder.isAtEnd else { throw PacketError.notExpectedPacket("SMATagPacket type:\(tagType) too long") }
                    JLog.trace("\(String(format: "groupnumber : 0x%08x d:%d", _group!, _group!))")

                case .net:
                    let netpacketDecoder = BinaryDecoder(data: [UInt8](data))
                    let protocolid = try netpacketDecoder.decode(UInt16.self).bigEndian

                    if let packetType = SMATagPacketNetSubtype(rawValue: protocolid)
                    {
                        JLog.trace("got SMATagPacketNetSubtype:\(packetType)")

                        switch packetType
                        {
                            case .emeterPacket:
                                _obisPacket = try ObisPacket(fromBinary: netpacketDecoder)

                            case .netPacket:
                                _netPacket = try SMANetPacket(fromBinary: netpacketDecoder)

                            case .extendedEmeterPacket:
                                JLog.info("Got packetype:\(packetType) - ignoring")
                                let _ = try netpacketDecoder.decode(Data.self, length: data.count - 2)
                        }
                        guard netpacketDecoder.isAtEnd else { throw PacketError.notExpectedPacket("SMATagPacket type:\(tagType) too long") }
                    }
                    else
                    {
                        JLog.debug("ignoring SMATagPacketNetSubtype:\(String(format: "0x%04x", protocolid))")
                    }

                case .ipaddress:
                    let ipaddress = [UInt8](data)
                    guard ipaddress.count == 4 else { throw PacketError.notExpectedPacket("SMATagPacket type:\(tagType) weird data:\(ipaddress)") }
                    _ipaddress = ipaddress.map { String($0) }.joined(separator: ".")

                default:
                    break
            }
        }
        catch
        {
            throw PacketError.prematureEndOfData("SMATagPacket")
        }
    }
}

public extension SMATagPacket
{
    var isLastPacket: Bool { type == .end && data == Data(capacity: 4) }

    var obisvalues: [ObisValue] { _obisPacket?.obisvalues ?? [ObisValue]() }
    var netPacket: SMANetPacket? { _netPacket }
    var netPacketValues: [SMANetPacketValue] { _netPacket?.values ?? [SMANetPacketValue]() }
}
