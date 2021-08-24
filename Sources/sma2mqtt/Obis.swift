import Foundation
import BinaryCoder
import JLog

enum ObisType:String,Decodable
{
    case version    = "softwareversion"
    case ipv4address

    case uint32x10
    case int32x1000
    case uint64
    case uint32x1000
}

struct ObisDefinition:Decodable
{
    let id:String
    let type:ObisType
    let unit:String
    let topic:String
    let name:String
    let title:String
}

struct Obis
{
    static let obisDefinitions:[String:ObisDefinition] = {
            if  let url = Bundle.module.url(forResource: "obisdefinition", withExtension: "json"),
                let jsonData = try? Data(contentsOf: url),
                let obisDefinitions = try? JSONDecoder().decode([ObisDefinition].self, from: jsonData)
            {
                return Dictionary(uniqueKeysWithValues: obisDefinitions.map { ($0.id, $0) })
            }
            return [String:ObisDefinition]()
        }()
}


func obisDetection(binaryDecoder:BinaryDecoder) -> [ObisValue]
{
    var obisvalues = [ObisValue]()

    while !binaryDecoder.isAtEnd
    {
        let currentposition = binaryDecoder.position

        do
        {
            let aObis = try ObisValue(fromBinary: binaryDecoder )
            obisvalues.append(aObis)
        }
        catch let error
        {
            JLog.error("Got decoding error:\(error) advancing 1 byte")
            binaryDecoder.position = currentposition + 1
        }
    }
    return obisvalues
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
        let c:UInt8 = try decoder.decode(UInt8.self)
        let d:UInt8 = try decoder.decode(UInt8.self)

        self.id = "\(a != 0 ? a : 1):\(b).\(c).\(d)"

        JLog.debug("Decoding Obis a':\(a) Id:\(id)")

        if let obisDefinition = Obis.obisDefinitions[self.id]
        {
            switch obisDefinition.type
            {
                case .version:      let intValue = try decoder.decode(Int32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%08x",intValue))")
                                    self.value = "major:\(intValue>>24) minor:\(intValue>>16 & 0xFF) build:\(intValue>>8 & 0xFF) revision:\(String(format:"%c",intValue & 0xFF))"

                case .ipv4address:  let intValue = try decoder.decode(UInt32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%08x",intValue))")
                                    self.value = intValue.ipv4String

                case .uint32x10:    let intValue = try decoder.decode(UInt32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%08x",intValue))")
                                    self.value = "\(intValue/10).\(intValue%10)"

                case .int32x1000:   let intValue = try decoder.decode(Int32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%08x",intValue))")
                                    self.value = "\(intValue/1000).\(intValue%1000)"

                case .uint32x1000:  let intValue = try decoder.decode(UInt32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%08x",intValue))")
                                    self.value = "\(intValue/1000).\(intValue%1000)"

                case .uint64:       let intValue = try decoder.decode(UInt64.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.name) value:\(String(format:"%16x",intValue))")
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

    var description:String { "\(id) : \(value)  \( Obis.obisDefinitions[id]?.topic ?? "" )"}
}

