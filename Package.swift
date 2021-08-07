// swift-tools-version:5.3
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
    products: [
        .executable(name: "sma2mqtt", targets: ["sma2mqtt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.2"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
        .package(url: "https://github.com/jollyjinx/mqtt-nio", from: "1.0.1"),
        .package(url: "https://github.com/jollyjinx/BinaryCoder", from: "2.2.1"),
        .package(url: "https://github.com/jollyjinx/JLog", from: "0.0.2")
    ],
    targets: [
        .target(name: "sma2mqtt",
//        dependencies: ["BinaryCoder","NIO","MQTTNIO" ,"ArgumentParser","JLog"])
        dependencies: [ .product(name: "BinaryCoder", package: "BinaryCoder"),
                        .product(name: "NIO", package: "swift-nio"),
                        .product(name: "MQTTNIO", package: "mqtt-nio"),
                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                        .product(name: "JLog", package: "JLog")
                        ]
                )
                ]
)
