// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "AcademyCore", platforms: [.macOS(.v14), .iOS(.v17)], products: [.library(name: "AcademyCore", targets: ["AcademyCore"])], targets: [.target(name: "AcademyCore"), .testTarget(name: "AcademyCoreTests", dependencies: ["AcademyCore"])])
