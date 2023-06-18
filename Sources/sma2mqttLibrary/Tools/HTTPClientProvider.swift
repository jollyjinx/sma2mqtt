//
//  File.swift
//  
//
//  Created by Patrick Stein on 18.06.23.
//

import Foundation
//import NIO
//import NIOCore
//import NIOFoundationCompat
//import NIOHTTP1
import NIOSSL
import AsyncHTTPClient

enum HTTPClientProvider
{
    static var sharedHttpClient: HTTPClient = { var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none

        return HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(tlsConfiguration: tlsConfiguration,
                                                                                   timeout: .init(connect: .seconds(5), read: .seconds(10)),
                                                                                   decompression: .enabled(limit: .none)))
    }()
}
