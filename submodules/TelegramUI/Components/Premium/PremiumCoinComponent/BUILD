load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PremiumCoinComponent",
    module_name = "PremiumCoinComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        #"-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/GZip",
        "//submodules/LegacyComponents",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/TelegramUI/Components/Premium/PremiumStarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
