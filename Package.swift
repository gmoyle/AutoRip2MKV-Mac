// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Detect libdvdcss path
func getLibdvdcssPath() -> String {
    let possiblePaths = [
        "/opt/homebrew/opt/libdvdcss",
        "/usr/local/opt/libdvdcss"
    ]
    
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    
    // Default fallback (will likely fail, but better than nothing)
    return "/usr/local/opt/libdvdcss"
}

let libdvdcssPath = getLibdvdcssPath()
print("Using libdvdcss path: \(libdvdcssPath)")

let package = Package(
    name: "AutoRip2MKV-Mac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoRip2MKV-Mac", targets: ["AutoRip2MKV-Mac"])
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .executableTarget(
            name: "AutoRip2MKV-Mac",
            dependencies: [],
            cSettings: [
                .headerSearchPath("include"),
                .unsafeFlags([
                    "-I\(libdvdcssPath)/include"
                ])
            ],
            linkerSettings: [
                .linkedLibrary("dvdcss"),
                .unsafeFlags([
                    "-L\(libdvdcssPath)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "\(libdvdcssPath)/lib"
                ])
            ]
        ),
        .testTarget(
            name: "AutoRip2MKV-MacTests",
            dependencies: ["AutoRip2MKV-Mac"]
        )
    ]
)
