import BinaryCoder
import Foundation
import JLog

public struct SMAPacket: Encodable, Decodable
{
    var smaprefix: UInt32
    var group: UInt32?
    var systemid: UInt16?
    var serialnumber: UInt32?
    var currenttimems: UInt32?

    var obisPackets: [ObisPacket]
    var smaNetPackets: [SMANetPacket]

    public var obis: [ObisValue] { obisPackets.first?.obisvalues ?? [] }
}

enum SMAPacketType: UInt16
{
    case obisPacket = 0x6069
    case netPacket = 0x6065
}

extension SMAPacket: BinaryDecodable
{
    enum SMAPacketError: Swift.Error
    {
        case notaSMAPacket(String)
        case prematureEndOfSMAContentData(String)
    }

    public init(data: Data) throws
    {
        let byteArray = [UInt8](data)
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(SMAPacket.self)
    }

    public init(byteArray: [UInt8]) throws
    {
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(SMAPacket.self)
    }

    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.debug("")

        obisPackets = [ObisPacket]()
        smaNetPackets = [SMANetPacket]()

        do { smaprefix = try decoder.decode(UInt32.self).bigEndian }
        catch { throw SMAPacketError.prematureEndOfSMAContentData("not long enough for SMA\\0 header") }

        guard smaprefix == 0x534D_4100 // == 'SMA\0'
        else { throw SMAPacketError.notaSMAPacket("packet not sma packet - does not start with SMA\\0") }

        JLog.debug("Valid SMA Prefix")

        var endPacketRead = false

        repeat
        {
            let smaTagPacket = try SMATagPacket(fromBinary: decoder)
            let smaNetDecoder = BinaryDecoder(data: [UInt8](smaTagPacket.data))

            switch smaTagPacket.type
            {
                case .end: endPacketRead = true

                case .group:
                    JLog.trace("tag0 :\(smaTagPacket)")
                    let groupnumber = try smaNetDecoder.decode(UInt32.self).bigEndian
                    JLog.trace("\(String(format: "groupnumber : 0x%08x d:%d", groupnumber, groupnumber))")
                    group = groupnumber

                case .net:
                    if let protocolid = try? smaNetDecoder.decode(UInt16.self).bigEndian,
                       let packetType = SMAPacketType(rawValue: protocolid)
                    {
                        JLog.debug("got packetType:\(packetType)")

                        switch packetType
                        {
                            case .obisPacket:
                                JLog.debug("recognizing ObisPacket")

                                let obisPacket = try ObisPacket(fromBinary: smaNetDecoder)
                                obisPackets.append(obisPacket)

                            case .netPacket:
                                JLog.debug("recognizing SMANetPacket")

                                let smaNetPacket = try SMANetPacket(fromBinary: smaNetDecoder)
                                smaNetPackets.append(smaNetPacket)
                        }
                    }
                    else
                    {
                        JLog.error("Could not decode protocolid of smaTagType:\(smaTagPacket.type) length:\(smaTagPacket.data.count) data:\(smaTagPacket.data.hexDump)")
                    }

                case .unknown:
                    JLog.warning("smaTagPacketType unknown:\(smaTagPacket.tag) length:\(smaTagPacket.data.count) data:\(smaTagPacket.data.hexDump)")
            }
        }
        while !decoder.isAtEnd && !endPacketRead

        JLog.trace("\npayload:\(json)")
    }
}
