//
//  File.swift
//  
//
//  Created by Patrick Stein on 27.06.23.
//

import Foundation
import JLog

struct SMAPacketGenerator {}


extension SMAPacketGenerator
{
    enum GeneratorError: Error
    {
        case objectIDConversionError(String)
    }

    static func generatePacketForObjectID(packetcounter:Int,objectID:String,dstSystemId:UInt16 = 0xffff , dstSerial:UInt32 = 0xFFFF_FFFF) throws -> String
    {
        let command = try objectID2Command(objectId: objectID)
        return try generateCommandPacket(packetcounter:packetcounter,command:command,dstSystemId:dstSystemId,dstSerial:dstSerial)
    }

    static func generateCommandPacket(packetcounter:Int,command:String,dstSystemId:UInt16 = 0xffff , dstSerial:UInt32 = 0xFFFF_FFFF) throws -> String
    {
        let jobid = String(format:"%02x",1)
        let result = "0000"
        let remainingpackets = "0000"
        let packetid = String(format:"%02x%02x",(packetcounter & 0xFF),(((packetcounter & 0x7F00) >> 8 )|0x80))
        let dstSysidString = String(format:"%02x%02x",(dstSystemId & 0xFF),((dstSystemId & 0xFF00) >> 8) )
        let dstSerialString = String(format:"%02x%02x%02x%02x",(dstSerial & 0xFF),((dstSerial >> 8) & 0xFF),((dstSerial >> 16) & 0xFF),((dstSerial >> 24) & 0xFF))

        let header = """
        534d 4100
            0004 02a0 0000 0001
        """

        let smanetpacketheader =
        """
            A0
            \(dstSysidString) \(dstSerialString) 00
            01
            1234 95b5 4321 00
            \(jobid)
            \(result)
            \(remainingpackets)
            \(packetid)
        """

        let smanetpacketwithoutlength = smanetpacketheader + command
        JLog.trace("smanetpacketwithoutlength :\(smanetpacketwithoutlength)")

        let smanetpacketlength = smanetpacketwithoutlength.hexStringToData().count + 1
        JLog.trace("smanetpacketlength :\(smanetpacketlength)")

        assert(smanetpacketlength % 4 == 0)
        assert(smanetpacketlength < 255)

        let smanetpacket =  " 0010 6065 \n"
                            + String(format:" %02x ",(smanetpacketlength / 4)) + smanetpacketwithoutlength

        let footer = " 0000 0000 "

        let smapacket = header + String(format:" %04x ",smanetpacket.hexStringToData().count - 2) + smanetpacket + footer

        JLog.trace("generated smapacket:\(smapacket)")

        return smapacket //.hexStringToData()
    }

    static func objectID2Command(objectId:String) throws -> String
    {
        let regex = #/([a-fA-F\d]{2})([a-fA-F\d]{2})_([a-fA-F\d]{2})([a-fA-F\d]{2})([a-fA-F\d]{2})([a-fA-F\d]{2})/#

        if let match = objectId.firstMatch(of: regex)
        {
            let (_,a,b,c,d,e,f) = match.output

            return "0000 \(b)\(a) \(f)\(e) \(d)\(c)  FF\(e) \(d)\(c)"
        }
        throw GeneratorError.objectIDConversionError(objectId)
    }

    static func generateDiscoveryPacket() -> String
    {
        let data = Data([0x53, 0x4D, 0x41, 0x00, 0x00, 0x04, 0x02, 0xA0, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00])

        return data.hexDump
    }

    static func generateLoginPacket(packetcounter:Int,password: String, userRight: UserRight,dstSystemId:UInt16 = 0xffff , dstSerial:UInt32 = 0xFFFF_FFFF) throws -> String
    {
        let encodedPassword = encodePassword(password: password, userRight: userRight)
        let passwordCommand = "0C04 fdff 07000000 84030000 4c20cb51 00000000 " + encodedPassword
        return try generateCommandPacket(packetcounter:packetcounter,command:passwordCommand,dstSystemId:dstSystemId,dstSerial:dstSerial)
    }


    static func encodePassword(password: String, userRight: UserRight) -> String
    {
        let paddedPassword = password.padding(toLength: 12, withPad: "\0", startingAt: 0)
        let passwordData = Data(paddedPassword.utf8)

        let usertype = userRight == .user ? 0x88 : 0xBB

        var encoded = Data()
        for byte in passwordData
        {
            let calculate = UInt8((Int(byte) + usertype) % 256)
            encoded.append(calculate)
        }

        return encoded.hexDump
    }

}

