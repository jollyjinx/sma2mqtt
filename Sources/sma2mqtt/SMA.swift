import Foundation
import BinaryCoder
import JLog
let obisDefinitions: [String:[String:String]] = [

    "1:0.0.0"   : [ "type"  : "ipv4address" , "unit" : "none", "topic" : "generic"    , "name" : "deviceaddress1"        , "title" : "Device Address 1"],

    // sums
    "1:1.4.0"   : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "usage"                  , "title" : "Grid Usage"],
    "1:1.8.0"   : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "usagecounter"           , "title" : "Grid Usage Counter"],
    "1:2.4.0"   : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "feedin"                 , "title" : "Grid Feedin"],
    "1:2.8.0"   : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "feedincounter"          , "title" : "Grid Feedin Counter"],

    "1:3.4.0"   : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "reactiveusage"          , "title" : "Reactive Usage"],
    "1:3.8.0"   : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "reavtiveusagecounter"   , "title" : "Reactive Usage Counter"],
    "1:4.4.0"   : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "reactivefeedin"         , "title" : "Reactive Feedin"],
    "1:4.8.0"   : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "reactivefeedincounter"  , "title" : "Reactive Feedin Counter"],

    "1:9.4.0"   : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "apparentusage"          , "title" : "Apparent Usage"],
    "1:9.8.0"   : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "apparentusagecounter"   , "title" : "Apparent Usage Counter"],
    "1:10.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "sums"    , "name" : "apparentfeedin"         , "title" : "Apparent Feedin"],
    "1:10.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "sums"    , "name" : "apparentfeedincounter"  , "title" : "Apparent Feedin Counter"],

    "1:13.4.0"  : [ "type"  : "uint32x10"   , "unit" : "cos(φ)","topic" : "sums"    , "name" : "powerfactor"            , "title" : "Power factor"],
    "1:14.4.0"  : [ "type"  : "uint32x1000" , "unit" : "Hz" , "topic"   : "sums"    , "name" : "gridfrequency"          , "title" : "Grid Frequency"],

    // phase 1
    "1:21.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "usage"                  , "title" : "Phase 1 Grid Usage"],
    "1:21.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "usagecounter"           , "title" : "Phase 1 Grid Usage Counter"],
    "1:22.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "feedin"                 , "title" : "Phase 1 Grid Feedin"],
    "1:22.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "feedincounter"          , "title" : "Phase 1 Grid Feedin Counter"],

    "1:23.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "reactiveusage"          , "title" : "Phase 1 Reactive Usage"],
    "1:23.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "reavtiveusagecounter"   , "title" : "Phase 1 Reactive Usage Counter"],
    "1:24.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "reactivefeedin"         , "title" : "Phase 1 Reactive Feedin"],
    "1:24.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "reactivefeedincounter"  , "title" : "Phase 1 Reactive Feedin Counter"],

    "1:29.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "apparentusage"          , "title" : "Phase 1 Apparent Usage"],
    "1:29.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "apparentusagecounter"   , "title" : "Phase 1 Apparent Usage Counter"],
    "1:30.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase1"  , "name" : "apparentfeedin"         , "title" : "Phase 1 Apparent Feedin"],
    "1:30.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase1"  , "name" : "apparentfeedincounter"  , "title" : "Phase 1 Apparent Feedin Counter"],

    "1:31.4.0"  : [ "type"  : "uint32x1000" , "unit" : "A"  , "topic"   : "phase1"  , "name" : "current"                , "title" : "Phase 1 Current"],
    "1:32.4.0"  : [ "type"  : "uint32x1000" , "unit" : "V"  , "topic"   : "phase1"  , "name" : "voltage"                , "title" : "Phase 1 Voltage"],
    "1:33.4.0"  : [ "type"  : "uint32x10"   , "unit" : "%"  , "topic"   : "phase1"  , "name" : "powerfactor"            , "title" : "Phase 1 Power factor"],
    "1:34.4.0"  : [ "type"  : "uint32x1000" , "unit" : "Hz" , "topic"   : "phase1"  , "name" : "gridfrequency"          , "title" : "Grid Frequency"],

    // phase 2
    "1:41.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "usage"                  , "title" : "Phase 2 Grid Usage"],
    "1:41.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "usagecounter"           , "title" : "Phase 2 Grid Usage Counter"],
    "1:42.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "feedin"                 , "title" : "Phase 2 Grid Feedin"],
    "1:42.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "feedincounter"          , "title" : "Phase 2 Grid Feedin Counter"],

    "1:43.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "reactiveusage"          , "title" : "Phase 2 Reactive Usage"],
    "1:43.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "reavtiveusagecounter"   , "title" : "Phase 2 Reactive Usage Counter"],
    "1:44.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "reactivefeedin"         , "title" : "Phase 2 Reactive Feedin"],
    "1:44.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "reactivefeedincounter"  , "title" : "Phase 2 Reactive Feedin Counter"],

    "1:49.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "apparentusage"          , "title" : "Phase 2 Apparent Usage"],
    "1:49.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "apparentusagecounter"   , "title" : "Phase 2 Apparent Usage Counter"],
    "1:50.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase2"  , "name" : "apparentfeedin"         , "title" : "Phase 2 Apparent Feedin"],
    "1:50.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase2"  , "name" : "apparentfeedincounter"  , "title" : "Phase 2 Apparent Feedin Counter"],

    "1:51.4.0"  : [ "type"  : "uint32x1000" , "unit" : "A"  , "topic"   : "phase2"  , "name" : "current"                , "title" : "Phase 2 Current"],
    "1:52.4.0"  : [ "type"  : "uint32x1000" , "unit" : "V"  , "topic"   : "phase2"  , "name" : "voltage"                , "title" : "Phase 2 Voltage"],
    "1:53.4.0"  : [ "type"  : "uint32x10"   , "unit" : "%"  , "topic"   : "phase2"  , "name" : "powerfactor"            , "title" : "Phase 2 Power factor"],
    "1:54.4.0"  : [ "type"  : "uint32x1000" , "unit" : "Hz" , "topic"   : "phase2"  , "name" : "gridfrequency"          , "title" : "Phase 2 Grid Frequency"],

    // phase 3
    "1:61.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "usage"                  , "title" : "Phase 3 Grid Usage"],
    "1:61.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "usagecounter"           , "title" : "Phase 3 Grid Usage Counter"],
    "1:62.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "feedin"                 , "title" : "Phase 3 Grid Feedin"],
    "1:62.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "feedincounter"          , "title" : "Phase 3 Grid Feedin Counter"],

    "1:63.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "reactiveusage"          , "title" : "Phase 3 Reactive Usage"],
    "1:63.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "reavtiveusagecounter"   , "title" : "Phase 3 Reactive Usage Counter"],
    "1:64.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "reactivefeedin"         , "title" : "Phase 3 Reactive Feedin"],
    "1:64.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "reactivefeedincounter"  , "title" : "Phase 3 Reactive Feedin Counter"],

    "1:69.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "apparentusage"          , "title" : "Phase 3 Apparent Usage"],
    "1:69.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "apparentusagecounter"   , "title" : "Phase 3 Apparent Usage Counter"],
    "1:70.4.0"  : [ "type"  : "uint32x10"   , "unit" : "W"  , "topic"   : "phase3"  , "name" : "apparentfeedin"         , "title" : "Phase 3 Apparent Feedin"],
    "1:70.8.0"  : [ "type"  : "uint64"      , "unit" : "Ws" , "topic"   : "phase3"  , "name" : "apparentfeedincounter"  , "title" : "Phase 3 Apparent Feedin Counter"],

    "1:71.4.0"  : [ "type"  : "uint32x1000" , "unit" : "A"  , "topic"   : "phase3"  , "name" : "current"                , "title" : "Phase 3 Current"],
    "1:72.4.0"  : [ "type"  : "uint32x1000" , "unit" : "V"  , "topic"   : "phase3"  , "name" : "voltage"                , "title" : "Phase 3 Voltage"],
    "1:73.4.0"  : [ "type"  : "uint32x10"   , "unit" : "%"  , "topic"   : "phase3"  , "name" : "powerfactor"            , "title" : "Phase 3 Power factor"],
    "1:74.4.0"  : [ "type"  : "uint32x1000" , "unit" : "Hz" , "topic"   : "phase3"  , "name" : "gridfrequency"          , "title" : "Phase 3 Grid Frequency"],

    "144:0.0.0" : [ "type"  : "softwareversion", "unit" : "none", "topic"   : "info"    , "name" : "version"                , "title" : "Software Version"],
 ]


