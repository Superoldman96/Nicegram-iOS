import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum RecentPeers {
    case peers([Peer])
    case disabled
}

func cachedRecentPeersEntryId() -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 101, key: CachedRecentPeers.cacheKey())
}

func cachedRecentAppsEntryId() -> ItemCacheEntryId {
    return ItemCacheEntryId(collectionId: 102, key: CachedRecentPeers.cacheKey())
}

public func _internal_recentPeers(accountPeerId: EnginePeer.Id, postbox: Postbox) -> Signal<RecentPeers, NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentPeersEntryId())
    return postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<RecentPeers, NoError> in
        if let value = (views.views[key] as? CachedItemView)?.value?.get(CachedRecentPeers.self) {
            if value.enabled {
                return postbox.multiplePeersView(value.ids)
                |> map { view -> RecentPeers in
                    var peers: [Peer] = []
                    for id in value.ids {
                        if let peer = view.peers[id], id != accountPeerId {
                            peers.append(peer)
                        }
                    }
                    return .peers(peers)
                }
            } else {
                return .single(.disabled)
            }
        } else {
            return .single(.peers([]))
        }
    }
}

public func _internal_getRecentPeers(transaction: Transaction) -> [PeerId] {
    guard let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId())?.get(CachedRecentPeers.self) else {
        return []
    }
    return entry.ids
}

public func _internal_managedUpdatedRecentPeers(accountPeerId: PeerId, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentPeersEntryId())
    let peersEnabled = postbox.combinedView(keys: [key])
    |> map { views -> Bool in
        if let value = (views.views[key] as? CachedItemView)?.value?.get(CachedRecentPeers.self) {
            return value.enabled
        } else {
            return true
        }
    }
    |> distinctUntilChanged
    
    let updateOnce =
        network.request(Api.functions.contacts.getTopPeers(flags: 1 << 0, offset: 0, limit: 50, hash: 0))
    |> `catch` { _ -> Signal<Api.contacts.TopPeers, NoError> in
        return .complete()
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Void in
            switch result {
                case let .topPeers(_, _, users):
                    let parsedPeers = AccumulatedPeers(users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)

                    if let entry = CodableEntry(CachedRecentPeers(enabled: true, ids: users.map { $0.peerId })) {
                        transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: entry)
                    }
                case .topPeersNotModified:
                    break
                case .topPeersDisabled:
                    if let entry = CodableEntry(CachedRecentPeers(enabled: false, ids: [])) {
                        transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: entry)
                    }
            }
        }
    }
    
    return peersEnabled |> mapToSignal { _ -> Signal<Void, NoError> in
        return updateOnce
    }
}

func _internal_removeRecentPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        guard let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId())?.get(CachedRecentPeers.self) else {
            return .complete()
        }
        
        if let index = entry.ids.firstIndex(of: peerId) {
            var updatedIds = entry.ids
            updatedIds.remove(at: index)
            if let entry = CodableEntry(CachedRecentPeers(enabled: entry.enabled, ids: updatedIds)) {
                transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: entry)
            }
        }
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.contacts.resetTopPeerRating(category: .topPeerCategoryCorrespondents, peer: apiPeer))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

func _internal_updateRecentPeersEnabled(postbox: Postbox, network: Network, enabled: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        var currentValue = true
        if let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId())?.get(CachedRecentPeers.self) {
            currentValue = entry.enabled
        }
        
        if currentValue == enabled {
            return .complete()
        }
        
        return network.request(Api.functions.contacts.toggleTopPeers(enabled: enabled ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                if !enabled {
                    if let entry = CodableEntry(CachedRecentPeers(enabled: false, ids: [])) {
                        transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: entry)
                    }
                } else {
                    let entry = transaction.retrieveItemCacheEntry(id: cachedRecentPeersEntryId())?.get(CachedRecentPeers.self)
                    if let codableEntry = CodableEntry(CachedRecentPeers(enabled: true, ids: entry?.ids ?? [])) {
                        transaction.putItemCacheEntry(id: cachedRecentPeersEntryId(), entry: codableEntry)
                    }
                }
            }
        }
    } |> switchToLatest
}

func _internal_managedRecentlyUsedInlineBots(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    let remotePeers = network.request(Api.functions.contacts.getTopPeers(flags: 1 << 2, offset: 0, limit: 16, hash: 0))
    |> retryRequestIfNotFrozen
    |> map { result -> (AccumulatedPeers, [(PeerId, Double)])? in
        switch result {
        case .topPeersDisabled:
            break
        case let .topPeers(categories, _, users):
            let parsedPeers = AccumulatedPeers(users: users)
            
            var peersWithRating: [(PeerId, Double)] = []
            for category in categories {
                switch category {
                case let .topPeerCategoryPeers(_, _, topPeers):
                    for topPeer in topPeers {
                        switch topPeer {
                        case let .topPeer(apiPeer, rating):
                            peersWithRating.append((apiPeer.peerId, rating))
                        }
                    }
                }
            }
            return (parsedPeers, peersWithRating)
        case .topPeersNotModified:
            break
        default:
            break
        }
        return (AccumulatedPeers(), [])
    }
    
    let updatedRemotePeers = remotePeers
    |> mapToSignal { peersAndPresences -> Signal<Void, NoError> in
        if let (parsedPeers, peersWithRating) = peersAndPresences {
            return postbox.transaction { transaction -> Void in
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                let sortedPeersWithRating = peersWithRating.sorted(by: { $0.1 > $1.1 })
                
                transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, items: sortedPeersWithRating.compactMap { (peerId, rating) in
                    if let entry = CodableEntry(RecentPeerItem(rating: rating)) {
                        return OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: entry)
                    } else {
                        return nil
                    }
                })
            }
        } else {
            return .complete()
        }
    }
    
    return updatedRemotePeers
}

