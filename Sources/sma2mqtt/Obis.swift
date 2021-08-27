import Foundation
import BinaryCoder
import JLog

enum ObisDefinitionType:String,Encodable,Decodable
{
    case version    = "softwareversion"
    case ipv4address

    case uint32
    case int32
    case uint64
}

struct ObisDefinition:Encodable,Decodable
{
    let id:String
    let type:ObisDefinitionType
    let factor:Decimal?
    let unit:String
    let topic:String
    let title:String
    let retain:Bool
}

struct Obis
{
    static let obisDefinitions:[String:ObisDefinition] = {
            if  let url = Bundle.module.url(forResource: "obisdefinition", withExtension: "json")
            {
                if  let jsonData = try? Data(contentsOf: url),
                    let obisDefinitions = try? JSONDecoder().decode([ObisDefinition].self, from: jsonData)
                {
                    return Dictionary(uniqueKeysWithValues: obisDefinitions.map { ($0.id, $0) })
                }
                JLog.error("Could not decode obisdefintion resource file")
                return [String:ObisDefinition]()
            }
            JLog.error("Could not find obisdefintion resource file")
            return [String:ObisDefinition]()
        }()
}

extension Array where Element == ObisValue
{
    init(fromBinary decoder:BinaryDecoder)
    {
        var obisvalues = [ObisValue]()

        while !decoder.isAtEnd
        {
            let currentposition = decoder.position

            do
            {
                let aObis = try ObisValue(fromBinary: decoder )
                obisvalues.append(aObis)
            }
            catch let error
            {
                JLog.error("Got decoding error:\(error) advancing 1 byte")
                decoder.position = currentposition + 1
            }
        }
        self = obisvalues
    }
}


enum ObisType
{
    case string(String)
    case uint(UInt64)
    case int(Int64)

    var description:String
    {
        switch self
        {
            case .string(let value):    return value.description
            case .uint(let value):      return value.description
            case .int(let value):       return value.description
        }
    }
}

extension ObisType:Decodable,Encodable
{
    private enum CodingKeys: String, CodingKey {
        case string
        case uint
        case int
    }

    enum PostTypeCodingError: Error
    {
        case decoding(String)
    }

    init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? values.decode(String.self, forKey: .string)
        {
            self = .string(value)
            return
        }
        if let value = try? values.decode(UInt64.self, forKey: .uint)
        {
            self = .uint(value)
            return
        }
        if let value = try? values.decode(Int64.self, forKey: .int)
        {
            self = .int(value)
            return
        }
        throw PostTypeCodingError.decoding("Whoops! \(dump(values))")
    }

    func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()

        switch self
        {
            case .string(let value):    try container.encode(value)
            case .uint(let value):      try container.encode(value)
            case .int(let value):       try container.encode(value)
        }
    }
}





struct ObisValue
{
    let id:String
    let value:ObisType

    var topic:String { Obis.obisDefinitions[id]?.topic ?? "id/\(id)" }
    var retain:Bool  { Obis.obisDefinitions[id]?.retain ?? false }
}


extension ObisValue:Encodable
{
    func encode(to encoder: Encoder) throws
    {
        let obisDefinition = Obis.obisDefinitions[id]!

        enum CodingKeys: String, CodingKey
        {
            case id,
            unit,
            title,
            value
        }
        var container = encoder.container(keyedBy:CodingKeys.self)

        try container.encode(obisDefinition.id      ,forKey:.id)
        try container.encode(obisDefinition.unit    ,forKey:.unit)
        try container.encode(obisDefinition.title   ,forKey:.title)

        let factor      = obisDefinition.factor
        let hasFactor   = obisDefinition.factor != nil && obisDefinition.factor! != 0

        switch value
        {
            case .string(let value):    try container.encode(value,forKey:.value)
            case .uint(let value):      if value == UInt64.max
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( hasFactor ? Decimal(value) / factor! : Decimal(value),forKey:.value)
                                        }
            case .int(let value):       if value == UInt64.min
                                        {
                                            let string:String? = nil
                                            try container.encode(string ,forKey:.value)
                                        }
                                        else
                                        {
                                            try container.encode( hasFactor ? Decimal(value) / factor! : Decimal(value),forKey:.value)
                                        }
        }
    }
}




extension ObisValue:BinaryDecodable
{
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
                                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format:"%08x",intValue))")
                                    self.value = .string("major:\(intValue>>24) minor:\(intValue>>16 & 0xFF) build:\(intValue>>8 & 0xFF) revision:\(String(format:"%c",intValue & 0xFF))")

                case .ipv4address:  let intValue = try decoder.decode(UInt32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format:"%08x",intValue))")
                                    self.value = .string(intValue.ipv4String)

                case .uint32:       let intValue = try decoder.decode(UInt32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format:"%08x",intValue))")
                                    self.value = .uint( intValue == UInt32.max ? UInt64.max : UInt64(intValue) )

                case .int32:        let intValue = try decoder.decode(Int32.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format:"%08x",intValue))")
                                    self.value = .int( intValue == UInt32.min ? Int64.min : Int64(intValue) )

                case .uint64:       let intValue = try decoder.decode(UInt64.self).bigEndian
                                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format:"%16x",intValue))")
                                    self.value = .uint( intValue )
            }
        }
        else
        {
            JLog.error("Unknown Obis Id: \(self.id)")
            throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
        }
        JLog.debug("Decoded corretly \(self.id) \(self.value)")
    }
}
