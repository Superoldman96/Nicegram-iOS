load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

NGDEPS = [
    "//Nicegram/NGTranslate:NGTranslate",
    "@swiftpkg_nicegram_assistant_ios//:NGAiChatUI",
]

swift_library(
    name = "ChatSendMessageActionUI",
    module_name = "ChatSendMessageActionUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        #"-warnings-as-errors",
    ],
    deps = NGDEPS + [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AppBundle:AppBundle",
        "//submodules/TextFormat:TextFormat",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/ReactionSelectionNode",
        "//submodules/Components/ReactionButtonListComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/ComponentFlow",
        "//submodules/ChatMessageBackground",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/Components/MultilineTextWithEntitiesComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/LottieMetal",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/ActivityIndicator",
        "//submodules/UndoUI",
        "//submodules/RadialStatusNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
