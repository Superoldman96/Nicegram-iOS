load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

NGDEPS = [
    "//Nicegram/NGData:NGData",
    "@swiftpkg_nicegram_assistant_ios//:NGCoreUI",
]

swift_library(
    name = "DebugSettingsUI",
    module_name = "DebugSettingsUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        #"-warnings-as-errors",
    ],
    deps = NGDEPS + [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AppBundle:AppBundle",
        "//submodules/GZip:GZip",
        "//third-party/ZipArchive:ZipArchive",
        "//submodules/InAppPurchaseManager:InAppPurchaseManager",
        "//submodules/TelegramVoip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
