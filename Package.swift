// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PomodoroBar",
  platforms: [
    .macOS(.v14),
  ],
  targets: [
    .executableTarget(
      name: "PomodoroBar",
      path: "Sources/PomodoroBar"
    ),
    .testTarget(
      name: "PomodoroBarTests",
      dependencies: ["PomodoroBar"],
      path: "Tests/PomodoroBarTests"
    ),
  ]
)