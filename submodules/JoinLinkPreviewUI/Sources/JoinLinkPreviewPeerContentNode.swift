// MARK: Nicegram
import NGUtils
//
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AvatarNode
import AccountContext
import SelectablePeerNode
import ShareController
import SolidRoundedButtonNode
import ActivityIndicator
import ComponentFlow
import EmojiStatusComponent

private let avatarFont = avatarPlaceholderFont(size: 42.0)

private final class MoreNode: ASDisplayNode {
    private let avatarNode = AvatarNode(font: Font.regular(24.0))
    
    init(count: Int) {
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setCustomLetters(["+\(count)"])
    }
    
    func updateLayout(size: CGSize) {
        self.avatarNode.frame = CGRect(origin: CGPoint(x: floor((size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
    }
}

final class JoinLinkPreviewPeerContentNode: ASDisplayNode, ShareContentContainerNode {
    enum Content {
        case invite(isGroup: Bool, image: TelegramMediaImageRepresentation?, title: String, about: String?, memberCount: Int32, members: [EnginePeer])
        case request(isGroup: Bool, image: TelegramMediaImageRepresentation?, title: String, about: String?, memberCount: Int32, isVerified: Bool, isFake: Bool, isScam: Bool)
        
        var isGroup: Bool {
            switch self {
                case let .invite(isGroup, _, _, _, _, _), let .request(isGroup, _, _, _, _, _, _, _):
                    return isGroup
            }
        }
        
        var image: TelegramMediaImageRepresentation? {
            switch self {
                case let .invite(_, image, _, _, _, _), let .request(_, image, _, _, _, _, _, _):
                    return image
            }
        }
        
        var title: String {
            switch self {
                case let .invite(_, _, title, _, _, _), let .request(_, _, title, _, _, _, _, _):
                    return title
            }
        }
        
        var memberCount: Int32 {
            switch self {
                case let .invite(_, _, _, _, memberCount, _), let .request(_, _, _, _, memberCount, _, _, _):
                    return memberCount
            }
        }
        
        var isVerified: Bool {
            switch self {
            case .invite:
                return false
            case let .request(_, _, _, _, _, isVerified, _, _):
                return isVerified
            }
        }
        
        var isFake: Bool {
            switch self {
            case .invite:
                return false
            case let .request(_, _, _, _, _, _, isFake, _):
                return isFake
            }
        }
        
        var isScam: Bool {
            switch self {
            case .invite:
                return false
            case let .request(_, _, _, _, _, _, _, isScam):
                return isScam
            }
        }
    }
    
    private var contentDidBeginDragging: (() -> Void)?
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private var avatarIcon: ComponentView<Empty>?
    private let countNode: ASTextNode
    private let aboutNode: ASTextNode
    private let descriptionNode: ASTextNode
    private let peersScrollNode: ASScrollNode
    
    private let peerNodes: [SelectablePeerNode]
    private let moreNode: MoreNode?
    
    private let actionButtonNode: SolidRoundedButtonNode
    
    private let context: AccountContext
    private let content: Content
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    // MARK: Nicegram ATT
    var inviteHash: String?
    
    private let subscribeButtonClaimApplier = SubscribeButtonClaimApplier()
    //
    
    var join: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, content: JoinLinkPreviewPeerContentNode.Content) {
        self.context = context
        self.content = content
        self.theme = theme
        self.strings = strings
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.titleNode.textAlignment = .center
        self.countNode = ASTextNode()
        self.aboutNode = ASTextNode()
        self.aboutNode.maximumNumberOfLines = 8
        self.aboutNode.textAlignment = .center
        self.descriptionNode = ASTextNode()
        self.descriptionNode.maximumNumberOfLines = 3
        self.descriptionNode.textAlignment = .center
        self.peersScrollNode = ASScrollNode()
        self.peersScrollNode.view.showsHorizontalScrollIndicator = false
        
        self.actionButtonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 52.0, cornerRadius: 11.0, gloss: false)
        
        let itemTheme = SelectablePeerNodeTheme(textColor: theme.actionSheet.primaryTextColor, secretTextColor: .green, selectedTextColor: theme.actionSheet.controlAccentColor, checkBackgroundColor: theme.actionSheet.opaqueItemBackgroundColor, checkFillColor: theme.actionSheet.controlAccentColor, checkColor: theme.actionSheet.opaqueItemBackgroundColor, avatarPlaceholderColor: theme.list.mediaPlaceholderColor)
        
        if case let .invite(isGroup, _, _, _, memberCount, members) = content {
            self.peerNodes = members.compactMap { peer in
                guard peer.id != context.account.peerId else {
                    return nil
                }
                let node = SelectablePeerNode()
                node.setup(context: context, theme: theme, strings: strings, peer: EngineRenderedPeer(peer: peer), requiresPremiumForMessaging: false, synchronousLoad: false)
                node.theme = itemTheme
                return node
            }
            
            if members.count < Int(memberCount) {
                self.moreNode = MoreNode(count: Int(memberCount) - members.count)
            } else {
                self.moreNode = nil
            }
            
            self.actionButtonNode.title = isGroup ? strings.Invitation_JoinGroup : strings.Channel_JoinChannel
        } else {
            self.peerNodes = []
            self.moreNode = nil
            
            self.actionButtonNode.title = content.isGroup ? strings.MemberRequests_RequestToJoinGroup : strings.MemberRequests_RequestToJoinChannel
        }
        
        super.init()
        
        let peer = TelegramGroup(id: EnginePeer.Id(0), title: content.title, photo: content.image.flatMap { [$0] } ?? [], participantCount: Int(content.memberCount), role: .member, membership: .Left, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        
        self.addSubnode(self.avatarNode)
        self.avatarNode.setPeer(context: context, theme: theme, peer: EnginePeer(peer), emptyColor: theme.list.mediaPlaceholderColor)
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: content.title, font: Font.semibold(24.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        
        self.addSubnode(self.countNode)
        let membersString: String
        if content.isGroup {
            if case let .invite(_, _, _, _, memberCount, members) = content, !members.isEmpty {
                membersString = strings.Invitation_Members(memberCount)
            } else {
                membersString = strings.Conversation_StatusMembers(content.memberCount)
            }
        } else {
            membersString = strings.Conversation_StatusSubscribers(content.memberCount)
        }

        self.countNode.attributedText = NSAttributedString(string: membersString, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor, paragraphAlignment: .center)
        
        if !self.peerNodes.isEmpty {
            for peerNode in peerNodes {
                self.peersScrollNode.addSubnode(peerNode)
            }
            self.addSubnode(self.peersScrollNode)
        }
        self.moreNode.flatMap(self.peersScrollNode.addSubnode)
        
        switch content {
        case let .invite(_, _, _, about, _, _):
            if let about = about, !about.isEmpty {
                self.aboutNode.attributedText = NSAttributedString(string: about, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                self.addSubnode(self.aboutNode)
            }
        case let .request(isGroup, _, _, about, _, _, _, _):
            if let about = about, !about.isEmpty {
                self.aboutNode.attributedText = NSAttributedString(string: about, font: Font.regular(17.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
                self.addSubnode(self.aboutNode)
            }
            
            self.descriptionNode.attributedText = NSAttributedString(string: isGroup ? strings.MemberRequests_RequestToJoinDescriptionGroup : strings.MemberRequests_RequestToJoinDescriptionChannel, font: Font.regular(15.0), textColor: theme.actionSheet.secondaryTextColor, paragraphAlignment: .center)
            self.addSubnode(self.descriptionNode)
        }
        
        self.actionButtonNode.pressed = { [weak self] in
            self?.join?()
            self?.actionButtonNode.transitionToProgress()
        }
        self.addSubnode(self.actionButtonNode)
    }
    
    func activate() {
    }
    
    func deactivate() {
    }
    
    func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?) {
    }
    
    func setDidBeginDragging(_ f: (() -> Void)?) {
        self.contentDidBeginDragging = f
    }
    
    func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    func updateTheme(_ theme: PresentationTheme) {
    
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let showPeers = !self.peerNodes.isEmpty && !isLandscape
        var nodeHeight: CGFloat = (!showPeers ? 236.0 : 320.0)
        let paddedSize = CGSize(width: size.width - 60.0, height: size.height)
        
        self.peersScrollNode.isHidden = !showPeers
        
        var aboutSize: CGSize?
        var descriptionSize: CGSize?
        if self.aboutNode.supernode != nil {
            if isLandscape {
                self.aboutNode.maximumNumberOfLines = 3
            } else {
                self.aboutNode.maximumNumberOfLines = 8
            }
            let measuredSize = self.aboutNode.measure(paddedSize)
            nodeHeight += measuredSize.height + 20.0
            aboutSize = measuredSize
        }
        
        if isLandscape {
            self.descriptionNode.removeFromSupernode()
        } else if self.descriptionNode.supernode == nil {
            self.addSubnode(self.descriptionNode)
        }
        if self.descriptionNode.supernode != nil {
            let measuredSize = self.descriptionNode.measure(paddedSize)
            nodeHeight += measuredSize.height + 20.0 + 10.0
            descriptionSize = measuredSize
        }
        
        let constrainSize = CGSize(width: size.width - 32.0, height: size.height)
        
        var statusIcon: EmojiStatusComponent.Content?
        var constrainedTextSize = constrainSize
        if self.content.isFake {
            statusIcon = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_FakeAccount.uppercased())
            constrainedTextSize.width -= 32.0
        } else if self.content.isScam {
            statusIcon = .text(color: self.theme.chat.message.incoming.scamColor, string: self.strings.Message_ScamAccount.uppercased())
            constrainedTextSize.width -= 32.0
        } else if self.content.isVerified {
            statusIcon = .verified(fillColor: self.theme.list.itemCheckColors.fillColor, foregroundColor: self.theme.list.itemCheckColors.foregroundColor, sizeType: .compact)
            constrainedTextSize.width -= 24.0
        }
        
        let titleInfo = self.titleNode.updateLayoutFullInfo(constrainedTextSize)
        let titleSize = titleInfo.size
        nodeHeight += titleSize.height
        
        let verticalOrigin = size.height - nodeHeight
        
        let avatarSize: CGFloat = 100.0
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: floor((size.width - avatarSize) / 2.0), y: verticalOrigin + 32.0), size: CGSize(width: avatarSize, height: avatarSize)))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: verticalOrigin + 27.0 + avatarSize + 15.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        if let statusIcon, let lastLine = titleInfo.linesRects().last {
            let animationCache = self.context.animationCache
            let animationRenderer = self.context.animationRenderer
            
            let avatarIcon: ComponentView<Empty>
            var avatarIconTransition = ComponentTransition(transition)
            if let current = self.avatarIcon {
                avatarIcon = current
            } else {
                avatarIconTransition = avatarIconTransition.withAnimation(.none)
                avatarIcon = ComponentView<Empty>()
                self.avatarIcon = avatarIcon
            }
            
            let avatarIconComponent = EmojiStatusComponent(
                context: self.context,
                animationCache: animationCache,
                animationRenderer: animationRenderer,
                content: statusIcon,
                isVisibleForAnimations: true,
                action: nil,
                emojiFileUpdated: nil
            )
            let iconSize = avatarIcon.update(
                transition: avatarIconTransition,
                component: AnyComponent(avatarIconComponent),
                environment: {},
                containerSize: CGSize(width: 20.0, height: 20.0)
            )
            
            if let avatarIconView = avatarIcon.view {
                if avatarIconView.superview == nil {
                    avatarIconView.isUserInteractionEnabled = false
                    self.view.addSubview(avatarIconView)
                }
                
                avatarIconTransition.setFrame(view: avatarIconView, frame: CGRect(origin: CGPoint(x: titleFrame.minX + floor((titleSize.width - lastLine.width) * 0.5) + lastLine.width + 5.0, y: 8.0 + titleFrame.minY + floorToScreenPixels(lastLine.midY - iconSize.height / 2.0) - lastLine.height), size: iconSize))
            }
        } else if let avatarIcon = self.avatarIcon {
            self.avatarIcon = nil
            avatarIcon.view?.removeFromSuperview()
        }
        
        let countSize = self.countNode.measure(constrainSize)
        transition.updateFrame(node: self.countNode, frame: CGRect(origin: CGPoint(x: floor((size.width - countSize.width) / 2.0), y: verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0), size: countSize))
        
        var verticalOffset = verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0 + countSize.height + 18.0
                
        let peerSize = CGSize(width: 85.0, height: 95.0)
        let peerInset: CGFloat = 10.0
        
        var peerOffset = peerInset
        for node in self.peerNodes {
            node.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        if let moreNode = self.moreNode {
            moreNode.updateLayout(size: peerSize)
            moreNode.frame = CGRect(origin: CGPoint(x: peerOffset, y: 0.0), size: peerSize)
            peerOffset += peerSize.width
        }
        
        self.peersScrollNode.view.contentSize = CGSize(width: CGFloat(self.peerNodes.count) * peerSize.width + (self.moreNode != nil ? peerSize.width : 0.0) + peerInset * 2.0, height: peerSize.height)
        transition.updateFrame(node: self.peersScrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin + 27.0 + avatarSize + 15.0 + titleSize.height + 3.0 + countSize.height + 12.0), size: CGSize(width: size.width, height: peerSize.height)))
        
        if showPeers {
            verticalOffset += 100.0
        }
        
        if let aboutSize = aboutSize {
            transition.updateFrame(node: self.aboutNode, frame: CGRect(origin: CGPoint(x: floor((size.width - aboutSize.width) / 2.0), y: verticalOffset), size: aboutSize))
            verticalOffset += aboutSize.height + 20.0
        }
        
        let buttonInset: CGFloat = 16.0
        let actionButtonHeight = self.actionButtonNode.updateLayout(width: size.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.actionButtonNode, frame: CGRect(x: buttonInset, y: verticalOffset, width: size.width, height: actionButtonHeight))
        verticalOffset += actionButtonHeight + 20.0
        
        if let descriptionSize = descriptionSize {
            transition.updateFrame(node: self.descriptionNode, frame: CGRect(origin: CGPoint(x: floor((size.width - descriptionSize.width) / 2.0), y: verticalOffset), size: descriptionSize))
        }
            
        self.contentOffsetUpdated?(-size.height + nodeHeight, transition)
        
        // MARK: Nicegram ATT
        subscribeButtonClaimApplier.update(
            buttonNode: actionButtonNode,
            titleNode: actionButtonNode.titleNode,
            apply: true,
            chatId: nil,
            inviteHash: inviteHash
        )
        //
    }
    
    func updateSelectedPeers(animated: Bool) {
    }
}

public enum ShareLoadingState {
    case preparing
    case progress(Float)
    case done
}

public final class JoinLinkPreviewLoadingContainerNode: ASDisplayNode, ShareContentContainerNode {
    private var contentDidBeginDragging: (() -> Void)?
    private var contentOffsetUpdated: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    private var theme: PresentationTheme
    private let activityIndicator: ActivityIndicator
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        self.activityIndicator = ActivityIndicator(type: .custom(theme.actionSheet.controlAccentColor, 22.0, 2.0, false))
        
