// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "sma2mqtt",
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
                          .package(url: "https://github.com/nicklockwood/SwiftFormat", .upToNextMajor(from: "0.51.12")),
                          .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.2.2")),
                          .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.18.0"),
                          .package(url: "https://github.com/swift-server-community/mqtt-nio", .upToNextMajor(from: "2.8.0")),
                          .package(url: "https://github.com/jollyjinx/BinaryCoder", .upToNextMajor(from: "2.3.1")),
                          .package(url: "https://github.com/jollyjinx/JLog", .upToNextMajor(from: "0.0.5")),
                      ],
                      targets: [
                          .executableTarget(name: "sma2mqtt",
                                            dependencies: [
                                                "sma2mqttLibrary",
                                                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                                                .product(name: "JLog", package: "JLog"),
                                            ]),
                          .target(name: "sma2mqttLibrary",
                                  dependencies: [
                                      .product(name: "BinaryCoder", package: "BinaryCoder"),
                                      .product(name: "AsyncHTTPClient", package: "async-http-client"),
                                      .product(name: "MQTTNIO", package: "mqtt-nio"),
                                      .product(name: "JLog", package: "JLog"),

                                  ],

                                  resources: [
                                      .process("Resources"),
                                  ]),
                          .testTarget(name: "sma2mqttTests",
                                      dependencies: [
                                          "sma2mqttLibrary",
                                          .product(name: "BinaryCoder", package: "BinaryCoder"),
                                          .product(name: "JLog", package: "JLog"),
                                      ]),
                      ])
