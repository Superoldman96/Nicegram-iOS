import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import TelegramCore

public enum GalleryControllerItemSource {
    case peerMessagesAtId(messageId: MessageId, chatLocation: ChatLocation, customTag: MemoryBuffer?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>)
    case standaloneMessage(Message, Int?)
    case custom(messages: Signal<([Message], Int32, Bool), NoError>, messageId: MessageId, loadMore: (() -> Void)?)
}

public final class GalleryControllerActionInteraction {
    public let openUrl: (String, Bool) -> Void
    public let openUrlIn: (String) -> Void
    public let openPeerMention: (String) -> Void
    public let openPeer: (EnginePeer) -> Void
    public let openHashtag: (String?, String) -> Void
    public let openBotCommand: (String) -> Void
    public let openAd: (MessageId) -> Void
    public let addContact: (String) -> Void
    public let storeMediaPlaybackState: (MessageId, Double?, Double) -> Void
    public let editMedia: (MessageId, [UIView], @escaping () -> Void) -> Void
    public let updateCanReadHistory: (Bool) -> Void

    public init(
        openUrl: @escaping (String, Bool) -> Void,
        openUrlIn: @escaping (String) -> Void,
        openPeerMention: @escaping (String) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        openHashtag: @escaping (String?, String) -> Void,
        openBotCommand: @escaping (String) -> Void,
        openAd: @escaping (MessageId) -> Void,
        addContact: @escaping (String) -> Void,
        storeMediaPlaybackState: @escaping (MessageId, Double?, Double) -> Void, 
        editMedia: @escaping (MessageId, [UIView], @escaping () -> Void) -> Void,
        updateCanReadHistory: @escaping (Bool) -> Void)
    {
        self.openUrl = openUrl
        self.openUrlIn = openUrlIn
        self.openPeerMention = openPeerMention
        self.openPeer = openPeer
        self.openHashtag = openHashtag
        self.openBotCommand = openBotCommand
        self.openAd = openAd
        self.addContact = addContact
        self.storeMediaPlaybackState = storeMediaPlaybackState
        self.editMedia = editMedia
        self.updateCanReadHistory = updateCanReadHistory
    }
}

public protocol GalleryControllerProtocol: ViewController {
    
}

public protocol StickerPackScreen {
    
}

public protocol StickerPickerInput {
    
}