struct InterestingValue : Encodable
{
    let id:     String
    let topic:  String
    let name:   String
    let title:  String
    let unit:   String
//    let ipaddress: String
    let value:  String
    let payload: String
    let devicename = "sunnymanager"
    let time = "\(Date())"
}


enum ObisType:String
{
    case version    = "softwareversion"
    case ipv4address

    case uint32x10
    case int32x1000
    case uint64
    case uint32x1000
}

extension UInt32
{
    var ipv4String:String { "\(self>>24).\(self>>16 & 0xFF).\(self>>8 & 0xFF).\(self & 0xFF)" }
}

extension Data
{
    var dump:String
        {
            var string:String = "\n"

//            let contents = self.map{ UInt8($0) }
            for (offset,value) in self.enumerated()
            {
                string += String(format:"%2d: %02x %d %c\n",offset,value,value,value > 31 && value < 0x7f ? value : " " )
            }
            return string
        }
}


struct ObisValue:BinaryDecodable, Encodable
{
    let id:String
    let value:String

    init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.debug("Decoding ObisValue")

        let a:UInt8 = try decoder.decode(UInt8.self)
        let b:UInt8 = try decoder.decode(UInt8.self)

//        if a == 0 && b == 0
//            {
//                JLog.error("End of Data detected \(a) \(b)")
//
//                throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
//            }
//
        let c:UInt8 = try decoder.decode(UInt8.self)
        let d:UInt8 = try decoder.decode(UInt8.self)

