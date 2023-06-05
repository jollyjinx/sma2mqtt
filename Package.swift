// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sma2mqtt",
    platforms: [
        .macOS(.v13),
//        .iOS(.v13),
//        .tvOS(.v13),
//        .watchOS(.v6)
    ],
    products: [
        .executable(name: "sma2mqtt", targets: ["sma2mqtt"]),
        .library(name: "sma2mqttLibrary", targets: ["sma2mqttLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.2")),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/swift-server-community/mqtt-nio", .upToNextMajor(from: "2.7.1")),
//        .package(url: "https://github.com/crossroadlabs/Regex.git", .upToNextMajor(from: "1.2.0")),
//        .package(url: "https://github.com/emqx/CocoaMQTT", .upToNextMajor(from: "1.0.8")),
        .package(url: "https://github.com/jollyjinx/BinaryCoder", from: "2.3.1"),
//        .package(url: "/Users/jolly/Documents/GitHub/BinaryCoder", .revision("58feed3") ),
//        .package(url: "/Users/jolly/Documents/GitHub/JLog", .revision("440b721") ),
        .package(url: "https://github.com/jollyjinx/JLog", from:"0.0.4")
    ],
    targets: [
        .executableTarget(
                        name: "sma2mqtt",
                        dependencies: [ "sma2mqttLibrary",
                                        .product(name: "BinaryCoder", package: "BinaryCoder"),
                                        .product(name: "NIO", package: "swift-nio"),
                                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                        .product(name: "MQTTNIO", package: "mqtt-nio"),
//                                        .product(name: "CocoaMQTT", package: "mqtt-nio"),
                                        .product(name: "JLog", package: "JLog")
                                       ]
                        ),
        .target(
                        name: "sma2mqttLibrary",
                        dependencies: [
                                        .product(name: "BinaryCoder", package: "BinaryCoder"),
//                                        .product(name: "Regex", package: "Regex")
                                        .product(name: "JLog", package: "JLog")
                                       ],
                        resources: [ .copy("Resources/obisdefinition.json"),
                                     .copy("Resources/SMANetPacketDefinitions.json"),
                                     .copy("Resources/sma.data.objectMetaData.json"),
                                     .copy("Resources/sma.data.Translation_Names.json")
                                    ]
                        ),
        .testTarget(    name: "sma2mqttTests",
                        dependencies: [ "sma2mqttLibrary",
                                        .product(name: "BinaryCoder", package: "BinaryCoder"),
                                        .product(name: "JLog", package: "JLog")
                                    ]                    
                    )
    ]
)
