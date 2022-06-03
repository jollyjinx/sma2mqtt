//
//  ObisProtocol.swift
//
//
//  Created by Patrick Stein on 29.08.21.
//
import Foundation
import BinaryCoder
import JLog

struct ObisPacket:Encodable,Decodable
{
    let systemid:UInt16
    let serialnumber:UInt32
    let mseconds:UInt32
    let obisvalues:[ObisValue]
}


extension ObisPacket:BinaryDecodable
{
    enum ObisDecodingError: Error
    {
        case decoding(String)
    }


    init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.debug("Decoding ObisValue")

        do
        {
            self.systemid       = try decoder.decode(UInt16.self).bigEndian
            self.serialnumber   = try decoder.decode(UInt32.self).bigEndian
            self.mseconds       = try decoder.decode(UInt32.self).bigEndian

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
            self.obisvalues = obisvalues
        }
        catch
        {
            throw ObisDecodingError.decoding("Could not decode at position:\(decoder.position)")
        }
    }
}