        self.id = "\(a != 0 ? a : 1):\(b).\(c).\(d)"

        JLog.debug("Decoding Obis a':\(a) Id:\(id)")

        if let obisDefinition = obisDefinitions[self.id]
        {
            guard let obisType = ObisType(rawValue:obisDefinition["type"] ?? "")
                else
                {
                    JLog.error("Unknown Obis ObisType: \(self.id)")
                    throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
                }
            JLog.trace("obisType:\(obisType)")

            switch obisType
            {
                case .version:      let intValue = try decoder.decode(Int32.self).bigEndian
                                    self.value = "major:\(intValue>>24) minor:\(intValue>>16 & 0xFF) build:\(intValue>>8 & 0xFF) revision:\(intValue & 0xFF)"

                case .ipv4address:  let intValue = try decoder.decode(UInt32.self).bigEndian
                                    self.value = intValue.ipv4String

                case .uint32x10:    let intValue = try decoder.decode(UInt32.self).bigEndian
                                    self.value = "\(intValue/10).\(intValue%10)"

                case .int32x1000:   let intValue = try decoder.decode(Int32.self).bigEndian
                                    self.value = "\(intValue/1000).\(intValue%1000)"
                                    
                case .uint32x1000:  let intValue = try decoder.decode(UInt32.self).bigEndian
                                    self.value = "\(intValue/1000).\(intValue%1000)"

                case .uint64:       let intValue = try decoder.decode(UInt64.self).bigEndian
                                    self.value = String(intValue)
            }
        }
        else
        {
            JLog.error("Unknown Obis Id: \(self.id)")
            throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
        }
        JLog.debug("Decoded corretly \(self.id) \(self.value)")

    }

    var description:String { "\(id) : \(value)  \( obisDefinitions[id]?["topic"] ?? "unknown" )" }
}


struct SMAMulticastPacket: BinaryDecodable
{
    let obis:[ObisValue]
    var group:UInt32?
    var systemid:UInt16?
    var serialnumber:UInt32?
    var currenttimems:UInt32?

    var interestingValues : [InterestingValue] { get { return obis.compactMap{ obisValue in
                                
                                                                    if let interestingValue = obisDefinitions[obisValue.id]
                                                                    {
                                                                        return InterestingValue(id: obisValue.id,
                                                                                                topic: interestingValue["topic"]!,
                                                                                                name: interestingValue["name"]!,
                                                                                                title: interestingValue["title"]!,
                                                                                                unit: interestingValue["unit"]!,
//                                                                                                ipaddress: ipaddress.ipv4String,
                                                                                                value: obisValue.value,
                                                                                                payload : obisValue.value
                                                                            )
                                                                    }
                                                                    JLog.error("Could not decode obisValue:\(obisValue)")
                                                                    return nil
                                                                }
                                        } }

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
                let data          = try decoder.decode(Data.self,length:Int(length))
                let binaryDecoder = BinaryDecoder(data: [UInt8](data) )

                switch tag
                {
                    case 0x02A0:    if let group = try? binaryDecoder.decode(UInt32.self).bigEndian
                                    {
                                        self.group = group
                                    }
                                    else
                                    {
                                        JLog.error(("Could not decode tag:\(tag) length:\(length) data:\(data.dump)"))
                                    }

                    case 0x0010:    if  let protocolid      = try? binaryDecoder.decode(UInt16.self).bigEndian, protocolid == 0x6069,
                                        let systemid        = try? binaryDecoder.decode(UInt16.self).bigEndian,
                                        let serialnumber    = try? binaryDecoder.decode(UInt32.self).bigEndian,
                                        let currenttimems   = try? binaryDecoder.decode(UInt32.self).bigEndian
                                    {
                                        self.systemid     = systemid
                                        self.serialnumber = serialnumber
                                        self.currenttimems = currenttimems
                                        JLog.debug("got systemid:\(systemid) serialnumber:\(serialnumber)")

                                        do
                                        {
                                            while !binaryDecoder.isAtEnd
                                            {
                                                let aObis = try ObisValue(fromBinary: binaryDecoder )

                                                obisvalues.append(aObis)
                                            }
                                        }
                                        catch let error
                                        {
                                            JLog.error("Got decoding error:\(error)")
                                        }
                                    }
                                    else
                                    {
                                        JLog.error("Could not decode tag:\(tag) length:\(length) data:\(data.dump)")
                                    }

                    default:        JLog.warning("Could not decode tag:\(tag) length:\(length) data:\(data.dump)")
                }
            }
        }
        self.obis = obisvalues

    }


    var description : String
    {
        return "Decoded: \( obis.map{ $0.description + "\n"}.joined() ) \n"
//        return "Decoded: \(self.id) \(self.time_in_ms) \( obis.map{ $0.description + "\n"}.joined() ) \n"
    }
}

