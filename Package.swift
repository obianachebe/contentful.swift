// swift-tools-version:4.0
import PackageDescription

public let package = Package(
    name: "Contentful",
    products: [
        .library(
            name: "Contentful",
            targets: ["Contentful"])
    ],
    dependencies: [
        .package(url: "https://github.com/michaeleisel/ZippyJSON", .exact("1.2.1")),
    ],
    targets: [
        .target(
            name: "Contentful",
            dependencies: ["ZippyJSON"])
    ]
)
