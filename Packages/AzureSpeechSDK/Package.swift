// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AzureSpeechSDK",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "AzureSpeechSDK",
            targets: ["AzureSpeechSDKWrapper", "MicrosoftCognitiveServicesSpeech"]
        ),
    ],
    targets: [
        // Wrapper target to re-export the binary framework
        .target(
            name: "AzureSpeechSDKWrapper",
            dependencies: ["MicrosoftCognitiveServicesSpeech"],
            path: "Sources/AzureSpeechSDKWrapper"
        ),
        // Binary target pointing to the locally downloaded xcframework
        .binaryTarget(
            name: "MicrosoftCognitiveServicesSpeech",
            path: "../../Frameworks/MicrosoftCognitiveServicesSpeech.xcframework"
        ),
    ]
)
