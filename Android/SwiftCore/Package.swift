// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VetPilotCore", products: [
 .library(name: "VetPilotCore", type: .dynamic, targets: ["VetPilotCore", "AndroidJNI"]),
 .executable(name: "CoreCLI", targets: ["CoreCLI"])
], targets: [
 .target(name: "VetPilotCore"),
 .target(name: "AndroidJNI", publicHeadersPath: "include"),
 .executableTarget(name: "CoreCLI", dependencies: ["VetPilotCore"])
], swiftLanguageModes: [.v5])
