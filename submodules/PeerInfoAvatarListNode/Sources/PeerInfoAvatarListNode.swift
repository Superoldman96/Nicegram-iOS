// MARK: Nicegram SaveAvatar
import ShareController
import UndoUI
//
import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import PhotoResources
import PeerAvatarGalleryUI
import TelegramStringFormatting
import TelegramUniversalVideoContent
import GalleryUI
import UniversalMediaPlayer
import RadialStatusNode
import TelegramUIPreferences
import AvatarNode
import AvatarVideoNode
import ComponentFlow
import ComponentDisplayAdapters
import StorySetIndicatorComponent
import HierarchyTrackingLayer

private class PeerInfoAvatarListLoadingStripNode: ASImageNode {
    private var currentInHierarchy = false
    
    let imageNode = ASImageNode()
    
    override init() {
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    override public var isHidden: Bool {
        didSet {
            self.updateAnimation()
        }
    }
    private var isAnimating = false {
        didSet {
            if self.isAnimating != oldValue {
                if self.isAnimating {
                    let basicAnimation = CABasicAnimation(keyPath: "opacity")
                    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                    basicAnimation.duration = 0.45
                    basicAnimation.fromValue = 0.1
                    basicAnimation.toValue = 0.75
                    basicAnimation.repeatCount = Float.infinity
                    basicAnimation.autoreverses = true
                    
                    self.imageNode.layer.add(basicAnimation, forKey: "loading")
                } else {
                    self.imageNode.layer.removeAnimation(forKey: "loading")
                }
            }
        }
    }
    
    private func updateAnimation() {
        self.isAnimating = !self.isHidden && self.currentInHierarchy
    }
    
    override public func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.currentInHierarchy = true
        self.updateAnimation()
    }
    
    override public func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.currentInHierarchy = false
        self.updateAnimation()
    }
    
    override func layout() {
        super.layout()
        
        self.imageNode.frame = self.bounds
    }
}

private struct CustomListItemResourceId {
    public var uniqueId: String {
        return "customNode"
    }
    
    public var hashValue: Int {
        return 0
    }
}

public enum PeerInfoAvatarListItem: Equatable {
    case custom(ASDisplayNode)
    case topImage([ImageRepresentationWithReference], [VideoRepresentationWithReference], Data?)
    case image(TelegramMediaImageReference?, [ImageRepresentationWithReference], [VideoRepresentationWithReference], Data?, Bool, TelegramMediaImage.EmojiMarkup?)
    
    var id: EngineMediaResource.Id {
        switch self {
        case .custom:
            return EngineMediaResource.Id(CustomListItemResourceId().uniqueId)
        case let .topImage(representations, _, _):
            let representation = largestImageRepresentation(representations.map { $0.representation }) ?? representations[representations.count - 1].representation
            return EngineMediaResource.Id(representation.resource.id)
        case let .image(_, representations, _, _, _, _):
            let representation = largestImageRepresentation(representations.map { $0.representation }) ?? representations[representations.count - 1].representation
            return EngineMediaResource.Id(representation.resource.id)
        }
    }
    
