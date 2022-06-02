import Foundation
import BinaryCoder
import JLog



public struct SMAPacket: BinaryDecodable
{
    var group:UInt32?
    var systemid:UInt16?
    var serialnumber:UInt32?
    var currenttimems:UInt32?

    var obisPackets     = [ObisPacket]()
    var smaNetPackets   = [SMANetPacket]()

    public var obis:[ObisValue] { obisPackets.first!.obisvalues }

    enum Error: Swift.Error {
        /// The decoder hit the end of the data while the values it was decoding expected
        /// more.
        case prematureEndOfData

        /// Attempted to decode a type which is `Decodable`, but not `BinaryDecodable`. (We
        /// require `BinaryDecodable` because `BinaryDecoder` doesn't support full keyed
        /// coding functionality.)
        case typeNotConformingToSMAPacket(Decodable.Type)
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

        let smaprefix = try decoder.decode(UInt32.self).bigEndian

        if smaprefix != 0x534d4100 // == 'SMA\0'
        {
            JLog.error("packet does not start with SMA header (SMA\0)")
            throw Error.typeNotConformingToSMAPacket(SMAPacket.self)
        }

        JLog.debug("Valid SMA Header")

        while !decoder.isAtEnd
        {
            let length  = try decoder.decode(UInt16.self).bigEndian

            if length == 0
            {
                break;
            }
            let tag     = try decoder.decode(UInt16.self).bigEndian

            JLog.debug("Decoding tag: \( String(format:"0x%x == %d",tag,tag) ) length:\(length) )")

            if length > 0
            {
                let smaNetData    = try decoder.decode(Data.self,length:Int(length))
                let smaNetDecoder = BinaryDecoder(data: [UInt8](smaNetData) )

                switch tag
                {
                    case 0x02A0:    if let group = try? smaNetDecoder.decode(UInt32.self).bigEndian
                                    {
                                        JLog.trace("\(String(format:"group: 0x%08x d:%d",group,group))")
                                        self.group = group
                                    }
                                    else
                                    {
                                        JLog.error(("Could not decode tag:\(tag) length:\(length) data:\(smaNetData.dump)"))
                                    }

                    case 0x0010:    if  let protocolid = try? smaNetDecoder.decode(UInt16.self).bigEndian
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
                                        JLog.error("Could not decode protocol:\(tag) length:\(length) data:\(smaNetData.dump)")
                                    }

                    default:        JLog.warning("Could not decode tag:\(tag) length:\(length) data:\(smaNetData.dump) trying detection")
                }
            }
        }
    }

    var description : String
    {
        return "Decoded: \( obis.description ) \n"
    }
}

