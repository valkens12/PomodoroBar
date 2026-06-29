// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PomodoroBar",
  platforms: [
    .macOS(.v26),
  ],
  targets: [
    .executableTarget(
      name: "PomodoroBar",
      path: "Sources/PomodoroBar"
    ),
  ]
)