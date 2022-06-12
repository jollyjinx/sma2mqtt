// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sma2mqtt",
    platforms: [
        .macOS(.v10_15),
//        .iOS(.v13),
//        .tvOS(.v13),
//        .watchOS(.v6)
    ],
    products: [
        .executable(name: "sma2mqtt", targets: ["sma2mqtt"]),
        .library(name: "sma2mqttLibrary", targets: ["sma2mqttLibrary"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
//        .package(url: "https://github.com/sroebert/mqtt-nio.git", from: "2.6.0"),
//        .package(url: "https://github.com/sroebert/mqtt-nio.git", .revision("6d75778") ),
//        .package(url: "https://github.com/swift-server-community/mqtt-nio", from: "2.6.0"),
        .package(url: "https://github.com/swift-server-community/mqtt-nio", .revision("bc68c7c")),

        .package(url: "https://github.com/jollyjinx/BinaryCoder", from: "2.3.1"),
//        .package(url: "/Users/jolly/Documents/GitHub/BinaryCoder", .revision("58feed3") ),
        .package(url: "https://github.com/jollyjinx/JLog", from:"0.0.4"),
//        .package(url: "/Users/jolly/Documents/GitHub/JLog", .revision("440b721") ),
    ],
    targets: [
        .executableTarget(
                        name: "sma2mqtt",
                        dependencies: [ "sma2mqttLibrary",
                                        .product(name: "NIO", package: "swift-nio"),
                                        .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                        .product(name: "MQTTNIO", package: "mqtt-nio"),
                                        .product(name: "JLog", package: "JLog")
                                       ]
                        ),
        .target(
                        name: "sma2mqttLibrary",
                        dependencies: [ .product(name: "BinaryCoder", package: "BinaryCoder"),
                                        .product(name: "JLog", package: "JLog")
                                       ],
                        resources: [ .copy("Resources/obisdefinition.json"),
                                     .copy("Resources/SMANetPacketDefinitions.json")
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
