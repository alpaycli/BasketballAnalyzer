// swift-tools-version: 5.9

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Splash30",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "Splash30",
            targets: ["AppModule"],
            bundleIdentifier: "com.alpaycalalli.BasketballAnalyzer",
            teamIdentifier: "G8MSA22VSU",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .paper),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .camera(purposeString: "App uses the camera to perform analysis."),
                .photoLibraryAdd(purposeString: "App gives option to save analysis video to your photo library.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Resources")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
