import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public typealias AdminLogEventId = Int64

public struct AdminLogEvent: Comparable {
    public let id: AdminLogEventId
    public let peerId: PeerId
    public let date: Int32
    public let action: AdminLogEventAction
    
    public static func ==(lhs: AdminLogEvent, rhs: AdminLogEvent) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func <(lhs: AdminLogEvent, rhs: AdminLogEvent) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date < rhs.date
        } else {
            return lhs.id < rhs.id
        }
    }
}

public struct AdminLogEventsResult {
    public let peerId: PeerId
    public let peers: [PeerId: Peer]
    public let events: [AdminLogEvent]
}

public enum AdminLogEventAction {
    public struct ForumTopicInfo {
        public var info: EngineMessageHistoryThread.Info
        public var isClosed: Bool
        public var isHidden: Bool
        
        public init(info: EngineMessageHistoryThread.Info, isClosed: Bool, isHidden: Bool) {
            self.info = info
            self.isClosed = isClosed
            self.isHidden = isHidden
        }
    }
    
    case changeTitle(prev: String, new: String)
    case changeAbout(prev: String, new: String)
    case changeUsername(prev: String, new: String)
    case changePhoto(prev: ([TelegramMediaImageRepresentation], [TelegramMediaImage.VideoRepresentation]), new: ([TelegramMediaImageRepresentation], [TelegramMediaImage.VideoRepresentation]))
    case toggleInvites(Bool)
    case toggleSignatures(Bool)
    case toggleSignatureProfiles(Bool)
    case updatePinned(Message?)
    case editMessage(prev: Message, new: Message)
    case deleteMessage(Message)
    case participantJoin
    case participantLeave
    case participantInvite(RenderedChannelParticipant)
    case participantToggleBan(prev: RenderedChannelParticipant, new: RenderedChannelParticipant)
    case participantToggleAdmin(prev: RenderedChannelParticipant, new: RenderedChannelParticipant)
    case changeStickerPack(prev: StickerPackReference?, new: StickerPackReference?)
    case togglePreHistoryHidden(Bool)
    case updateDefaultBannedRights(prev: TelegramChatBannedRights, new: TelegramChatBannedRights)
    case pollStopped(Message)
    case linkedPeerUpdated(previous: Peer?, updated: Peer?)
    case changeGeoLocation(previous: PeerGeoLocation?, updated: PeerGeoLocation?)
    case updateSlowmode(previous: Int32?, updated: Int32?)
    case startGroupCall
    case endGroupCall
    case groupCallUpdateParticipantMuteStatus(peerId: PeerId, isMuted: Bool)
    case updateGroupCallSettings(joinMuted: Bool)
    case groupCallUpdateParticipantVolume(peerId: PeerId, volume: Int32)
    case deleteExportedInvitation(ExportedInvitation)
    case revokeExportedInvitation(ExportedInvitation)
    case editExportedInvitation(previous: ExportedInvitation, updated: ExportedInvitation)
    case participantJoinedViaInvite(invitation: ExportedInvitation, joinedViaFolderLink: Bool)
    case changeHistoryTTL(previousValue: Int32?, updatedValue: Int32?)
    case changeTheme(previous: String?, updated: String?)
    case participantJoinByRequest(invitation: ExportedInvitation, approvedBy: PeerId)
    case toggleCopyProtection(Bool)
    case sendMessage(Message)
    case changeAvailableReactions(previousValue: PeerAllowedReactions, updatedValue: PeerAllowedReactions)
    case changeUsernames(prev: [String], new: [String])
    case createTopic(info: EngineMessageHistoryThread.Info)
    case deleteTopic(info: EngineMessageHistoryThread.Info)
    case editTopic(prevInfo: ForumTopicInfo, newInfo: ForumTopicInfo)
    case pinTopic(prevInfo: EngineMessageHistoryThread.Info?, newInfo: EngineMessageHistoryThread.Info?)
    case toggleForum(isForum: Bool)
    case toggleAntiSpam(isEnabled: Bool)
    case changeNameColor(prevColor: PeerNameColor, prevIcon: Int64?, newColor: PeerNameColor, newIcon: Int64?)
    case changeProfileColor(prevColor: PeerNameColor?, prevIcon: Int64?, newColor: PeerNameColor?, newIcon: Int64?)
    case changeWallpaper(prev: TelegramWallpaper?, new: TelegramWallpaper?)
    case changeStatus(prev: PeerEmojiStatus?, new: PeerEmojiStatus?)
    case changeEmojiPack(prev: StickerPackReference?, new: StickerPackReference?)
    case participantSubscriptionExtended(prev: RenderedChannelParticipant, new: RenderedChannelParticipant)
    case toggleAutoTranslation(Bool)
}

