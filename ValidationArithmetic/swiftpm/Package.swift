// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "VetPilotArithmeticAudit", products: [.library(name: "FergusonVetPilot", targets: ["FergusonVetPilot"])], targets: [.target(name: "FergusonVetPilot"), .testTarget(name: "FergusonVetPilotTests", dependencies: ["FergusonVetPilot"])])
