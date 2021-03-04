// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sma2mqtt",
    products: [
        .executable(name: "sma2mqtt", targets: ["sma2mqtt"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.2"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
        .package(url: "https://github.com/jollyjinx/mqtt-nio", from: "1.0.1"),
        .package(url: "https://github.com/jollyjinx/BinaryCoder", from: "2.2.1"),
    ],
    targets: [
        .target(name: "sma2mqtt", dependencies: ["BinaryCoder","NIO","MQTTNIO" ,"ArgumentParser"])
    ]
)