public enum ChannelAdminLogEventError {
    case generic
}

public struct AdminLogEventsFlags: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    public static let join = AdminLogEventsFlags(rawValue: 1 << 0)
    public static let leave = AdminLogEventsFlags(rawValue: 1 << 1)
    public static let invite = AdminLogEventsFlags(rawValue: 1 << 2)
    public static let ban = AdminLogEventsFlags(rawValue: 1 << 3)
    public static let unban = AdminLogEventsFlags(rawValue: 1 << 4)
    public static let kick = AdminLogEventsFlags(rawValue: 1 << 5)
    public static let unkick = AdminLogEventsFlags(rawValue: 1 << 6)
    public static let promote = AdminLogEventsFlags(rawValue: 1 << 7)
    public static let demote = AdminLogEventsFlags(rawValue: 1 << 8)
    public static let info = AdminLogEventsFlags(rawValue: 1 << 9)
    public static let settings = AdminLogEventsFlags(rawValue: 1 << 10)
    public static let pinnedMessages = AdminLogEventsFlags(rawValue: 1 << 11)
    public static let editMessages = AdminLogEventsFlags(rawValue: 1 << 12)
    public static let deleteMessages = AdminLogEventsFlags(rawValue: 1 << 13)
    public static let calls = AdminLogEventsFlags(rawValue: 1 << 14)
    public static let invites = AdminLogEventsFlags(rawValue: 1 << 15)
    public static let sendMessages = AdminLogEventsFlags(rawValue: 1 << 16)
    public static let forums = AdminLogEventsFlags(rawValue: 1 << 17)

    public static var all: AdminLogEventsFlags {
        return [.join, .leave, .invite, .ban, .unban, .kick, .unkick, .promote, .demote, .info, .settings, .sendMessages, .pinnedMessages, .editMessages, .deleteMessages, .calls, .invites, .forums]
    }
    public static var flags: AdminLogEventsFlags {
        return [.join, .leave, .invite, .ban, .unban, .kick, .unkick, .promote, .demote, .info, .settings, .sendMessages, .pinnedMessages, .editMessages, .deleteMessages, .calls, .invites, .forums]
    }
}

private func boolFromApiValue(_ value: Api.Bool) -> Bool {
    switch value {
        case .boolFalse:
            return false
        case .boolTrue:
            return true
    }
}

