import ProjectDescription
import Foundation

let teamId = ProcessInfo.processInfo.environment["DEVELOPMENT_TEAM"] ?? "Y7J7WUK693"

let project = Project(
    name: "EdgeLab",
    packages: [
        .remote(
            url: "https://github.com/google-ai-edge/LiteRT-LM.git",
            requirement: .revision("aeefa9bee065166ade2706ff9e25ba39ed063843")
        ),
    ],
    settings: .settings(
        base: [
            "DEVELOPMENT_TEAM": .string(teamId),
            "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_VERSION": "5.0",
        ]
    ),
    targets: [
        .target(
            name: "EdgeLab",
            destinations: .iOS,
            product: .app,
            bundleId: "com.andrewvoirol.edge-lab",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "UIFileSharingEnabled": true,
                "LSSupportsOpeningDocumentsInPlace": true,
                "UISupportsDocumentBrowser": true,
                "CFBundleDisplayName": "Edge Lab",
                "CFBundleDocumentTypes": [
                    [
                        "CFBundleTypeName": "LiteRT-LM Model",
                        "CFBundleTypeRole": "Viewer",
                        "LSHandlerRank": "Owner",
                        "LSItemContentTypes": ["com.andrewvoirol.litertlm"],
                    ],
                ],
                "UTExportedTypeDeclarations": [
                    [
                        "UTTypeIdentifier": "com.andrewvoirol.litertlm",
                        "UTTypeDescription": "LiteRT-LM Model",
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["litertlm"],
                        ],
                        "UTTypeConformsTo": ["public.data"],
                    ],
                ],
            ]),
            sources: ["Sources/**"],
            entitlements: .file(path: "EdgeLab_iOS.entitlements"),
            dependencies: [
                .package(product: "LiteRTLM"),
            ]
        ),
        .target(
            name: "EdgeLabTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.andrewvoirol.edge-lab.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "EdgeLab"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "EdgeLab",
            shared: true,
            buildAction: .buildAction(targets: ["EdgeLab"]),
            testAction: .targets(["EdgeLabTests"], configuration: .debug),
            runAction: .runAction(configuration: .debug)
        ),
    ]
)