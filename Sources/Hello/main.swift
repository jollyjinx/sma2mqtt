import Dispatch
import Foundation
import AsyncNetwork
import BinaryCoder

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

                    let binaryDecoder = BinaryDecoder(data: [UInt8](data) )
                    if let sma = try? binaryDecoder.decode(SMAMulticastPacket.self)
                    {
                        print( "Decoded: \(sma)")
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
