// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sma2mqtt",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.2"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.32.0"),
        .package(url: "https://github.com/jollyjinx/mqtt-nio", from: "1.0.1"),
        .package(url: "https://github.com/jollyjinx/BinaryCoder", from: "2.2.3"),
//        .package(url: "/Users/jolly/Documents/GitHub/BinaryCoder", .revision("f2e6dad") ),
        .package(url: "https://github.com/jollyjinx/JLog", from:"0.0.4"),
//        .package(url: "/Users/jolly/Documents/GitHub/JLog", .revision("440b721") ),
    ],
    targets: [
        .executableTarget(
                        name: "sma2mqtt",
                        dependencies: [ .product(name: "NIO", package: "swift-nio"),
                                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                        .product(name: "MQTTNIO", package: "mqtt-nio"),
                                        .product(name: "BinaryCoder", package: "BinaryCoder"),
                                        .product(name: "JLog", package: "JLog")
                                       ],
                        resources: [ .copy("Resources/obisdefinition.json")
                                    ]
//                        ),
//        .testTarget(    name: "sma2mqttTests",
//                        dependencies: [ "sma2mqtt",
//                                        .product(name: "BinaryCoder", package: "BinaryCoder"),
//                                        .product(name: "JLog", package: "JLog")
//                                    ]
                    )
    ]
)
