// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swift-boardgame-toolkit",
    platforms: [
        // note that these are requirements to the minimum version per platform;
        // it is _not_ a list of exclusively supported platforms- for example, linux/windows
        // are not excluded here just because they are not mentioned
        .macOS(.v10_13), // 10.12 for Measurement, 10.13 for WKWebView snapshot
    ],
    products: [
        .library(
            name: "BoardgameKit",
            targets: ["BoardgameKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BoardgameKit",
            dependencies: [],
            resources: [
                .copy("templates"),
            ]
        ),
    ]
)