    func isSemanticallyEqual(to: PeerInfoAvatarListItem) -> Bool {
        if case let .topImage(lhsRepresentations, _, _) = self {
            if case let .topImage(rhsRepresentations, _, _) = self {
                if let lhsRepresentation = largestImageRepresentation(lhsRepresentations.map { $0.representation }),
                    let rhsRepresentation = largestImageRepresentation(rhsRepresentations.map { $0.representation }) {
                    return lhsRepresentation.isSemanticallyEqual(to: rhsRepresentation)
                } else {
                    return false
                }
            } else if case let .image(_, rhsRepresentations, _, _, _, _) = self {
                if let lhsRepresentation = largestImageRepresentation(lhsRepresentations.map { $0.representation }),
                    let rhsRepresentation = largestImageRepresentation(rhsRepresentations.map { $0.representation }) {
                    return lhsRepresentation.isSemanticallyEqual(to: rhsRepresentation)
                } else {
                    return false
                }
            } else {
                return false
            }
        } else if case let .image(_, lhsRepresentations, _, _, _, _) = self {
            if case let .topImage(rhsRepresentations, _, _) = self {
                if let lhsRepresentation = largestImageRepresentation(lhsRepresentations.map { $0.representation }),
                    let rhsRepresentation = largestImageRepresentation(rhsRepresentations.map { $0.representation }) {
                    return lhsRepresentation.isSemanticallyEqual(to: rhsRepresentation)
                } else {
                    return false
                }
            } else if case let .image(_, rhsRepresentations, _, _, _, _) = self {
                if let lhsRepresentation = largestImageRepresentation(lhsRepresentations.map { $0.representation }),
                    let rhsRepresentation = largestImageRepresentation(rhsRepresentations.map { $0.representation }) {
                    return lhsRepresentation.isSemanticallyEqual(to: rhsRepresentation)
                } else {
                    return false
                }
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    var representations: [ImageRepresentationWithReference] {
        switch self {
            case .custom:
                return []
            case let .topImage(representations, _, _):
                return representations
            case let .image(_, representations, _, _, _, _):
                return representations
        }
    }
    
    
    var videoRepresentations: [VideoRepresentationWithReference] {
        switch self {
            case .custom:
                return []
            case let .topImage(_, videoRepresentations, _):
                return videoRepresentations
            case let .image(_, _, videoRepresentations, _, _, _):
                return videoRepresentations
        }
    }
    
    var isFallback: Bool {
        switch self {
            case .custom, .topImage:
                return false
            case let .image(_, _, _, _, isFallback, _):
                return isFallback
        }
    }
    
    var emojiMarkup: TelegramMediaImage.EmojiMarkup? {
        switch self {
            case let .image(_, _, _, _, _, emojiMarkup):
                return emojiMarkup
            default:
                return nil
        }
    }
    
    public init?(entry: AvatarGalleryEntry) {
        switch entry {
            case let .topImage(representations, videoRepresentations, _, _, immediateThumbnailData, _):
                self = .topImage(representations, videoRepresentations, immediateThumbnailData)
            case let .image(_, reference, representations, videoRepresentations, _, _, _, _, immediateThumbnailData, _, isFallback, emojiMarkup):
                if representations.isEmpty {
                    return nil
                }
                self = .image(reference, representations, videoRepresentations, immediateThumbnailData, isFallback, emojiMarkup)
        }
    }
}

public final class PeerInfoAvatarListItemNode: ASDisplayNode {
    private let context: AccountContext
    private let peer: EnginePeer
    public let imageNode: TransformImageNode
    private var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    private let playbackStartDisposable = MetaDisposable()
    private var markupNode: AvatarVideoNode?
    private let statusDisposable = MetaDisposable()
    private let preloadDisposable = MetaDisposable()
    private let statusNode: RadialStatusNode
    
    private var playerStatus: MediaPlayerStatus?
    private var isLoading = Promise<Bool>(false)
    private var loadingProgress = Promise<Float?>(nil)
    private var progress: Signal<Float?, NoError>?
    private var loadingProgressDisposable = MetaDisposable()
    private var hasProgress = false

    private let hierarchyTrackingLayer = HierarchyTrackingLayer()
    
    public let isReady = Promise<Bool>()
    private var didSetReady: Bool = false
    
    public var item: PeerInfoAvatarListItem?
        
    private var statusPromise = Promise<(MediaPlayerStatus?, Double?)?>()
    var mediaStatus: Signal<(MediaPlayerStatus?, Double?)?, NoError> {
        get {
            return self.statusPromise.get()
        }
    }
    
    var delayCentralityLose = false
    var isCentral: Bool? = nil {
        didSet {
            guard self.isCentral != oldValue, let isCentral = self.isCentral else {
                return
            }
            if isCentral {
                self.setupVideoPlayback()
                self.preloadDisposable.set(nil)
            } else {
                if let videoNode = self.videoNode {
                    self.playbackStartDisposable.set(nil)
                    self.statusPromise.set(.single(nil))
                    self.videoNode = nil
                    if self.delayCentralityLose {
                        Queue.mainQueue().after(0.5) {
                            videoNode.removeFromSupernode()
                        }
                    } else {
                        videoNode.removeFromSupernode()
                    }
                }
                if let videoContent = self.videoContent {
                    let duration: Double = (self.videoStartTimestamp ?? 0.0) + 4.0
                    self.preloadDisposable.set(preloadVideoResource(postbox: self.context.account.postbox, userLocation: .other, userContentType: .video, resourceReference: videoContent.fileReference.resourceReference(videoContent.fileReference.media.resource), duration: duration).startStrict())
                }
            }
            self.markupNode?.updateVisibility(isCentral)
        }
    }
    
    init(context: AccountContext, peer: EnginePeer) {
        self.context = context
        self.peer = peer
        self.imageNode = TransformImageNode()
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.3))
        self.statusNode.isUserInteractionEnabled = false
   
        super.init()
        
        self.clipsToBounds = true
                
        self.imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
        self.addSubnode(self.imageNode)
        self.addSubnode(self.statusNode)
                
        self.loadingProgressDisposable.set((combineLatest(self.isLoading.get()
        |> mapToSignal { value -> Signal<Bool, NoError> in
            if value {
                return .single(value) |> delay(0.5, queue: Queue.mainQueue())
            } else {
                return .single(value)
            }
        } |> distinctUntilChanged, self.loadingProgress.get() |> distinctUntilChanged)).startStrict(next: { [weak self] isLoading, progress in
            guard let strongSelf = self else {
                return
            }
            if isLoading, let progress = progress {
                strongSelf.hasProgress = true
                strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(max(0.027, progress)), cancelEnabled: false, animateRotation: true), completion: {})
            } else if strongSelf.hasProgress {
                strongSelf.hasProgress = false
                strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: 1.0, cancelEnabled: false, animateRotation: true), completion: { [weak self] in
                     guard let strongSelf = self else {
                        return
                    }
                    if !strongSelf.hasProgress {
                        Queue.mainQueue().after(0.3) {
                            strongSelf.statusNode.transitionToState(.none, completion: {})
                        }
                    }
                })
            }
        }))

        self.hierarchyTrackingLayer.isInHierarchyUpdated = { [weak self] value in
            guard let self else {
                return
            }
            if value {
                self.setupVideoPlayback()
            } else {
                self.videoNode?.removeFromSupernode()
                self.videoNode = nil
                self.videoContent = nil
            }
        }
        self.layer.addSublayer(self.hierarchyTrackingLayer)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.playbackStartDisposable.dispose()
        self.preloadDisposable.dispose()
        self.loadingProgressDisposable.dispose()
    }
    
    private func updateStatus() {
        guard let videoContent = self.videoContent else {
            return
        }
             
        var bufferingProgress: Float?
        if isMediaStreamable(resource: videoContent.fileReference.media.resource) {
            if let playerStatus = self.playerStatus {
                if case let .buffering(_, _, progress, _) = playerStatus.status {
                    bufferingProgress = progress
                } else if case .playing = playerStatus.status {
                    bufferingProgress = nil
                }
            } else {
                bufferingProgress = nil
            }
        }
        
        if self.progress == nil {
            self.loadingProgress.set(.single(bufferingProgress))
            self.isLoading.set(.single(bufferingProgress != nil))
        }
    }
    
    public func updateTransitionFraction(_ fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        if let videoNode = self.videoNode {
            if case .immediate = transition, fraction == 1.0 {
                return
            }
            transition.updateAlpha(node: videoNode, alpha: 1.0 - fraction)
        }
        if let markupNode = self.markupNode {
            if case .immediate = transition, fraction == 1.0 {
                return
            }
            transition.updateAlpha(node: markupNode, alpha: 1.0 - fraction)
        }
    }
    
    private func setupVideoPlayback() {
        guard let videoContent = self.videoContent, let isCentral = self.isCentral, isCentral, self.videoNode == nil else {
            return
        }
        if !self.hierarchyTrackingLayer.isInHierarchy {
            return
        }
        
        let mediaManager = self.context.sharedContext.mediaManager
        let videoNode = UniversalVideoNode(context: self.context, postbox: self.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .secondaryOverlay)
        videoNode.isUserInteractionEnabled = false
        videoNode.canAttachContent = true
        videoNode.isHidden = true
        
        if let videoStartTimestamp = self.videoStartTimestamp {
            self.playbackStartDisposable.set((videoNode.status
            |> castError(Bool.self)
            |> mapToSignal { status -> Signal<Bool, Bool> in
                if let status = status, case .playing = status.status {
                    if videoStartTimestamp > 0.0 && videoStartTimestamp > status.duration - 1.0 {
                        return .fail(true)
                    }
                    return .single(true)
                } else {
                    return .single(false)
                }
            }
            |> filter { playing in
                return playing
            }
            |> take(1)
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                if let strongSelf = self {
                    if let _ = strongSelf.videoNode {
                        videoNode.seek(0.0)
                        Queue.mainQueue().after(0.1) {
                            strongSelf.videoNode?.layer.allowsGroupOpacity = true
                            strongSelf.videoNode?.alpha = 0.0
                            strongSelf.videoNode?.isHidden = false
                            
                            strongSelf.videoNode?.alpha = 1.0
                            strongSelf.videoNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.01)
                        }
                    }
                }
            }, completed: { [weak self] in
                if let strongSelf = self {
                    Queue.mainQueue().after(0.1) {
                        strongSelf.videoNode?.isHidden = false
                    }
                }
            }))
        } else {
            self.playbackStartDisposable.set(nil)
            videoNode.isHidden = false
        }
        videoNode.play()
        
        self.videoNode = videoNode
        let videoStartTimestamp = self.videoStartTimestamp
        self.statusPromise.set(videoNode.status |> map { ($0, videoStartTimestamp) })
        
        self.statusDisposable.set((self.mediaStatus
        |> deliverOnMainQueue).startStrict(next: { [weak self] mediaStatus in
            if let strongSelf = self {
                if let mediaStatusAndStartTimestamp = mediaStatus {
                    strongSelf.playerStatus = mediaStatusAndStartTimestamp.0
                }
                strongSelf.updateStatus()
            }
        }))
        
        self.insertSubnode(videoNode, belowSubnode: self.statusNode)
        
        self.isReady.set(videoNode.ready |> map { return true })
    }
    
    func setup(item: PeerInfoAvatarListItem, isMain: Bool, progress: Signal<Float?, NoError>? = nil, synchronous: Bool, fullSizeOnly: Bool = false) {
        let previousItem = self.item
        self.item = item
        self.progress = progress
        
        var fullSizeOnly = fullSizeOnly
        if let previousItem = previousItem, previousItem.isSemanticallyEqual(to: item) && self.didSetReady && isMain {
            fullSizeOnly = true
        }
        
        if let progress = progress {
            self.loadingProgress.set((progress
            |> beforeNext { [weak self] next in
                self?.isLoading.set(.single(next != nil))
            }))
        }
        
        let representations: [ImageRepresentationWithReference]
        let videoRepresentations: [VideoRepresentationWithReference]
        let immediateThumbnailData: Data?
        var id: Int64
        let markup: TelegramMediaImage.EmojiMarkup?
        switch item {
        case let .custom(node):
            representations = []
            videoRepresentations = []
            immediateThumbnailData = nil
            id = 0
            markup = nil
            if !synchronous {
                self.addSubnode(node)
            }
        case let .topImage(topRepresentations, videoRepresentationsValue, immediateThumbnail):
            id = self.peer.id.id._internalGetInt64Value()
            representations = topRepresentations
            videoRepresentations = videoRepresentationsValue
            immediateThumbnailData = immediateThumbnail
            if let resource = videoRepresentations.first?.representation.resource as? CloudPhotoSizeMediaResource {
                id = id &+ resource.photoId
            }
            markup = nil
        case let .image(reference, imageRepresentations, videoRepresentationsValue, immediateThumbnail, _, markupValue):
            representations = imageRepresentations
            videoRepresentations = videoRepresentationsValue
            immediateThumbnailData = immediateThumbnail
            if case let .cloud(imageId, _, _) = reference {
                id = imageId
            } else {
                id = self.peer.id.id._internalGetInt64Value()
            }
            markup = markupValue
        }
        self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.context.account, representations: representations, immediateThumbnailData: immediateThumbnailData, autoFetchFullSize: true, attemptSynchronously: synchronous, skipThumbnail: fullSizeOnly, skipBlurIfLarge: isMain), attemptSynchronously: synchronous, dispatchOnDisplayLink: false)
        
        if let markup {
            if let videoNode = self.videoNode {
                self.videoContent = nil
                self.videoStartTimestamp = nil
                self.videoNode = nil
                          
                videoNode.removeFromSupernode()
            }
            self.statusPromise.set(.single(nil))
            self.statusDisposable.set(nil)
            
            let markupNode: AvatarVideoNode
            if let current = self.markupNode {
                markupNode = current
            } else {
                markupNode = AvatarVideoNode(context: self.context)
                self.insertSubnode(markupNode, belowSubnode: self.statusNode)
                self.markupNode = markupNode
            }
            markupNode.update(markup: markup, size: CGSize(width: 320.0, height: 320.0))
            markupNode.updateVisibility(self.isCentral ?? true)
           
            if !self.didSetReady {
                self.didSetReady = true
                self.isReady.set(.single(true))
            }
        } else if let video = videoRepresentations.last, let peerReference = PeerReference(self.peer._asPeer()) {
            let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: representations.map { $0.representation }, videoThumbnails: [], immediateThumbnailData: immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
            let videoContent = NativeVideoContent(id: .profileVideo(id, nil), userLocation: .other, fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.representation.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: fullSizeOnly, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, startTimestamp: video.representation.startTimestamp, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear, storeAfterDownload: nil)
            
            if videoContent.id != self.videoContent?.id {
                self.videoContent = videoContent
                self.videoStartTimestamp = video.representation.startTimestamp
                self.setupVideoPlayback()
            }
        } else {
            if let videoNode = self.videoNode {
                self.videoContent = nil
                self.videoStartTimestamp = nil
                self.videoNode = nil
                          
                videoNode.removeFromSupernode()
            }
            
            self.statusPromise.set(.single(nil))
            self.statusDisposable.set(nil)
            
            self.imageNode.imageUpdated = { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf.isReady.set(.single(true))
                }
            }
        }
    }
    
    func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        let imageSize = CGSize(width: min(size.width, size.height), height: min(size.width, size.height))
        let makeLayout = self.imageNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
        let _ = applyLayout()
        let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
        transition.updateFrame(node: self.imageNode, frame: imageFrame)
        
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: floor((size.width - 50.0) / 2.0), y: floor((size.height - 50.0) / 2.0)), size: CGSize(width: 50.0, height: 50.0)))
        
        if let videoNode = self.videoNode {
            videoNode.updateLayout(size: imageSize, transition: .immediate)
            videoNode.frame = imageFrame
        }
        if let markupNode = self.markupNode {
            markupNode.updateLayout(size: imageSize, cornerRadius: 0.0, transition: .immediate)
            markupNode.frame = imageFrame
        }
    }
}

