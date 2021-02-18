import Dispatch
import Foundation
import AsyncNetwork
import BinaryCodable

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

struct Obis
{
    let id:String
    let value:Double

  init(from container:inout BinaryDecodingContainer) throws
  {
        let b:UInt8 = try container.decode(UInt8.self)
        let c:UInt8 = try container.decode(UInt8.self)
        let d:UInt8 = try container.decode(UInt8.self)
        let e:UInt8 = try container.decode(UInt8.self)

        self.id = "1:\(c).\(d).\(e)"

        let intValue:Int64

        switch b
        {
            case 144:   self.value = Double(try container.decode(Int64.self).bigEndian)

            default:    switch d
                        {
                            case 8:     intValue = try container.decode(Int64.self).bigEndian
                                        self.value = Double(intValue) / 3_600_000

                            case 4:     let value32 = try container.decode(Int32.self).bigEndian
                                        self.value = id == "1:14.4.0" ? Double(value32) / 1000 : Double(value32) / 10

                            default:    throw BinaryDecodingError.dataCorrupted(.init(debugDescription:
                        "Cannot initialize \(Self.self) from invalid length: \(d)"))
                        }
        }

        //print("decoded: \(id) : \(value)")
    }

    var description:String { "\(id) : \(value)" }
}


struct SMAMulticastPacket: BinaryDecodable
{
    let id : Data
    let time_in_ms: UInt32
    let header2 : Data
    let obis:[Obis]

    init(from decoder: BinaryDecoder) throws
    {
        var container = decoder.container(maxLength:608)

        self.id = try container.decode(length:6)
        self.time_in_ms = try container.decode(type(of: time_in_ms))
        self.header2 = try container.decode(length:18)

        var obisvalues = [Obis]()
        do
        {
            while !container.isAtEnd
            {
                let aObis = try Obis(from: &container )

                obisvalues.append(aObis)
            }
        }
        catch let error
        {
            print("Got decoding error:\(error)")
        }
        self.obis = obisvalues
    }
}

print("Hello from Swift 👋")
let sock = AsyncUDP()

let observer = UDPReceiveObserver(closeHandler:
                {   (sock: AsyncUDP, error: SocketError?) in

                    print("Socket did Close: \(error)")

                },
                receiveHandler:
                {
                    (sock: AsyncUDP, data: Data, address: InternetAddress) in

                    print("\n Data: \(data)  from: \(address.hostname) onPort:\(address.port)")

                    let decoder = BinaryDataDecoder()

                    if let header = try? decoder.decode(SMAMulticastPacket.self, from: data)
                    {
                        print( "Decoded: \(header.id) \(header.time_in_ms) \n")

                        var json = [String:String]()

                        for obis in header.obis
                        {
                            if let name = interestingValues[obis.id]
                            {
                                print("\(obis.id) : \(obis.value) : \(name)")
                                json[name] = "\(obis.value)"
                            }
                        }
                    }
                    else
                    {
                        print("did not decode")
                    }
                })

sock.addObserver(observer)



do {
//    let addr = InternetAddress(hostname:"10.112.16.115",port:9522, family: .inet)

    let addr = InternetAddress.anyAddr(port: 9522, family: .inet)

    //let addr = InternetAddress.anyAddr(port: 5353, family: .inet)
    try sock.bind(address: addr)
} catch  {
    print("error \(error)")
}

    //Join Muliticast Group
    let mGroup = MulticastGroup(group: "239.12.255.254")

    do
    {
        try sock.join(group: mGroup)

        //Start the Stream of Data
        try sock.beginReceiving()

    } catch  {
        print("error \(error)")
    }


// Setup shutdown handlers to handle SIGINT and SIGTERM
// https://www.balena.io/docs/reference/base-images/base-images/#how-the-images-work-at-runtime
let signalQueue = DispatchQueue(label: "shutdown")

func makeSignalSource(_ code: Int32)
{
    let source = DispatchSource.makeSignalSource(signal: code, queue: signalQueue)
    source.setEventHandler {
        source.cancel()
        print()

        do {
            try sock.leave(group: mGroup)
        } catch {
            print("Error \(error)")
        }

        print("Goodbye")
        exit(0)
    }
    source.resume()
    signal(code, SIG_IGN)
}

makeSignalSource(SIGTERM)
makeSignalSource(SIGINT)

RunLoop.main.run()