func _internal_addRecentlyUsedInlineBot(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        var maxRating = 1.0
        for entry in transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots) {
            if let contents = entry.contents.get(RecentPeerItem.self) {
                maxRating = max(maxRating, contents.rating)
            }
        }
        if let entry = CodableEntry(RecentPeerItem(rating: maxRating)) {
            transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, item: OrderedItemListEntry(id: RecentPeerItemId(peerId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
        }
    }
}

func _internal_recentlyUsedInlineBots(postbox: Postbox) -> Signal<[(Peer, Double)], NoError> {
    return postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)])
        |> take(1)
        |> mapToSignal { view -> Signal<[(Peer, Double)], NoError> in
            return postbox.transaction { transaction -> [(Peer, Double)] in
                var peers: [(Peer, Double)] = []
                if let view = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentInlineBots)] as? OrderedItemListView {
                    for item in view.items {
                        let peerId = RecentPeerItemId(item.id).peerId
                        if let peer = transaction.getPeer(peerId), let contents = item.contents.get(RecentPeerItem.self) {
                            peers.append((peer, contents.rating))
                        }
                    }
                }
                return peers
            }
    }
}

func _internal_removeRecentlyUsedInlineBot(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        transaction.removeOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentInlineBots, itemId: RecentPeerItemId(peerId).rawValue)
        
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.contacts.resetTopPeerRating(category: .topPeerCategoryBotsInline, peer: apiPeer))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func _internal_recentApps(accountPeerId: PeerId, postbox: Postbox) -> Signal<[EnginePeer.Id], NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentAppsEntryId())
    return postbox.combinedView(keys: [key])
    |> mapToSignal { views -> Signal<[EnginePeer.Id], NoError> in
        if let value = (views.views[key] as? CachedItemView)?.value?.get(CachedRecentPeers.self) {
            return .single(value.ids)
        } else {
            return .single([])
        }
    }
}

public func _internal_managedUpdatedRecentApps(accountPeerId: PeerId, postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let key = PostboxViewKey.cachedItem(cachedRecentAppsEntryId())
    let peersEnabled = postbox.combinedView(keys: [key])
    |> map { views -> Bool in
        if let value = (views.views[key] as? CachedItemView)?.value?.get(CachedRecentPeers.self) {
            return value.enabled
        } else {
            return true
        }
    }
    |> distinctUntilChanged
    
    let updateOnce =
        network.request(Api.functions.contacts.getTopPeers(flags: 1 << 16, offset: 0, limit: 50, hash: 0))
    |> `catch` { _ -> Signal<Api.contacts.TopPeers, NoError> in
        return .complete()
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        return postbox.transaction { transaction -> Void in
            switch result {
            case let .topPeers(_, _, users):
                let parsedPeers = AccumulatedPeers(users: users)
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                
                if let entry = CodableEntry(CachedRecentPeers(enabled: true, ids: users.map { $0.peerId })) {
                    transaction.putItemCacheEntry(id: cachedRecentAppsEntryId(), entry: entry)
                }
            case .topPeersNotModified:
                break
            case .topPeersDisabled:
                if let entry = CodableEntry(CachedRecentPeers(enabled: false, ids: [])) {
                    transaction.putItemCacheEntry(id: cachedRecentAppsEntryId(), entry: entry)
                }
            }
        }
    }
    
    return peersEnabled |> mapToSignal { _ -> Signal<Void, NoError> in
        return updateOnce
    }
}

func _internal_removeRecentlyUsedApp(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let entry = transaction.retrieveItemCacheEntry(id: cachedRecentAppsEntryId()), let recentPeers = entry.get(CachedRecentPeers.self) {
            let updatedRecentPeers = CachedRecentPeers(enabled: recentPeers.enabled, ids: recentPeers.ids.filter({ $0 != peerId }))
            if let updatedEntry = CodableEntry(updatedRecentPeers) {
                transaction.putItemCacheEntry(id: cachedRecentAppsEntryId(), entry: updatedEntry)
            }
        }
        
        if let peer = transaction.getPeer(peerId), let apiPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.contacts.resetTopPeerRating(category: .topPeerCategoryBotsApp, peer: apiPeer))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
