import BinaryCoder
import Foundation
import JLog

public struct SMAPacket: Codable
{
    enum MagicHeader: UInt32
    {
        case smaprefix = 0x534D_4100 // == 'SMA\0'
    }

    var smaTagPackets: [SMATagPacket]
}

extension SMAPacket: BinaryDecodable
{
    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.trace("")

        let prefix: UInt32
        do
        {
            prefix = try decoder.decode(UInt32.self).bigEndian
        }
        catch { throw PacketError.prematureEndOfData("not long enough for SMA\\0 header") }
        guard prefix == MagicHeader.smaprefix.rawValue
        else { throw PacketError.notExpectedPacket("packet not sma packet - does not start with SMA\\0") }

        JLog.trace("Valid SMAPacket Prefix")

        var endTagRead = false

        var smaTagPackets = [SMATagPacket]()
        repeat
        {
            let smaTagPacket = try SMATagPacket(fromBinary: decoder)

            smaTagPackets.append(smaTagPacket)
            endTagRead = smaTagPacket.isLastPacket
        }
        while !decoder.isAtEnd && !endTagRead

        if decoder.isAtEnd, !endTagRead
        {
            throw PacketError.prematureEndOfData("SMAPacket atEnd but no Endpacket read")
        }
        self.smaTagPackets = smaTagPackets
    }
}

public extension SMAPacket
{
    var obis: [ObisValue] { smaTagPackets.first(where: { $0.type == .net })?.obisvalues ?? [] }
}

//
//    var group: UInt32?
//    var systemid: UInt16?
//    var serialnumber: UInt32?
//    var currenttimems: UInt32?
//
//    var obisPackets: [ObisPacket]
//    var smaNetPackets: [SMANetPacket]
// }

// extension SMAPacket
// {
//    public var obis: [ObisValue] { obisPackets.first?.obisvalues ?? [] }
// }
