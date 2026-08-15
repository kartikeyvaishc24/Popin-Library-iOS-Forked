// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PopinCall",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PopinCall",
            targets: ["PopinCall"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pusher/pusher-websocket-swift.git", .upToNextMinor(from: "10.1.0")),
        .package(url: "https://github.com/livekit/client-sdk-swift.git", .upToNextMajor(from: "2.10.0")),
        .package(url: "https://github.com/livekit/components-swift.git", .upToNextMinor(from: "0.1.6")),
    ],
    targets: [
        .target(
            name: "PopinCall",
            dependencies: [
                .product(name: "PusherSwift", package: "pusher-websocket-swift"),
                .product(name: "LiveKit", package: "client-sdk-swift"),
                .product(name: "LiveKitComponents", package: "components-swift"),
            ],
            path: "PopinCall"
        ),
        .testTarget(
            name: "PopinCallTests",
            dependencies: ["PopinCall"],
            path: "PopinCallTests"
        ),
    ]
)