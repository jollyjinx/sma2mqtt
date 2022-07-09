import Foundation
import BinaryCoder
import JLog



public struct SMAPacket:Encodable,Decodable
{
    var smaprefix:UInt32
    var group:UInt32?
    var systemid:UInt16?
    var serialnumber:UInt32?
    var currenttimems:UInt32?

    var obisPackets:[ObisPacket]
    var smaNetPackets:[SMANetPacket]

    public var obis:[ObisValue] { obisPackets.first?.obisvalues ?? []}
}


extension SMAPacket:BinaryDecodable
{
    enum SMAPacketError: Swift.Error {
        case notaSMAPacket(String)
        case prematureEndOfSMAContentData(String)
    }

    public init(data:Data) throws
    {
        let byteArray = [UInt8](data)
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(SMAPacket.self)
    }

    public init(byteArray:[UInt8]) throws
    {
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(SMAPacket.self)
    }

    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.debug("")

        obisPackets = [ObisPacket]()
        smaNetPackets = [SMANetPacket]()

        do
        {
            smaprefix = try decoder.decode(UInt32.self).bigEndian
        }
        catch
        {
            throw SMAPacketError.prematureEndOfSMAContentData("not long enough for SMA\\0 header")
        }

        guard smaprefix == 0x534d4100 // == 'SMA\0'
        else
        {
            throw SMAPacketError.notaSMAPacket("packet not sma packet - does not start with SMA\\0")
        }

        JLog.debug("Valid SMA Prefix")

        var endPacketRead = false

        struct SMATagPacket
        {
            let length:UInt16
            let tag:UInt16
            let data:Data

            enum TagType:Int
            {
                case end        = 0x0000
                case net        = 0x0010
                case group      = 0x02A0
                case unknown    = 0xFFFF_FFFF
            }

            public init(fromBinary decoder: BinaryDecoder) throws
            {
                self.length  = try decoder.decode(UInt16.self).bigEndian
                self.tag     = try decoder.decode(UInt16.self).bigEndian

                JLog.debug("SMATagPacket tag: \( String(format:"0x%x == %d",tag,tag) ) length:\(length) )")

                guard Int(length) <= decoder.countToEnd
                else
                {
                    throw SMAPacketError.prematureEndOfSMAContentData("SMATagPacket content too short expected length:\(length) has:\(decoder.countToEnd)")
                }
                self.data    = try decoder.decode(Data.self,length:Int(length))

                if length != 0
                {
                    JLog.error("SMATagPacket End Tag with length:\(length) - ignoring")
                }
            }

            var type:TagType { TagType(rawValue: Int(self.tag)) ?? .unknown }
        }


        repeat
        {
            let smaTagPacket    = try SMATagPacket(fromBinary: decoder)
            let smaNetDecoder   = BinaryDecoder(data: [UInt8](smaTagPacket.data) )

            switch smaTagPacket.type
            {
                case .end:      endPacketRead = true

                case .group:    if let group = try? smaNetDecoder.decode(UInt32.self).bigEndian
                                {
                                    JLog.trace("\(String(format:"group: 0x%08x d:%d",group,group))")
                                    self.group = group
                                }

                case .net:      if  let protocolid = try? smaNetDecoder.decode(UInt16.self).bigEndian
                                {
                                    JLog.debug("got protocol id:\(String(format:"0x%x",protocolid))")

                                    switch protocolid
                                    {
                                        case 0x6069:    JLog.debug("recognizing ObisPacket")

                                                        do
                                                        {
                                                            let obisPacket = try ObisPacket.init(fromBinary: smaNetDecoder)
                                                            self.obisPackets.append(obisPacket)
                                                        }
                                                        catch
                                                        {
                                                            JLog.error("ObisPacket decoding error:\(error)")
                                                        }


                                        case 0x6065:    JLog.debug("recognizing SMANetPacket")

                                                        do
                                                        {
                                                            let smanetPacket = try SMANetPacket.init(fromBinary: smaNetDecoder)
                                                            self.smaNetPackets.append(smanetPacket)
                                                        }
                                                        catch
                                                        {
                                                            JLog.error("SMANetPacket decoding error:\(error)")
                                                        }

                                        default:        JLog.error("protocol unknown.")
                                    }
                                }
                                else
                                {
                                    JLog.error("Could not decode protocolid of smaTagType:\(smaTagPacket.type) length:\(smaTagPacket.data.count) data:\(smaTagPacket.data.hexDump)")
                                }

                case .unknown:  JLog.warning("smaTagPacketType unknown:\(smaTagPacket.tag) length:\(smaTagPacket.data.count) data:\(smaTagPacket.data.hexDump)")
            }
        }
        while !decoder.isAtEnd && !endPacketRead

       print("\npayload:\(self.json)")
    }
}

