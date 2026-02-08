// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// The Swift package definition for the todo-server application.
let package = Package(
    name: "todo-server",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
    products: [
        .executable(name: "ToDoApp", targets: ["ToDoApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(name: "ToDoApp",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdBasicAuth", package: "hummingbird-auth"),
                .product(name: "HummingbirdBcrypt", package: "hummingbird-auth"),
                .product(name: "JWTKit", package: "jwt-kit")
            ],
            path: "Sources/App"
        ),
        .testTarget(name: "ToDoAppTests",
            dependencies: [
                .byName(name: "ToDoApp"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ],
            path: "Tests/AppTests",
            resources: [
                .process("Resources/volatile-config.json")
            ]
        )
    ]
)
