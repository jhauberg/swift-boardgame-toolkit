// swift-tools-version:5.4

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
                // note that these resources are bundled specifically for the
                // library target; this means naming will never produce conflicts
                // with resources bundled through executable targets
                .copy("Rendering/Templates"),
            ]
        ),

        .executableTarget(
            name: "print-standard-deck",
            dependencies: ["BoardgameKit"],
            path: "Examples/print-standard-deck"
        ),

        .testTarget(
            name: "BoardgameKitTests",
            dependencies: ["BoardgameKit"]
        ),
    ]
)
