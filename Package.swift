// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription



let package = Package(
    name: "Hello",
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/FitnessKit/AsyncNetwork", from: "1.0.2"),
        .package(url: "https://github.com/jverkoey/BinaryCodable", from: "0.3.1"),
//        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
//        .package(url: "https://github.com/HJianBo/Mqtt", from: "0.2.0"),

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Hello",
            dependencies: [ "AsyncNetwork", "BinaryCodable"])
    ]
)
