import Foundation
import BinaryCoder

     let interestingValues = [   "1:1.4.0"   : "grid usage" ,
                            "1:1.8.0"   : "grid counter",
                            "1:2.4.0"   : "feed in",
                            "1:2.8.0"   : "feed in counter",

                            "1:21.4.0"  :   "L1 grid usage",
                            "1:21.8.0"  :   "L1 grid counter",
                            "1:22.4.0"  :   "L1 feed in",
                            "1:22.8.0"  :   "L1 feed in counter",

                            "1:41.4.0"  :   "L2 grid usage",
                            "1:41.8.0"  :   "L2 grid counter",
                            "1:42.4.0"  :   "L2 feed in",
                            "1:42.8.0"  :   "L2 feed in counter",

                            "1:61.4.0"  :   "L3 grid usage",
                            "1:61.8.0"  :   "L3 grid counter",
                            "1:62.4.0"  :   "L3 feed in",
                            "1:62.8.0"  :   "L3 feed in counter",

                            "1:14.4.0"  :   "frequency"
                        ];


struct ObisValue:BinaryDecodable, Encodable
{
    let id:String
    let value:Double

    init(fromBinary decoder: BinaryDecoder) throws
    {
//        print("Decoding ObisValue")

        let b:UInt8 = try decoder.decode(UInt8.self)
        let c:UInt8 = try decoder.decode(UInt8.self)
        let d:UInt8 = try decoder.decode(UInt8.self)
        let e:UInt8 = try decoder.decode(UInt8.self)

        self.id = "1:\(c).\(d).\(e)"

//        print("Decoding ObisValue:id:\(id)")

        let intValue:Int64

        switch b
        {
            case 144:   self.value  = Double(try decoder.decode(Int64.self).bigEndian)

            default:    switch d
                        {
                            case 8:     intValue = try decoder.decode(Int64.self).bigEndian
                                        self.value = Double(intValue) / 3_600_000

                            case 4:     let value32 = try decoder.decode(Int32.self).bigEndian
                                        self.value = id == "1:14.4.0" ? Double(value32) / 1000 : Double(value32) / 10

                            default:    throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
                        }
        }
    }

    var description:String { "\(id) : \(value)  \( interestingValues[id] ?? "unknown" )" }
}


struct SMAMulticastPacket: BinaryDecodable
{
    let id : Data
    let time_in_ms: UInt32
    let header2 : Data
    let obis:[ObisValue]

    init(fromBinary decoder: BinaryDecoder) throws
    {
//        print("Decoding SMAMulticastPacket")

        self.id         = try decoder.decode(Data.self,length:6)
        self.time_in_ms = try decoder.decode(type(of: time_in_ms))
        self.header2    = try decoder.decode(Data.self,length:18)

        var obisvalues = [ObisValue]()
        do
        {
            while true
            {
                let aObis = try ObisValue(fromBinary: decoder )

                obisvalues.append(aObis)
            }
        }
        catch let error
        {
            print("Got decoding error:\(error)")
        }
        self.obis = obisvalues
    }


    var description : String
    {
        return "Decoded: \(self.id) \(self.time_in_ms) \( obis.map{ $0.description + "\n"}.joined() ) \n"
    }
}