private let fadeWidth: CGFloat = 70.0

private final class VariableBlurView: UIVisualEffectView {
    let maxBlurRadius: CGFloat
    
    var gradientMask: UIImage {
        didSet {
            if self.gradientMask !== oldValue {
                self.resetEffect()
            }
        }
    }
    
    init(gradientMask: UIImage, maxBlurRadius: CGFloat = 20) {
        self.gradientMask = gradientMask
        self.maxBlurRadius = maxBlurRadius
        
        super.init(effect: UIBlurEffect(style: .regular))

        self.resetEffect()

        if self.subviews.indices.contains(1) {
            let tintOverlayView = subviews[1]
            tintOverlayView.alpha = 0
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                self.resetEffect()
            }
        }
    }
    
    private func resetEffect() {
        let filterClassStringEncoded = "Q0FGaWx0ZXI="
        let filterClassString: String = {
            if
                let data = Data(base64Encoded: filterClassStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()
        let filterWithTypeStringEncoded = "ZmlsdGVyV2l0aFR5cGU6"
        let filterWithTypeString: String = {
            if
                let data = Data(base64Encoded: filterWithTypeStringEncoded),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }

            return ""
        }()

        let filterWithTypeSelector = Selector(filterWithTypeString)

        guard let filterClass = NSClassFromString(filterClassString) as AnyObject as? NSObjectProtocol else {
            return
        }

        guard filterClass.responds(to: filterWithTypeSelector) else {
            return
        }

        let variableBlur = filterClass.perform(filterWithTypeSelector, with: "variableBlur").takeUnretainedValue()

        guard let variableBlur = variableBlur as? NSObject else {
            return
        }
        
        guard let gradientImageRef = self.gradientMask.cgImage else {
            return
        }

        variableBlur.setValue(self.maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImageRef, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")
        variableBlur.setValue(UIScreenScale, forKey: "scale")
        
        let backdropLayer = self.subviews.first?.layer
        backdropLayer?.filters = [variableBlur]
    }
}

public final class PeerAvatarBottomShadowNode: ASDisplayNode {
    let backgroundNode: NavigationBackgroundNode
    private var backgroundView: VariableBlurView?
    private var currentBackgroundBlurImage: UIImage?
    
    private let backgroundGradientMaskLayer: SimpleGradientLayer
    public let imageView: UIImageView
    
    override init() {
        self.backgroundNode = NavigationBackgroundNode(color: .black, enableBlur: true)
        
        self.backgroundGradientMaskLayer = SimpleGradientLayer()
        //self.backgroundNode.layer.mask = self.backgroundGradientMaskLayer
        
        self.imageView = UIImageView()
        self.imageView.contentMode = .scaleToFill
        self.imageView.alpha = 0.8
        
        super.init()
        
        //self.backgroundColor = UIColor.blue.withAlphaComponent(0.5)
        
        self.backgroundGradientMaskLayer.type = .axial
        self.backgroundGradientMaskLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        self.backgroundGradientMaskLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
        
        let baseGradientAlpha: CGFloat = 1.0
        let numSteps = 8
        let firstStep = 1
        let firstLocation = 0.8
        self.backgroundGradientMaskLayer.colors = (0 ..< numSteps).map { i in
            if i < firstStep {
                return UIColor(white: 1.0, alpha: 1.0).cgColor
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                return UIColor(white: 1.0, alpha: baseGradientAlpha * value).cgColor
            }
        }
        self.backgroundGradientMaskLayer.locations = (0 ..< numSteps).map { i -> NSNumber in
            if i < firstStep {
                return 0.0 as NSNumber
            } else {
                let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                return (firstLocation + (1.0 - firstLocation) * step) as NSNumber
            }
        }
        
        self.backgroundNode.updateColor(color: UIColor(white: 0.0, alpha: 0.1), enableSaturation: false, forceKeepBlur: true, transition: .immediate)
        
        self.view.addSubview(self.imageView)
        //self.addSubnode(self.backgroundNode)
    }
    
    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: self.imageView, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
        transition.updateFrame(layer: self.backgroundGradientMaskLayer, frame: CGRect(origin: CGPoint(), size: size), beginWithCurrentState: true)
        self.backgroundNode.update(size: size, transition: transition)
        
        let backgroundBlurImage: UIImage
        if let currentBackgroundBlurImage = self.currentBackgroundBlurImage, currentBackgroundBlurImage.size.height == size.height {
            backgroundBlurImage = currentBackgroundBlurImage
        } else {
            let baseGradientAlpha: CGFloat = 0.5
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.5
            let colors = (0 ..< numSteps).map { i -> UIColor in
                if i < firstStep {
                    return UIColor(white: 1.0, alpha: 1.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = 1.0 - bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                }
            }
            let locations = (0 ..< numSteps).map { i -> CGFloat in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
            
            backgroundBlurImage = generateGradientImage(size: CGSize(width: 8.0, height: size.height), colors: colors.reversed(), locations: locations.reversed().map { 1.0 - $0 })!
        }
        if let backgroundView = self.backgroundView {
            if self.currentBackgroundBlurImage !== backgroundBlurImage {
                backgroundView.gradientMask = backgroundBlurImage
            }
            backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        } else {
            self.currentBackgroundBlurImage = backgroundBlurImage
            let backgroundView = VariableBlurView(gradientMask: backgroundBlurImage, maxBlurRadius: 15.0)
            backgroundView.layer.mask = self.backgroundGradientMaskLayer
            self.backgroundView = backgroundView
            self.view.addSubview(backgroundView)
            backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
}

public final class AvatarListContentNode: ASDisplayNode {
    final class View: UIView {
        override static var layerClass: AnyClass {
            return CAReplicatorLayer.self
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            let replicatorLayer = self.layer as! CAReplicatorLayer
            replicatorLayer.instanceCount = 2
            
            self.backgroundColor = nil
            self.isOpaque = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(size: CGSize) {
            var instanceTransform = CATransform3DIdentity
            instanceTransform = CATransform3DTranslate(instanceTransform, 0.0, (size.width - (size.height - size.width)) * 2.0 - 4.0, 0.0)
            instanceTransform = CATransform3DScale(instanceTransform, 1.0, -3.0, 1.0)
            
            let replicatorLayer = self.layer as! CAReplicatorLayer
            replicatorLayer.instanceTransform = instanceTransform
        }
        
        func updateIsInPinchMode(_ value: Bool) {
            let replicatorLayer = self.layer as! CAReplicatorLayer
            
            if value {
                replicatorLayer.instanceAlphaOffset = -1.0
                replicatorLayer.animate(from: 0.0 as NSNumber, to: -1.0 as NSNumber, keyPath: "instanceAlphaOffset", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
            } else {
                replicatorLayer.instanceAlphaOffset = 0.0
                replicatorLayer.animate(from: -1.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "instanceAlphaOffset", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
            }
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return View(frame: CGRect())
        })
    }
    
    public func update(size: CGSize) {
        (self.view as? View)?.update(size: size)
    }
    
    public func updateIsInPinchMode(_ value: Bool) {
        (self.view as? View)?.updateIsInPinchMode(value)
    }
}

public final class PeerInfoAvatarListContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let isSettings: Bool
    public var peer: EnginePeer?
    
    public let controlsContainerNode: ASDisplayNode
    public let controlsClippingNode: ASDisplayNode
    public let controlsClippingOffsetNode: ASDisplayNode
    public let topShadowNode: ASImageNode
    public let bottomShadowNode: PeerAvatarBottomShadowNode
    
    public var storyParams: (peer: EnginePeer, items: [EngineStoryItem], count: Int, hasUnseen: Bool, hasUnseenPrivate: Bool)?
    private var expandedStorySetIndicator: ComponentView<Empty>?
    public var expandedStorySetIndicatorTransitionView: (UIView, CGRect)? {
        if let setView = self.expandedStorySetIndicator?.view as? StorySetIndicatorComponent.View {
            return setView.transitionView
        } else {
            return nil
        }
    }
    
    public let contentNode: AvatarListContentNode
    let leftHighlightNode: ASDisplayNode
    let rightHighlightNode: ASDisplayNode
    var highlightedSide: Bool?
    public let stripContainerNode: ASDisplayNode
    public let highlightContainerNode: ASDisplayNode
    public let setByYouNode: ImmediateTextNode
    private let setByYouImageNode: ImageNode
    private var setByYouTapRecognizer: UITapGestureRecognizer?
    
    public private(set) var galleryEntries: [AvatarGalleryEntry] = []
    private var items: [PeerInfoAvatarListItem] = []
    private var itemNodes: [EngineMediaResource.Id: PeerInfoAvatarListItemNode] = [:]
    private var stripNodes: [ASImageNode] = []
    private var activeStripNode: ASImageNode
    private var loadingStripNode: PeerInfoAvatarListLoadingStripNode
    private let activeStripImage: UIImage
    private var appliedStripNodeCurrentIndex: Int?
    var currentIndex: Int = 0
    // MARK: Nicegram SaveAvatar
    private var currentItem: PeerInfoAvatarListItem? {
        return items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }
    public var presentController: ((ViewController) -> Void)?
    //
    private var transitionFraction: CGFloat = 0.0
    
    private var validLayout: CGSize?
    public var isCollapsing = false
    private var isExpanded = false
    
    public var firstFullSizeOnly = false
    public var customCenterTapAction: (() -> Void)?
    
    private let disposable = MetaDisposable()
    private let positionDisposable = MetaDisposable()
    private var initializedList = false
    private var ignoreNextProfilePhotoUpdate = false
    public var itemsUpdated: (([PeerInfoAvatarListItem]) -> Void)?
    public var currentIndexUpdated: (() -> Void)?
    
    public var openStories: (() -> Void)?
    
    public let isReady = Promise<Bool>()
    private var didSetReady = false
    
    public var currentItemNode: PeerInfoAvatarListItemNode? {
        if self.currentIndex >= 0 && self.currentIndex < self.items.count {
            return self.itemNodes[self.items[self.currentIndex].id]
        } else {
            return nil
        }
    }
    
    public var currentEntry: AvatarGalleryEntry? {
        if self.currentIndex >= 0 && self.currentIndex < self.galleryEntries.count {
            return self.galleryEntries[self.currentIndex]
        } else {
            return nil
        }
    }
    
    private var playerUpdateTimer: SwiftSignalKit.Timer?
    private var playerStatus: (MediaPlayerStatus?, Double?)? {
        didSet {
            if self.playerStatus?.0 != oldValue?.0 || self.playerStatus?.1 != oldValue?.1 {
                if let (playerStatus, _) = self.playerStatus, let status = playerStatus, case .playing = status.status {
                    self.ensureHasTimer()
                } else {
                    self.stopTimer()
                }
                self.updateStatus()
            }
        }
    }
    
    private func ensureHasTimer() {
        if self.playerUpdateTimer == nil {
            let timer = SwiftSignalKit.Timer(timeout: 0.016, repeat: true, completion: { [weak self] in
                self?.updateStatus()
                }, queue: Queue.mainQueue())
            self.playerUpdateTimer = timer
            timer.start()
        }
    }
    
    private var playbackProgress: CGFloat?
    private var loading: Bool = false
    private func updateStatus() {
        var position: CGFloat = 1.0
        var loading = false
        if let (status, videoStartTimestamp) = self.playerStatus, let playerStatus = status {
            var playerPosition: Double
            if case .buffering = playerStatus.status {
                loading = true
            }
            if !playerStatus.generationTimestamp.isZero, case .playing = playerStatus.status {
                playerPosition = playerStatus.timestamp + (CACurrentMediaTime() - playerStatus.generationTimestamp)
            } else {
                playerPosition = playerStatus.timestamp
            }
            
            if let videoStartTimestamp = videoStartTimestamp, false {
                playerPosition -= videoStartTimestamp
                if playerPosition < 0.0 {
                    playerPosition = playerStatus.duration + playerPosition
                }
            }
            
            if playerStatus.duration.isZero {
                position = 0.0
            } else {
                position = CGFloat(playerPosition / playerStatus.duration)
            }
        } else {
            self.playbackProgress = nil
        }
        
        if let size = self.validLayout {
            self.playbackProgress = position
            self.loading = loading
            self.updateStrips(size: size, itemsAdded: false, stripTransition: .animated(duration: 0.3, curve: .spring))
        }
    }
    
    private func stopTimer() {
        self.playerUpdateTimer?.invalidate()
        self.playerUpdateTimer = nil
    }
    
    public init(context: AccountContext, isSettings: Bool = false) {
        self.context = context
        self.isSettings = isSettings
        
        self.contentNode = AvatarListContentNode()
        
        self.leftHighlightNode = ASDisplayNode()
        self.leftHighlightNode.displaysAsynchronously = false
        self.leftHighlightNode.backgroundColor = generateImage(CGSize(width: fadeWidth, height: 24.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let topColor = UIColor(rgb: 0x000000, alpha: 0.1)
            let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }).flatMap { UIColor(patternImage: $0) }
        self.leftHighlightNode.alpha = 0.0
        
        self.rightHighlightNode = ASDisplayNode()
        self.rightHighlightNode.displaysAsynchronously = false
        self.rightHighlightNode.backgroundColor = generateImage(CGSize(width: fadeWidth, height: 24.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let topColor = UIColor(rgb: 0x000000, alpha: 0.1)
            let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
            
            var locations: [CGFloat] = [0.0, 1.0]
            let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: size.width, y: 0.0), end: CGPoint(x: 0.0, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }).flatMap { UIColor(patternImage: $0) }
        self.rightHighlightNode.alpha = 0.0
        
        self.stripContainerNode = ASDisplayNode()
        self.contentNode.addSubnode(self.stripContainerNode)
        self.activeStripImage = generateSmallHorizontalStretchableFilledCircleImage(diameter: 2.0, color: .white)!
        
        self.activeStripNode = ASImageNode()
        self.activeStripNode.image = self.activeStripImage
        
        self.loadingStripNode = PeerInfoAvatarListLoadingStripNode()
        self.loadingStripNode.imageNode.image = self.activeStripImage
        
        self.highlightContainerNode = ASDisplayNode()
        self.highlightContainerNode.addSubnode(self.leftHighlightNode)
        self.highlightContainerNode.addSubnode(self.rightHighlightNode)
        
        self.setByYouNode = ImmediateTextNode()
        self.setByYouNode.alpha = 0.0
        self.setByYouNode.isUserInteractionEnabled = false
        
        self.setByYouImageNode = ImageNode()
        self.setByYouImageNode.alpha = 0.0
        self.setByYouImageNode.isUserInteractionEnabled = false
        
        self.controlsContainerNode = ASDisplayNode()
        self.controlsContainerNode.isUserInteractionEnabled = false
        
        self.controlsClippingOffsetNode = ASDisplayNode()
        
        self.controlsClippingNode = ASDisplayNode()
        self.controlsClippingNode.isUserInteractionEnabled = false
        self.controlsClippingNode.clipsToBounds = true
        
        self.topShadowNode = ASImageNode()
        self.topShadowNode.displaysAsynchronously = false
        self.topShadowNode.displayWithoutProcessing = true
        self.topShadowNode.contentMode = .scaleToFill
        
        self.bottomShadowNode = PeerAvatarBottomShadowNode()
        
        do {
            let size = CGSize(width: 88.0, height: 88.0)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            if let context = UIGraphicsGetCurrentContext() {
                context.clip(to: CGRect(origin: CGPoint(), size: size))
                
                let topColor = UIColor(rgb: 0x000000, alpha: 0.4)
                let bottomColor = UIColor(rgb: 0x000000, alpha: 0.0)
                
                var locations: [CGFloat] = [0.0, 1.0]
                let colors: [CGColor] = [topColor.cgColor, bottomColor.cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let image = image {
                    self.topShadowNode.image = generateImage(image.size, contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.rotate(by: -CGFloat.pi / 2.0)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    })
                    self.bottomShadowNode.imageView.image = generateImage(image.size, contextGenerator: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                        context.rotate(by: CGFloat.pi / 2.0)
                        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                    })
                }
            }
        }
        
        super.init()
        
        //self.backgroundColor = .black
        
        self.addSubnode(self.contentNode)
        
        self.controlsContainerNode.addSubnode(self.highlightContainerNode)
        self.controlsContainerNode.addSubnode(self.topShadowNode)
        self.addSubnode(self.bottomShadowNode)
        self.controlsContainerNode.addSubnode(self.stripContainerNode)
        self.controlsClippingNode.addSubnode(self.controlsContainerNode)
        self.controlsClippingOffsetNode.addSubnode(self.controlsClippingNode)
        self.addSubnode(self.setByYouNode)
        self.addSubnode(self.setByYouImageNode)
        
        self.view.disablesInteractiveTransitionGestureRecognizerNow = { [weak self] in
            guard let strongSelf = self else {
                return false
            }
            return strongSelf.currentIndex != 0
        }
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        
        // MARK: Nicegram SaveAvatar, copied from PeerAvatarImageGalleryItemNode
        let avatarListLongTapGesture = ContextGesture()
        avatarListLongTapGesture.activated = { [weak self] _, _ in
            guard let self = self,
                  let item = self.currentItem else { return }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with{$0}
            
            let representations = item.representations
            let videoRepresentations = item.videoRepresentations
            
            let subject: ShareControllerSubject
            var actionCompletionText: String?
            if let video = videoRepresentations.last, let peer = self.peer, let peerReference = PeerReference(peer._asPeer()) {
                let videoFileReference = FileMediaReference.avatarList(peer: peerReference, media: TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.representation.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.representation.dimensions, flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: []))
                subject = .media(videoFileReference.abstract, nil)
                actionCompletionText = presentationData.strings.Gallery_VideoSaved
            } else {
                subject = .image(representations)
                actionCompletionText = presentationData.strings.Gallery_ImageSaved
            }
            
            var forceTheme: PresentationTheme?
            if !presentationData.theme.overallDarkAppearance {
                forceTheme = defaultDarkColorPresentationTheme
            }
            
            let shareController = ShareController(context: self.context, subject: subject, preferredAction: .saveToCameraRoll, forceTheme: forceTheme)
            shareController.actionCompleted = { [weak self] in
                if let self = self, let actionCompletionText = actionCompletionText {
                    self.presentController?(UndoOverlayController(presentationData: presentationData, content: .mediaSaved(text: actionCompletionText), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return true }))
                }
            }
            self.presentController?(shareController)
        }
        self.view.addGestureRecognizer(avatarListLongTapGesture)
        //
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .keepWithSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self, let size = strongSelf.validLayout else {
                return
            }
            var highlightedSide: Bool?
            if let point = point {
                if point.x < size.width * 1.0 / 5.0 {
                    if strongSelf.items.count > 1 {
                        highlightedSide = false
                    }
                } else {
                    if strongSelf.items.count > 1 {
                        highlightedSide = true
                    }
                }
            }
            if strongSelf.highlightedSide != highlightedSide {
                strongSelf.highlightedSide = highlightedSide
                let leftAlpha: CGFloat
                let rightAlpha: CGFloat
                if let highlightedSide = highlightedSide {
                    leftAlpha = highlightedSide ? 0.0 : 1.0
                    rightAlpha = highlightedSide ? 1.0 : 0.0
                } else {
                    leftAlpha = 0.0
                    rightAlpha = 0.0
                }
                if strongSelf.leftHighlightNode.alpha != leftAlpha {
                    strongSelf.leftHighlightNode.alpha = leftAlpha
                    if leftAlpha.isZero {
                        strongSelf.leftHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.leftHighlightNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
                if strongSelf.rightHighlightNode.alpha != rightAlpha {
                    strongSelf.rightHighlightNode.alpha = rightAlpha
                    if rightAlpha.isZero {
                        strongSelf.rightHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.16, timingFunction: kCAMediaTimingFunctionSpring)
                    } else {
                        strongSelf.rightHighlightNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)
                    }
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    deinit {
        self.disposable.dispose()
        self.positionDisposable.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let setByYouTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.setByYouTapped))
        self.setByYouNode.isUserInteractionEnabled = true
        self.setByYouNode.view.addGestureRecognizer(setByYouTapRecognizer)
        self.setByYouTapRecognizer = setByYouTapRecognizer
    }
    
    @objc private func setByYouTapped() {
        self.selectLastItem()
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.isExpanded, let expandedStorySetIndicatorView = self.expandedStorySetIndicator?.view {
            if let result = expandedStorySetIndicatorView.hitTest(self.view.convert(point, to: expandedStorySetIndicatorView), with: event) {
                return result
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    public func selectFirstItem() {
        let previousIndex = self.currentIndex
        self.currentIndex = 0
        if self.currentIndex != previousIndex {
            self.currentIndexUpdated?()
        }
        if let size = self.validLayout {
            self.updateItems(size: size, transition: .immediate, stripTransition: .immediate)
        }
    }
    
    public func selectLastItem() {
        let previousIndex = self.currentIndex
        self.currentIndex = self.items.count - 1
        if self.currentIndex != previousIndex {
            self.currentIndexUpdated?()
        }
        if let size = self.validLayout {
            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
        }
    }
    
    public func updateEntryIsHidden(entry: AvatarGalleryEntry?) {
        if let entry = entry, let index = self.galleryEntries.firstIndex(of: entry) {
            self.currentItemNode?.isHidden = index == self.currentIndex
        } else {
            self.currentItemNode?.isHidden = false
        }
    }
    
    public var offsetLocation = false
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                if let size = self.validLayout, case .tap = gesture {
                    var location = location
                    if self.offsetLocation {
                        location.x += size.width / 2.0
                    }
                    if location.x < size.width * 1.0 / 5.0 {
                        if self.currentIndex != 0 {
                            let previousIndex = self.currentIndex
                            self.currentIndex -= 1
                            if self.currentIndex != previousIndex {
                                self.currentIndexUpdated?()
                            }
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        } else if self.items.count > 1 {
                            let previousIndex = self.currentIndex
                            self.currentIndex = self.items.count - 1
                            if self.currentIndex != previousIndex {
                                self.currentIndexUpdated?()
                            }
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        }
                    } else {
                        if let customAction = self.customCenterTapAction, location.x < size.width - size.width * 1.0 / 5.0 {
                            customAction()
                            return
                        }
                        if self.currentIndex < self.items.count - 1 {
                            let previousIndex = self.currentIndex
                            self.currentIndex += 1
                            if self.currentIndex != previousIndex {
                                self.currentIndexUpdated?()
                            }
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        } else if self.items.count > 1 {
                            let previousIndex = self.currentIndex
                            self.currentIndex = 0
                            if self.currentIndex != previousIndex {
                                self.currentIndexUpdated?()
                            }
                            self.updateItems(size: size, transition: .immediate, stripTransition: .animated(duration: 0.3, curve: .spring), synchronous: true)
                        }
                    }
                }
            }
        default:
            break
        }
    }
    
    private var pageChangedByPan = false
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            let translation = recognizer.translation(in: self.view)
            var transitionFraction = translation.x / self.bounds.width
            if self.currentIndex <= 0 {
                transitionFraction = min(0.0, transitionFraction)
            }
            if self.currentIndex >= self.items.count - 1 {
                transitionFraction = max(0.0, transitionFraction)
            }
            self.transitionFraction = transitionFraction
            if let size = self.validLayout {
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring), stripTransition: .animated(duration: 0.3, curve: .spring))
            }
        case .cancelled, .ended:
            let velocity = recognizer.velocity(in: self.view)
            var directionIsToRight: Bool?
            if abs(velocity.x) > 10.0 {
                directionIsToRight = velocity.x < 0.0
            } else if abs(self.transitionFraction) > 0.5 {
                directionIsToRight = self.transitionFraction < 0.0
            }
            var updatedIndex = self.currentIndex
            if let directionIsToRight = directionIsToRight {
                if directionIsToRight {
                    updatedIndex = min(updatedIndex + 1, self.items.count - 1)
                } else {
                    updatedIndex = max(updatedIndex - 1, 0)
                }
            }
            let previousIndex = self.currentIndex
            self.currentIndex = updatedIndex
            if self.currentIndex != previousIndex {
                self.pageChangedByPan = true
                self.currentIndexUpdated?()
            }
            self.transitionFraction = 0.0
            if let size = self.validLayout {
                self.updateItems(size: size, transition: .animated(duration: 0.3, curve: .spring), stripTransition: .animated(duration: 0.3, curve: .spring))
                self.pageChangedByPan = false
            }
        default:
            break
        }
    }
    
    func setMainItem(_ item: PeerInfoAvatarListItem) {
        guard case let .image(imageReference, _, _, _, _, _) = item else {
            return
        }
        var items: [PeerInfoAvatarListItem] = []
        var entries: [AvatarGalleryEntry] = []
        for entry in self.galleryEntries {
            switch entry {
                case let .topImage(representations, videoRepresentations, _, _, immediateThumbnailData, _):
                    entries.append(entry)
                    items.append(.topImage(representations, videoRepresentations, immediateThumbnailData))
                case let .image(_, reference, representations, videoRepresentations, _, _, _, _, immediateThumbnailData, _, isFallback, emojiMarkup):
                    if representations.isEmpty {
                        continue
                    }
                    if imageReference == reference {
                        entries.insert(entry, at: 0)
                        items.insert(.image(reference, representations, videoRepresentations, immediateThumbnailData, isFallback, emojiMarkup), at: 0)
                    } else {
                        entries.append(entry)
                        items.append(.image(reference, representations, videoRepresentations, immediateThumbnailData, isFallback, emojiMarkup))
                    }
            }
        }
        self.galleryEntries = normalizeEntries(entries)
        self.items = items
        self.itemsUpdated?(items)
        let previousIndex = self.currentIndex
        self.currentIndex = 0
        if self.currentIndex != previousIndex {
            self.currentIndexUpdated?()
        }
        self.ignoreNextProfilePhotoUpdate = true
        if let size = self.validLayout {
            self.updateItems(size: size, update: true, transition: .immediate, stripTransition: .immediate, synchronous: true)
        }
    }
    
    public func deleteItem(_ item: PeerInfoAvatarListItem) -> Bool {
        guard case let .image(imageReference, _, _, _, _, _) = item else {
            return false
        }
                
        var items: [PeerInfoAvatarListItem] = []
        var entries: [AvatarGalleryEntry] = []
        let previousIndex = self.currentIndex
        
        var index = 0
        var deletedIndex: Int?
        for entry in self.galleryEntries {
            switch entry {
                case let .topImage(representations, videoRepresentations, _, _, immediateThumbnailData, _):
                    entries.append(entry)
                    items.append(.topImage(representations, videoRepresentations, immediateThumbnailData))
                case let .image(_, reference, representations, videoRepresentations, _, _, _, _, immediateThumbnailData, _, isFallback, emojiMarkup):
                    if representations.isEmpty {
                        continue
                    }
                    if imageReference != reference {
                        entries.append(entry)
                        items.append(.image(reference, representations, videoRepresentations, immediateThumbnailData, isFallback, emojiMarkup))
                    } else {
                        deletedIndex = index
                    }
            }
            index += 1
        }
        
        switch self.peer {
        case .legacyGroup, .channel:
            if deletedIndex == 0 {
                self.galleryEntries = []
                self.items = []
                self.itemsUpdated?([])
                self.currentIndex = 0
                if let size = self.validLayout {
                    self.updateItems(size: size, update: true, transition: .immediate, stripTransition: .immediate, synchronous: true)
                }
                return true
            }
        default:
            break
        }
        
        self.galleryEntries = normalizeEntries(entries)
        self.items = items
        self.itemsUpdated?(items)
        self.currentIndex = max(0, previousIndex - 1)
        if self.currentIndex != previousIndex {
            self.currentIndexUpdated?()
        }
        self.ignoreNextProfilePhotoUpdate = true
        if let size = self.validLayout {
            self.updateItems(size: size, update: true, transition: .immediate, stripTransition: .immediate, synchronous: true)
        }
        
        return items.count == 0
    }
    
    private var additionalEntryProgress: Signal<Float?, NoError>? = nil
    public func update(size: CGSize, peer: EnginePeer?, customNode: ASDisplayNode? = nil, additionalEntry: Signal<(TelegramMediaImageRepresentation, Float)?, NoError> = .single(nil), isExpanded: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        let previousExpanded = self.isExpanded
        self.isExpanded = isExpanded
        if !isExpanded && previousExpanded {
            self.isCollapsing = true
        }
        self.leftHighlightNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: fadeWidth, height: size.height))
        self.rightHighlightNode.frame = CGRect(origin: CGPoint(x: size.width - fadeWidth, y: 0.0), size: CGSize(width: fadeWidth, height: size.height))
        
        if let peer = peer, !self.initializedList {
            self.initializedList = true
                    
            let entry = additionalEntry
            |> map { representation -> AvatarGalleryEntry? in
                return representation.flatMap { AvatarGalleryEntry(representation: $0.0, peer: peer) }
            }
            
            self.disposable.set(combineLatest(queue: Queue.mainQueue(), peerInfoProfilePhotosWithCache(context: self.context, peerId: peer.id), entry).startStrict(next: { [weak self] completeAndEntries, entry in
                guard let strongSelf = self else {
                    return
                }
                
                var (complete, entries) = completeAndEntries
                
                if strongSelf.galleryEntries.count > 1, entries.count == 1 && !complete {
                    return
                }
                
                var synchronous = false
                if !strongSelf.galleryEntries.isEmpty, let updated = entries.first, case let .image(mediaId, reference, _, videoRepresentations, peer, index, indexData, messageId, thumbnailData, caption, _, emojiMarkup) = updated, !videoRepresentations.isEmpty, let previous = strongSelf.galleryEntries.first, case let .topImage(representations, _, _, _, _, _) = previous {
                    let firstEntry = AvatarGalleryEntry.image(mediaId, reference, representations, videoRepresentations, peer, index, indexData, messageId, thumbnailData, caption, false, emojiMarkup)
                    entries.remove(at: 0)
                    entries.insert(firstEntry, at: 0)
                    synchronous = true
                }
                
                if let entry = entry {
                    entries.insert(entry, at: 0)
                    
                    strongSelf.additionalEntryProgress = additionalEntry
                    |> map { value -> Float? in
                        return value?.1
                    }
                }
                
                if strongSelf.ignoreNextProfilePhotoUpdate {
                    if entries.count == 1, let first = entries.first, case .topImage = first {
                        return
                    } else {
                        strongSelf.ignoreNextProfilePhotoUpdate = false
                        synchronous = true
                    }
                }
                
                var items: [PeerInfoAvatarListItem] = []
                if let customNode = customNode {
                    items.append(.custom(customNode))
                }
                for entry in entries {
                    if let item = PeerInfoAvatarListItem(entry: entry) {
                        items.append(item)
                    }
                }
                strongSelf.galleryEntries = entries
                strongSelf.items = items
                strongSelf.itemsUpdated?(items)
                if let size = strongSelf.validLayout {
                    strongSelf.updateItems(size: size, update: true, transition: .immediate, stripTransition: .immediate, synchronous: synchronous)
                }
                if items.isEmpty {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf.isReady.set(.single(true))
                    }
                }
            }))
        }
        self.updateItems(size: size, transition: transition, stripTransition: transition)
        
        if let storyParams = self.storyParams {
            var indicatorTransition = ComponentTransition(transition)
            let expandedStorySetIndicator: ComponentView<Empty>
            if let current = self.expandedStorySetIndicator {
                expandedStorySetIndicator = current
            } else {
                indicatorTransition = .immediate
                expandedStorySetIndicator = ComponentView()
                self.expandedStorySetIndicator = expandedStorySetIndicator
            }
            
            let expandedStorySetSize = expandedStorySetIndicator.update(
                transition: indicatorTransition,
                component: AnyComponent(StorySetIndicatorComponent(
                    context: self.context,
                    strings: self.context.sharedContext.currentPresentationData.with({ $0 }).strings,
                    items: storyParams.items.map { StorySetIndicatorComponent.Item(storyItem: $0, peer: storyParams.peer) },
                    displayAvatars: false,
                    hasUnseen: storyParams.hasUnseen,
                    hasUnseenPrivate: storyParams.hasUnseenPrivate,
                    totalCount: storyParams.count,
                    theme: defaultDarkPresentationTheme,
                    action: { [weak self] in
                        self?.openStories?()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: 300.0, height: 100.0)
            )
            let expandedStorySetFrame = CGRect(origin: CGPoint(x: floor((size.width - expandedStorySetSize.width) * 0.5), y: 10.0), size: expandedStorySetSize)
            if let expandedStorySetIndicatorView = expandedStorySetIndicator.view {
                if expandedStorySetIndicatorView.superview == nil {
                    self.stripContainerNode.view.addSubview(expandedStorySetIndicatorView)
                }
                indicatorTransition.setFrame(view: expandedStorySetIndicatorView, frame: expandedStorySetFrame)
            }
        } else if let expandedStorySetIndicator = self.expandedStorySetIndicator {
            self.expandedStorySetIndicator = nil
            expandedStorySetIndicator.view?.removeFromSuperview()
        }
    }
    
    private func updateStrips(size: CGSize, itemsAdded: Bool, stripTransition: ContainedViewLayoutTransition) {
        let hadOneStripNode = self.stripNodes.count == 1
        if self.stripNodes.count != self.items.count {
            if self.stripNodes.count < self.items.count {
                for _ in 0 ..< self.items.count - self.stripNodes.count {
                    let stripNode = ASImageNode()
                    stripNode.displaysAsynchronously = false
                    stripNode.displayWithoutProcessing = true
                    stripNode.image = self.activeStripImage
                    stripNode.alpha = 0.2
                    self.stripNodes.append(stripNode)
                    self.stripContainerNode.addSubnode(stripNode)
                }
            } else {
                for i in (self.items.count ..< self.stripNodes.count).reversed() {
                    self.stripNodes[i].removeFromSupernode()
                    self.stripNodes.remove(at: i)
                }
            }
            self.stripContainerNode.addSubnode(self.activeStripNode)
            self.stripContainerNode.addSubnode(self.loadingStripNode)
        }
        if self.appliedStripNodeCurrentIndex != self.currentIndex || itemsAdded {
            if !self.itemNodes.isEmpty {
                self.appliedStripNodeCurrentIndex = self.currentIndex
            }
            
            if let currentItemNode = self.currentItemNode {
                self.positionDisposable.set((currentItemNode.mediaStatus
                    |> deliverOnMainQueue).startStrict(next: { [weak self] statusAndVideoStartTimestamp in
                        if let strongSelf = self {
                            strongSelf.playerStatus = statusAndVideoStartTimestamp
                        }
                    }))
            } else {
                self.positionDisposable.set(nil)
            }
        }
        if hadOneStripNode && self.stripNodes.count > 1 {
            self.stripContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        }
        let stripInset: CGFloat = 8.0
        let stripSpacing: CGFloat = 4.0
        let stripWidth: CGFloat = max(5.0, floorToScreenPixels((size.width - stripInset * 2.0 - stripSpacing * CGFloat(self.stripNodes.count - 1)) / CGFloat(self.stripNodes.count)))
        let currentStripMinX = stripInset + CGFloat(self.currentIndex) * (stripWidth + stripSpacing)
        let currentStripMidX = floorToScreenPixels(currentStripMinX + stripWidth / 2.0)
        let lastStripMaxX = stripInset + CGFloat(self.stripNodes.count - 1) * (stripWidth + stripSpacing) + stripWidth
        let stripOffset: CGFloat = min(0.0, max(size.width - stripInset - lastStripMaxX, size.width / 2.0 - currentStripMidX))
        for i in 0 ..< self.stripNodes.count {
            let stripX: CGFloat = stripInset + CGFloat(i) * (stripWidth + stripSpacing)
            if i == 0 && self.stripNodes.count == 1 {
                self.stripNodes[i].isHidden = true
            } else {
                self.stripNodes[i].isHidden = false
            }
            let stripFrame = CGRect(origin: CGPoint(x: stripOffset + stripX, y: 0.0), size: CGSize(width: stripWidth + 1.0, height: 2.0))
            stripTransition.updateFrame(node: self.stripNodes[i], frame: stripFrame)
        }
        
        if self.currentIndex >= 0 && self.currentIndex < self.stripNodes.count {
            var frame = self.stripNodes[self.currentIndex].frame
            stripTransition.updateFrame(node: self.loadingStripNode, frame: frame)
            if let playbackProgress = self.playbackProgress {
                frame.size.width = max(frame.size.height, frame.size.width * playbackProgress)
            }
            stripTransition.updateFrameAdditive(node: self.activeStripNode, frame: frame)
            stripTransition.updateAlpha(node: self.activeStripNode, alpha: self.loading ? 0.0 : 1.0)
            stripTransition.updateAlpha(node: self.loadingStripNode, alpha: self.loading ? 1.0 : 0.0)
            
            self.activeStripNode.isHidden = self.stripNodes.count < 2
            self.loadingStripNode.isHidden = self.stripNodes.count < 2 || !self.loading
        }
    }
    
    public var updateCustomItemsOnlySynchronously = false
    
    private func updateItems(size: CGSize, update: Bool = false, transition: ContainedViewLayoutTransition, stripTransition: ContainedViewLayoutTransition, synchronous: Bool = false) {
        var validIds: [EngineMediaResource.Id] = []
        var addedItemNodesForAdditiveTransition: [PeerInfoAvatarListItemNode] = []
        var additiveTransitionOffset: CGFloat = 0.0
        var itemsAdded = false
        if self.currentIndex >= 0 && self.currentIndex < self.items.count {
            let preloadSpan: Int = 2
            for i in max(0, self.currentIndex - preloadSpan) ... min(self.currentIndex + preloadSpan, self.items.count - 1) {
                if self.items[i].representations.isEmpty {
                    continue
                }
                validIds.append(self.items[i].id)
                var itemNode: PeerInfoAvatarListItemNode?
                var wasAdded = false
                if let current = self.itemNodes[self.items[i].id] {
                    itemNode = current
                    if update {
                        var synchronous = synchronous && i == self.currentIndex
                        if case .custom = self.items[i], self.updateCustomItemsOnlySynchronously {
                            synchronous = true
                        }
                        current.setup(item: self.items[i], isMain: i == 0, synchronous: synchronous && i == self.currentIndex, fullSizeOnly: self.firstFullSizeOnly && i == 0)
                    }
                } else if let peer = self.peer {
                    wasAdded = true
                    let addedItemNode = PeerInfoAvatarListItemNode(context: self.context, peer: peer)
                    itemNode = addedItemNode
                    addedItemNode.setup(item: self.items[i], isMain: i == 0, progress: i == 0 ? self.additionalEntryProgress : nil, synchronous: (i == 0 && i == self.currentIndex) || (synchronous && i == self.currentIndex), fullSizeOnly: self.firstFullSizeOnly && i == 0)
                    self.itemNodes[self.items[i].id] = addedItemNode
                    self.contentNode.addSubnode(addedItemNode)
                }
                if let itemNode = itemNode {
                    itemNode.delayCentralityLose = self.pageChangedByPan
                    itemNode.isCentral = i == self.currentIndex
                    itemNode.delayCentralityLose = false
                    
                    let indexOffset = CGFloat(i - self.currentIndex)
                    var itemFrame = CGRect(origin: CGPoint(x: indexOffset * size.width + self.transitionFraction * size.width - size.width / 2.0, y: -size.height / 2.0), size: size)
                    itemFrame.origin.y -= (size.height - size.width) * 0.5
                    
                    if wasAdded {
                        itemsAdded = true
                        addedItemNodesForAdditiveTransition.append(itemNode)
                        itemNode.frame = itemFrame
                        itemNode.update(size: size, transition: .immediate)
                    } else {
                        additiveTransitionOffset = itemNode.frame.minX - itemFrame.minX
                        transition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.update(size: size, transition: .immediate)
                    }
                }
            }
        }
        
        if !self.items.isEmpty, self.currentIndex >= 0 && self.currentIndex < self.items.count {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let currentItem = self.items[self.currentIndex]
            
            var photoTitle: String?
            var hasLink = false
            var fallbackImageSignal: Signal<UIImage?, NoError>?
            if let representation = currentItem.representations.first?.representation, representation.isPersonal {
                photoTitle = representation.hasVideo ? presentationData.strings.UserInfo_CustomVideo : presentationData.strings.UserInfo_CustomPhoto
            } else if currentItem.isFallback, let representation = currentItem.representations.first?.representation, self.isSettings {
                photoTitle = representation.hasVideo ? presentationData.strings.UserInfo_PublicVideo : presentationData.strings.UserInfo_PublicPhoto
            } else if self.currentIndex == 0, let lastItem = self.items.last, lastItem.isFallback, let representation = lastItem.representations.first?.representation, self.isSettings {
                photoTitle = representation.hasVideo ? presentationData.strings.UserInfo_PublicVideo : presentationData.strings.UserInfo_PublicPhoto
                hasLink = true
                if let peer = self.peer {
                    fallbackImageSignal = peerAvatarCompleteImage(account: self.context.account, peer: peer, forceProvidedRepresentation: true, representation: representation, size: CGSize(width: 28.0, height: 28.0))
                }
            }
                        
            if let photoTitle = photoTitle {
                transition.updateAlpha(node: self.setByYouNode, alpha: 0.7)
                self.setByYouNode.attributedText = NSAttributedString(string: photoTitle, font: Font.regular(12.0), textColor: UIColor.white)
                let setByYouSize = self.setByYouNode.updateLayout(size)
                self.setByYouNode.frame = CGRect(origin: CGPoint(x: size.width - setByYouSize.width - 14.0, y: size.height - setByYouSize.height - 40.0), size: setByYouSize)
                self.setByYouNode.isUserInteractionEnabled = hasLink
            } else {
                transition.updateAlpha(node: self.setByYouNode, alpha: 0.0)
                self.setByYouNode.isUserInteractionEnabled = false
            }
            
            if let fallbackImageSignal = fallbackImageSignal {
                self.setByYouImageNode.setSignal(fallbackImageSignal)
                transition.updateAlpha(node: self.setByYouImageNode, alpha: 1.0)
                self.setByYouImageNode.frame = CGRect(origin: CGPoint(x: self.setByYouNode.frame.minX - 32.0, y: self.setByYouNode.frame.minY - 7.0), size: CGSize(width: 28.0, height: 28.0))
            } else {
                transition.updateAlpha(node: self.setByYouImageNode, alpha: 0.0)
            }
        }
        
        for itemNode in addedItemNodesForAdditiveTransition {
            transition.animatePositionAdditive(node: itemNode, offset: CGPoint(x: additiveTransitionOffset, y: 0.0))
        }
        var removeIds: [EngineMediaResource.Id] = []
        for (id, _) in self.itemNodes {
            if !validIds.contains(id) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes.removeValue(forKey: id) {
                itemNode.removeFromSupernode()
            }
        }
        
        self.updateStrips(size: size, itemsAdded: itemsAdded, stripTransition: stripTransition)
        
        if let item = self.items.first, let itemNode = self.itemNodes[item.id] {
            if !self.didSetReady {
                self.didSetReady = true
                self.isReady.set(itemNode.isReady.get())
            }
        }
    }
}
