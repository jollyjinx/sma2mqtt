//
//  HTTPClientProvider.swift
//

import AsyncHTTPClient
import Foundation
// import NIO
// import NIOCore
// import NIOFoundationCompat
// import NIOHTTP1
import NIOSSL

enum HTTPClientProvider: Sendable
{
    static let sharedHttpClient: HTTPClient = { var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none

        return HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(tlsConfiguration: tlsConfiguration,
                                                                                   timeout: .init(connect: .seconds(5), read: .seconds(10)),
                                                                                   decompression: .enabled(limit: .none)))
    }()
}