func channelAdminLogEvents(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, maxId: AdminLogEventId, minId: AdminLogEventId, limit: Int32 = 100, query: String? = nil, filter: AdminLogEventsFlags? = nil, admins: [PeerId]? = nil) -> Signal<AdminLogEventsResult, ChannelAdminLogEventError> {
    return postbox.transaction { transaction -> (Peer?, [Peer]?) in
        return (transaction.getPeer(peerId), admins?.compactMap { transaction.getPeer($0) })
    }
    |> castError(ChannelAdminLogEventError.self)
    |> mapToSignal { (peer, admins) -> Signal<AdminLogEventsResult, ChannelAdminLogEventError> in
        if let peer = peer, let inputChannel = apiInputChannel(peer) {
            let inputAdmins = admins?.compactMap { apiInputUser($0) }
            
            var flags: Int32 = 0
            var eventsFilter: Api.ChannelAdminLogEventsFilter? = nil
            if let filter = filter {
                flags += Int32(1 << 0)
                eventsFilter = Api.ChannelAdminLogEventsFilter.channelAdminLogEventsFilter(flags: Int32(filter.rawValue))
            }
            if let _ = inputAdmins {
                flags += Int32(1 << 1)
            }
            return network.request(Api.functions.channels.getAdminLog(flags: flags, channel: inputChannel, q: query ?? "", eventsFilter: eventsFilter, admins: inputAdmins, maxId: maxId, minId: minId, limit: limit))
            |> mapToSignal { result in
                switch result {
                case let .adminLogResults(apiEvents, apiChats, apiUsers):
                    return postbox.transaction { transaction -> AdminLogEventsResult in
                        var peers: [PeerId: Peer] = [:]
                        for apiChat in apiChats {
                            if let peer = parseTelegramGroupOrChannel(chat: apiChat) {
                                peers[peer.id] = peer
                            }
                        }
                        for apiUser in apiUsers {
                            let peer = TelegramUser(user: apiUser)
                            peers[peer.id] = peer
                        }
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: apiChats, users: apiUsers)
                        
                        var events: [AdminLogEvent] = []
                        
                        func renderedMessage(message: StoreMessage) -> Message? {
                            var associatedThreadInfo: Message.AssociatedThreadInfo?
                            if let threadId = message.threadId, let threadInfo = transaction.getMessageHistoryThreadInfo(peerId: message.id.peerId, threadId: threadId) {
                                associatedThreadInfo = postbox.seedConfiguration.decodeMessageThreadInfo(threadInfo.data)
                            }
                            var associatedMessages: SimpleDictionary<MessageId, Message> = SimpleDictionary()
                            if let replyAttribute = message.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute {
                                var foundDeletedReplyMessage = false
                                for event in apiEvents {
                                    switch event {
                                    case let .channelAdminLogEvent(_, _, _, apiAction):
                                        switch apiAction {
                                        case let .channelAdminLogEventActionDeleteMessage(apiMessage):
                                            if let messageId = apiMessage.id(namespace: Namespaces.Message.Cloud), messageId == replyAttribute.messageId, let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let replyMessage = locallyRenderedMessage(message: message, peers: peers, associatedThreadInfo: associatedThreadInfo) {
                                                associatedMessages[replyMessage.id] = replyMessage
                                                foundDeletedReplyMessage = true
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                if !foundDeletedReplyMessage, let replyMessage = transaction.getMessage(replyAttribute.messageId) {
                                    associatedMessages[replyMessage.id] = replyMessage
                                }
                            }
                            return locallyRenderedMessage(message: message, peers: peers, associatedThreadInfo: associatedThreadInfo, associatedMessages: associatedMessages)
                        }
                        
                        for event in apiEvents {
                            switch event {
                            case let .channelAdminLogEvent(id, date, userId, apiAction):
                                var action: AdminLogEventAction?
                                switch apiAction {
                                case let .channelAdminLogEventActionChangeTitle(prev, new):
                                    action = .changeTitle(prev: prev, new: new)
                                case let .channelAdminLogEventActionChangeAbout(prev, new):
                                    action = .changeAbout(prev: prev, new: new)
                                case let .channelAdminLogEventActionChangeUsername(prev, new):
                                    action = .changeUsername(prev: prev, new: new)
                                case let .channelAdminLogEventActionChangePhoto(prev, new):
                                    let previousImage = telegramMediaImageFromApiPhoto(prev)
                                    let newImage = telegramMediaImageFromApiPhoto(new)
                                    action = .changePhoto(prev: (previousImage?.representations ?? [], previousImage?.videoRepresentations ?? []) , new: (newImage?.representations ?? [], newImage?.videoRepresentations ?? []))
                                case let .channelAdminLogEventActionToggleInvites(new):
                                    action = .toggleInvites(boolFromApiValue(new))
                                case let .channelAdminLogEventActionToggleSignatures(new):
                                    action = .toggleSignatures(boolFromApiValue(new))
                                case let .channelAdminLogEventActionUpdatePinned(new):
                                    switch new {
                                    case .messageEmpty:
                                        action = .updatePinned(nil)
                                    default:
                                        if let message = StoreMessage(apiMessage: new, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let rendered = renderedMessage(message: message) {
                                            action = .updatePinned(rendered)
                                        }
                                    }
                                case let .channelAdminLogEventActionEditMessage(prev, new):
                                    if let prev = StoreMessage(apiMessage: prev, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let prevRendered = renderedMessage(message: prev), let new = StoreMessage(apiMessage: new, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let newRendered = renderedMessage(message: new) {
                                        action = .editMessage(prev: prevRendered, new: newRendered)
                                    }
                                case let .channelAdminLogEventActionDeleteMessage(message):
                                    if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let rendered = renderedMessage(message: message) {
                                        action = .deleteMessage(rendered)
                                    }
                                case .channelAdminLogEventActionParticipantJoin:
                                    action = .participantJoin
                                case .channelAdminLogEventActionParticipantLeave:
                                    action = .participantLeave
                                case let .channelAdminLogEventActionParticipantInvite(participant):
                                    let participant = ChannelParticipant(apiParticipant: participant)
                                    
                                    if let peer = peers[participant.peerId] {
                                        action = .participantInvite(RenderedChannelParticipant(participant: participant, peer: peer))
                                    }
                                case let .channelAdminLogEventActionParticipantToggleBan(prev, new):
                                    let prevParticipant = ChannelParticipant(apiParticipant: prev)
                                    let newParticipant = ChannelParticipant(apiParticipant: new)
                                    
                                    if let prevPeer = peers[prevParticipant.peerId], let newPeer = peers[newParticipant.peerId] {
                                        action = .participantToggleBan(prev: RenderedChannelParticipant(participant: prevParticipant, peer: prevPeer), new: RenderedChannelParticipant(participant: newParticipant, peer: newPeer))
                                    }
                                case let .channelAdminLogEventActionParticipantToggleAdmin(prev, new):
                                    let prevParticipant = ChannelParticipant(apiParticipant: prev)
                                    let newParticipant = ChannelParticipant(apiParticipant: new)
                                    
                                    if let prevPeer = peers[prevParticipant.peerId], let newPeer = peers[newParticipant.peerId] {
                                        action = .participantToggleAdmin(prev: RenderedChannelParticipant(participant: prevParticipant, peer: prevPeer), new: RenderedChannelParticipant(participant: newParticipant, peer: newPeer))
                                    }
                                case let .channelAdminLogEventActionChangeStickerSet(prevStickerset, newStickerset):
                                    action = .changeStickerPack(prev: StickerPackReference(apiInputSet: prevStickerset), new: StickerPackReference(apiInputSet: newStickerset))
                                case let .channelAdminLogEventActionTogglePreHistoryHidden(value):
                                    action = .togglePreHistoryHidden(value == .boolTrue)
                                case let .channelAdminLogEventActionDefaultBannedRights(prevBannedRights, newBannedRights):
                                    action = .updateDefaultBannedRights(prev: TelegramChatBannedRights(apiBannedRights: prevBannedRights), new: TelegramChatBannedRights(apiBannedRights: newBannedRights))
                                case let .channelAdminLogEventActionStopPoll(message):
                                    if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let rendered = renderedMessage(message: message) {
                                        action = .pollStopped(rendered)
                                    }
                                case let .channelAdminLogEventActionChangeLinkedChat(prevValue, newValue):
                                    action = .linkedPeerUpdated(previous: prevValue == 0 ? nil : peers[PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(prevValue))], updated: newValue == 0 ? nil : peers[PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(newValue))])
                                case let .channelAdminLogEventActionChangeLocation(prevValue, newValue):
                                    action = .changeGeoLocation(previous: PeerGeoLocation(apiLocation: prevValue), updated: PeerGeoLocation(apiLocation: newValue))
                                case let .channelAdminLogEventActionToggleSlowMode(prevValue, newValue):
                                    action = .updateSlowmode(previous: prevValue == 0 ? nil : prevValue, updated: newValue == 0 ? nil : newValue)
                                case .channelAdminLogEventActionStartGroupCall:
                                    action = .startGroupCall
                                case .channelAdminLogEventActionDiscardGroupCall:
                                    action = .endGroupCall
                                case let .channelAdminLogEventActionParticipantMute(participant):
                                    let parsedParticipant = GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate(participant)
                                    action = .groupCallUpdateParticipantMuteStatus(peerId: parsedParticipant.peerId, isMuted: true)
                                case let .channelAdminLogEventActionParticipantUnmute(participant):
                                    let parsedParticipant = GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate(participant)
                                    action = .groupCallUpdateParticipantMuteStatus(peerId: parsedParticipant.peerId, isMuted: false)
                                case let .channelAdminLogEventActionToggleGroupCallSetting(joinMuted):
                                    action = .updateGroupCallSettings(joinMuted: joinMuted == .boolTrue)
                                case let .channelAdminLogEventActionExportedInviteDelete(invite):
                                    action = .deleteExportedInvitation(ExportedInvitation(apiExportedInvite: invite))
                                case let .channelAdminLogEventActionExportedInviteRevoke(invite):
                                    action = .revokeExportedInvitation(ExportedInvitation(apiExportedInvite: invite))
                                case let .channelAdminLogEventActionExportedInviteEdit(prevInvite, newInvite):
                                    action = .editExportedInvitation(previous: ExportedInvitation(apiExportedInvite: prevInvite), updated: ExportedInvitation(apiExportedInvite: newInvite))
                                case let .channelAdminLogEventActionParticipantJoinByInvite(flags, invite):
                                    action = .participantJoinedViaInvite(invitation: ExportedInvitation(apiExportedInvite: invite), joinedViaFolderLink: (flags & (1 << 0)) != 0)
                                case let .channelAdminLogEventActionParticipantVolume(participant):
                                    let parsedParticipant = GroupCallParticipantsContext.Update.StateUpdate.ParticipantUpdate(participant)
                                    action = .groupCallUpdateParticipantVolume(peerId: parsedParticipant.peerId, volume: parsedParticipant.volume ?? 10000)
                                case let .channelAdminLogEventActionChangeHistoryTTL(prevValue, newValue):
                                    action = .changeHistoryTTL(previousValue: prevValue, updatedValue: newValue)
                                case let .channelAdminLogEventActionParticipantJoinByRequest(invite, approvedBy):
                                    action = .participantJoinByRequest(invitation: ExportedInvitation(apiExportedInvite: invite), approvedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(approvedBy)))
                                case let .channelAdminLogEventActionToggleNoForwards(new):
                                    action = .toggleCopyProtection(boolFromApiValue(new))
                                case let .channelAdminLogEventActionSendMessage(message):
                                    if let message = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peer.isForum), let rendered = renderedMessage(message: message) {
                                        action = .sendMessage(rendered)
                                    }
                                case let .channelAdminLogEventActionChangeAvailableReactions(prevValue, newValue):
                                    action = .changeAvailableReactions(previousValue: PeerAllowedReactions(apiReactions: prevValue), updatedValue: PeerAllowedReactions(apiReactions: newValue))
                                case let .channelAdminLogEventActionChangeUsernames(prevValue, newValue):
                                    action = .changeUsernames(prev: prevValue, new: newValue)
                                case let .channelAdminLogEventActionCreateTopic(topic):
                                    switch topic {
                                    case let .forumTopic(_, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        action = .createTopic(info: EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor))
                                    case .forumTopicDeleted:
                                        action = .createTopic(info: EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0))
                                    }
                                case let .channelAdminLogEventActionDeleteTopic(topic):
                                    switch topic {
                                    case let .forumTopic(_, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        action = .deleteTopic(info: EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor))
                                    case .forumTopicDeleted:
                                        action = .deleteTopic(info: EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0))
                                    }
                                case let .channelAdminLogEventActionEditTopic(prevTopic, newTopic):
                                    let prevInfo: AdminLogEventAction.ForumTopicInfo
                                    switch prevTopic {
                                    case let .forumTopic(flags, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        prevInfo = AdminLogEventAction.ForumTopicInfo(info: EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor), isClosed: (flags & (1 << 2)) != 0, isHidden: (flags & (1 << 6)) != 0)
                                    case .forumTopicDeleted:
                                        prevInfo = AdminLogEventAction.ForumTopicInfo(info: EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0), isClosed: false, isHidden: false)
                                    }
                                    
                                    let newInfo: AdminLogEventAction.ForumTopicInfo
                                    switch newTopic {
                                    case let .forumTopic(flags, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        newInfo = AdminLogEventAction.ForumTopicInfo(info: EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor), isClosed: (flags & (1 << 2)) != 0, isHidden: (flags & (1 << 6)) != 0)
                                    case .forumTopicDeleted:
                                        newInfo = AdminLogEventAction.ForumTopicInfo(info: EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0), isClosed: false, isHidden: false)
                                    }
                                    
                                    action = .editTopic(prevInfo: prevInfo, newInfo: newInfo)
                                case let .channelAdminLogEventActionPinTopic(_, prevTopic, newTopic):
                                    let prevInfo: EngineMessageHistoryThread.Info?
                                    switch prevTopic {
                                    case let .forumTopic(_, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        prevInfo = EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor)
                                    case .forumTopicDeleted:
                                        prevInfo = EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0)
                                    case .none:
                                        prevInfo = nil
                                    }
                                    
                                    let newInfo: EngineMessageHistoryThread.Info?
                                    switch newTopic {
                                    case let .forumTopic(_, _, _, title, iconColor, iconEmojiId, _, _, _, _, _, _, _, _, _):
                                        newInfo = EngineMessageHistoryThread.Info(title: title, icon: iconEmojiId, iconColor: iconColor)
                                    case .forumTopicDeleted:
                                        newInfo = EngineMessageHistoryThread.Info(title: "", icon: nil, iconColor: 0)
                                    case .none:
                                        newInfo = nil
                                    }
                                    action = .pinTopic(prevInfo: prevInfo, newInfo: newInfo)
                                case let .channelAdminLogEventActionToggleForum(newValue):
                                    action = .toggleForum(isForum: newValue == .boolTrue)
                                case let .channelAdminLogEventActionToggleAntiSpam(newValue):
                                    action = .toggleAntiSpam(isEnabled: newValue == .boolTrue)
                                case let .channelAdminLogEventActionChangePeerColor(prevValue, newValue):
                                    var prevColorIndex: Int32
                                    var prevEmojiId: Int64?
                                    switch prevValue {
                                    case let .peerColor(_, color, backgroundEmojiIdValue):
                                        prevColorIndex = color ?? 0
                                        prevEmojiId = backgroundEmojiIdValue
                                    }
                                    
                                    var newColorIndex: Int32
                                    var newEmojiId: Int64?
                                    switch newValue {
                                    case let .peerColor(_, color, backgroundEmojiIdValue):
                                        newColorIndex = color ?? 0
                                        newEmojiId = backgroundEmojiIdValue
                                    }
                                    
                                    action = .changeNameColor(prevColor: PeerNameColor(rawValue: prevColorIndex), prevIcon: prevEmojiId, newColor: PeerNameColor(rawValue: newColorIndex), newIcon: newEmojiId)
                                case let .channelAdminLogEventActionChangeProfilePeerColor(prevValue, newValue):
                                    var prevColorIndex: Int32?
                                    var prevEmojiId: Int64?
                                    switch prevValue {
                                    case let .peerColor(_, color, backgroundEmojiIdValue):
                                        prevColorIndex = color
                                        prevEmojiId = backgroundEmojiIdValue
                                    }
                                    
                                    var newColorIndex: Int32?
                                    var newEmojiId: Int64?
                                    switch newValue {
                                    case let .peerColor(_, color, backgroundEmojiIdValue):
                                        newColorIndex = color
                                        newEmojiId = backgroundEmojiIdValue
                                    }
                                    
                                    action = .changeProfileColor(prevColor: prevColorIndex.flatMap(PeerNameColor.init(rawValue:)), prevIcon: prevEmojiId, newColor: newColorIndex.flatMap(PeerNameColor.init(rawValue:)), newIcon: newEmojiId)
                                case let .channelAdminLogEventActionChangeWallpaper(prevValue, newValue):
                                    let prev: TelegramWallpaper?
                                    if case let .wallPaperNoFile(_, _, settings) = prevValue {
                                        if settings == nil {
                                            prev = nil
                                        } else if case let .wallPaperSettings(flags, _, _, _, _, _, _, _) = settings, flags == 0 {
                                            prev = nil
                                        } else {
                                            prev = TelegramWallpaper(apiWallpaper: prevValue)
                                        }
                                    } else {
                                        prev = TelegramWallpaper(apiWallpaper: prevValue)
                                    }
                                    let new: TelegramWallpaper?
                                    if case let .wallPaperNoFile(_, _, settings) = newValue {
                                        if settings == nil {
                                            new = nil
                                        } else if case let .wallPaperSettings(flags, _, _, _, _, _, _, _) = settings, flags == 0 {
                                            new = nil
                                        } else {
                                            new = TelegramWallpaper(apiWallpaper: newValue)
                                        }
                                    } else {
                                        new = TelegramWallpaper(apiWallpaper: newValue)
                                    }
                                    action = .changeWallpaper(prev: prev, new: new)
                                case let .channelAdminLogEventActionChangeEmojiStatus(prevValue, newValue):
                                    action = .changeStatus(prev: PeerEmojiStatus(apiStatus: prevValue), new: PeerEmojiStatus(apiStatus: newValue))
                                case let .channelAdminLogEventActionChangeEmojiStickerSet(prevStickerset, newStickerset):
                                    action = .changeEmojiPack(prev: StickerPackReference(apiInputSet: prevStickerset), new: StickerPackReference(apiInputSet: newStickerset))
                                case let .channelAdminLogEventActionToggleSignatureProfiles(newValue):
                                    action = .toggleSignatureProfiles(boolFromApiValue(newValue))
                                case let .channelAdminLogEventActionParticipantSubExtend(prev, new):
                                    let prevParticipant = ChannelParticipant(apiParticipant: prev)
                                    let newParticipant = ChannelParticipant(apiParticipant: new)
                                    
                                    if let prevPeer = peers[prevParticipant.peerId], let newPeer = peers[newParticipant.peerId] {
                                        action = .participantSubscriptionExtended(prev: RenderedChannelParticipant(participant: prevParticipant, peer: prevPeer), new: RenderedChannelParticipant(participant: newParticipant, peer: newPeer))
                                    }
                                case let .channelAdminLogEventActionToggleAutotranslation(newValue):
                                    action = .toggleAutoTranslation(boolFromApiValue(newValue))
                                }
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                if let action = action {
                                    events.append(AdminLogEvent(id: id, peerId: peerId, date: date, action: action))
                                }
                            }
                        }
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        if peers[peerId] == nil, let peer = transaction.getPeer(peerId) {
                            peers[peer.id] = peer
                        }
                        return AdminLogEventsResult(peerId: peerId, peers: peers, events: events)
                    }
                    |> castError(MTRpcError.self)
                }
            }
            |> mapError {_ in return .generic}
        }
        
        return .complete()
    }
}
