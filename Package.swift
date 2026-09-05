// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "DiskCleaner",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DiskCleaner",
            path: "Sources/DiskCleaner"
        )
    ]
)