        super.init()
        
        self.addSubnode(self.activityIndicator)
    }
    
    public func activate() {
    }
    
    public func deactivate() {
    }
    
    public func setEnsurePeerVisibleOnLayout(_ peerId: EnginePeer.Id?) {
    }
    
    public func setDidBeginDragging(_ f: (() -> Void)?) {
        self.contentDidBeginDragging = f
    }
    
    public func setContentOffsetUpdated(_ f: ((CGFloat, ContainedViewLayoutTransition) -> Void)?) {
        self.contentOffsetUpdated = f
    }
    
    public func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.activityIndicator.type = .custom(theme.actionSheet.controlAccentColor, 22.0, 2.0, false)
    }
    
    public func updateLayout(size: CGSize, isLandscape: Bool, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let nodeHeight: CGFloat = 125.0
        
        let indicatorSize = self.activityIndicator.calculateSizeThatFits(size)
        let indicatorFrame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: size.height - nodeHeight + floor((nodeHeight - indicatorSize.height) / 2.0)), size: indicatorSize)
        transition.updateFrame(node: self.activityIndicator, frame: indicatorFrame)
        
        self.contentOffsetUpdated?(-size.height + nodeHeight, transition)
    }
    
    public func updateSelectedPeers(animated: Bool) {
    }
}
