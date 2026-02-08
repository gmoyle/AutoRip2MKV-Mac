// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Detect library paths (Homebrew standard locations)
func getLibraryPath(name: String) -> String {
    let possiblePaths = [
        "/opt/homebrew/opt/\(name)",  // Apple Silicon
        "/usr/local/opt/\(name)"      // Intel
    ]
    
    for path in possiblePaths {
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    
    // Default fallback
    return "/opt/homebrew/opt/\(name)"
}

let libdvdcssPath = getLibraryPath(name: "libdvdcss")
let libaacspath = getLibraryPath(name: "libaacs")

let package = Package(
    name: "AutoRip2MKV-Mac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoRip2MKV-Mac", targets: ["AutoRip2MKV-Mac"])
    ],
    dependencies: [
        // Using system-installed libraries via Homebrew
    ],
    targets: [
        .executableTarget(
            name: "AutoRip2MKV-Mac",
            dependencies: [],
            cSettings: [
                .headerSearchPath("include"),
                .unsafeFlags([
                    "-I\(libdvdcssPath)/include",
                    "-I\(libaacspath)/include"
                ])
            ],
            linkerSettings: [
                .linkedLibrary("dvdcss"),
                .linkedLibrary("aacs"),
                .unsafeFlags([
                    "-L\(libdvdcssPath)/lib",
                    "-L\(libaacspath)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "\(libdvdcssPath)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "\(libaacspath)/lib"
                ])
            ]
        ),
        .testTarget(
            name: "AutoRip2MKV-MacTests",
            dependencies: ["AutoRip2MKV-Mac"]
        )
    ]
)
