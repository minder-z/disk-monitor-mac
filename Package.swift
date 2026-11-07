// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DiskMonitor",
    // 最低支持 macOS 10.15 Catalina（Apple 芯片版本最低为 macOS 11）
    platforms: [.macOS(.v10_15)],
    targets: [
        .executableTarget(
            name: "DiskMonitor",
            path: "Sources/DiskMonitor",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
