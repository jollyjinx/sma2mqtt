import Foundation
import BinaryCoder
import JLog



struct SMAMulticastPacket: BinaryDecodable
{
    let obis:[ObisValue]
    var group:UInt32?
    var systemid:UInt16?
    var serialnumber:UInt32?
    var currenttimems:UInt32?

    init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.debug("Decoding SMAMulticastPacket")

        let smaprefix = try decoder.decode(UInt32.self).bigEndian

        if smaprefix != 0x534d4100 // == 'SMA\0'
        {
            JLog.error("packet does not start with SMA header (SMA\0)")
            throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
        }

        JLog.debug("Valid SMA Header")
        var obisvalues = [ObisValue]()

        while !decoder.isAtEnd
        {
            let length  = try decoder.decode(UInt16.self).bigEndian
            let tag     = try decoder.decode(UInt16.self).bigEndian

            JLog.debug("Decoding SMAMulticastPacket tag: \( String(format:"0x%x == %d",tag,tag) ) length:\(length) )")

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
                                            case 0x6069:    JLog.debug("recognizing BigEndian obis protocol")

                                                            if  let systemid        = try? smaNetDecoder.decode(UInt16.self).bigEndian,
                                                                let serialnumber    = try? smaNetDecoder.decode(UInt32.self).bigEndian,
                                                                let currenttimems   = try? smaNetDecoder.decode(UInt32.self).bigEndian
                                                            {
                                                                self.systemid     = systemid
                                                                self.serialnumber = serialnumber
                                                                self.currenttimems = currenttimems
                                                                JLog.debug("got \(String(format:"systemid:0x%x serialnumber:0x%x time:0x%xms",systemid,serialnumber,currenttimems))")

                                                                obisvalues = Array<ObisValue>(fromBinary: smaNetDecoder)
                                                            }
                                                            else
                                                            {
                                                                JLog.error("BigEndian header decoding error:\(smaNetData.dump)")
                                                            }


                                            case 0x6065:    JLog.debug("recognizing LittleEndian speedwire protocol")

                                                            if  let fourbytecount   = try? smaNetDecoder.decode(UInt8.self),
                                                                let countertype     = try? smaNetDecoder.decode(UInt8.self)
                                                            {
                                                                let expectinglength     = Int(fourbytecount) * 2

                                                                JLog.debug("got fourbytecount:\(fourbytecount) =>\(expectinglength) countertype:\(countertype)")

                                                                let littleEndianData    = try smaNetDecoder.decode(Data.self,length:Int(expectinglength))
                                                                let littleEndianDecoder = BinaryDecoder(data: [UInt8](littleEndianData) )

                                                                JLog.debug("got fourbytecount:\(fourbytecount) =>\(expectinglength) == current:\(littleEndianData.count) countertype:\(countertype)")

                                                                if !smaNetDecoder.isAtEnd
                                                                {
                                                                    JLog.error("Expected expectinglength:\(expectinglength) but seems to have more - ignoring")
                                                                }

                                                            if  let packetidlow  = try? littleEndianDecoder.decode(UInt32.self).littleEndian,
                                                                let packetidhigh = try? littleEndianDecoder.decode(UInt16.self).littleEndian,
                                                                let somevalue  = try? littleEndianDecoder.decode(UInt16.self),
                                                                let sysID      = try? littleEndianDecoder.decode(UInt16.self).littleEndian,
                                                                let serial     = try? littleEndianDecoder.decode(UInt32.self).littleEndian
                                                            {
                                                                JLog.debug("packetidhigh:\(packetidhigh) low:\(packetidlow) somevalue:\(somevalue) littleEndian: sysid:\(sysID) serial:\(serial)")

                                                                obisvalues = Array<ObisValue>(fromBinary: smaNetDecoder)

                                                            }
                                                            else
                                                            {
                                                                JLog.error("littleEndianDecoder header decoding error:\(littleEndianData.dump)")

                                                            }
                                                            }
                                                            else
                                                            {
                                                                JLog.error("littleEndianData header decoding error:\(smaNetData.dump)")
                                                            }

                                            default:        JLog.error("prototocol unknown - will try decoding")
                                                            obisvalues = Array<ObisValue>(fromBinary: smaNetDecoder)

                                        }
                                    }
                                    else
                                    {
                                        JLog.error("Could not decode prototocol:\(tag) length:\(length) data:\(smaNetData.dump)")
                                    }

                    default:        JLog.warning("Could not decode tag:\(tag) length:\(length) data:\(smaNetData.dump) trying detection")
                                    obisvalues = Array<ObisValue>(fromBinary: smaNetDecoder)
                }
            }
        }
        self.obis = obisvalues

    }

    var description : String
    {
        return "Decoded: \( obis.map{ $0.value.description + "\n"}.joined() ) \n"
    }
}

