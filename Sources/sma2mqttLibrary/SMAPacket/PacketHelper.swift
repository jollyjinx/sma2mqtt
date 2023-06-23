//
//  File.swift
//
//
//  Created by Patrick Stein on 21.06.23.
//

import BinaryCoder
import Foundation
import JLog

enum PacketError: Swift.Error
{
    case notExpectedPacket(String, line: Int = #line, file: String = #file)
    case prematureEndOfData(String, line: Int = #line, file: String = #file)
    case decoding(String, line: Int = #line, file: String = #file)
}

protocol PacketHelper: Decodable
{
    init(fromBinary decoder: BinaryDecoder) throws
}

extension PacketHelper
{
    public init(data: Data) throws
    {
        let byteArray = [UInt8](data)
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(Self.self)
    }

    public init(byteArray: [UInt8]) throws
    {
        let binaryDecoder = BinaryDecoder(data: byteArray)
        self = try binaryDecoder.decode(Self.self)
    }
}

extension SMAPacket: PacketHelper {}
extension SMATagPacket: PacketHelper {}
extension SMANetPacket: PacketHelper {}
