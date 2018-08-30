//
//  NSCache+FutureKit.swift
//  FutureKit
//
//  Created by Michael Gray on 5/17/16.
//  Copyright © 2016 Michael Gray. All rights reserved.
//

import Foundation

/**
 *  A protocol for giving a Cache the ability to compute a cost even if using a Future.
 */
public protocol CacheEntryProtocol: class {
    associatedtype Value

    var future : Future<Value> { get }
    var expireTime: Date? { set get }
    func refresh() -> Future<Value>

    init(_ f: Future<Value>, expireTime e: Date?, refreshCommand refresh: @escaping () -> Future<Value>)

}

public extension CacheEntryProtocol {

    public init(value: Value, expireTime e: Date? = nil) {
        self.init(.success(value), expireTime: e) {
            return .success(value)
        }
    }

}

final public class CacheEntry<Value>: CacheEntryProtocol {

    public var future : Future<Value>
    public var expireTime: Date?


    public func refresh() -> Future<Value>  {
        return .cancelled
    }
    
    public init(_ f: Future<Value>,expireTime e: Date? = nil, refreshCommand refresh: @escaping () -> Future<Value>) {
        self.future = f
        self.expireTime = e
    }
}

final public class RefreshingCacheEntry<Value>: CacheEntryProtocol {

    public var future : Future<Value>
    public var expireTime: Date?
    let refreshCommand: () -> Future<Value>


    public func refresh() -> Future<Value> {
        return refreshCommand()
    }

    public init(_ f: Future<Value>, expireTime e: Date? = nil, refreshCommand refresh: @escaping () -> Future<Value>) {
        future = f
        expireTime = e
        refreshCommand = refresh
    }
}


private class ObjectWrapper<Value> {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

public protocol CacheStorageProtocol {
    associatedtype KeyType: Hashable
    associatedtype Entry


    init()
    func object(forKey key: KeyType) -> Entry?
    mutating func setObject(_ obj: Entry, forKey key: KeyType, cost g: Int)
    mutating func removeObject(forKey key: KeyType)
    mutating func removeAllObjects()


}
public final class NSCacheWrapper<KeyType : Hashable, Entry>: CacheStorageProtocol {

    private let innerCache: NSCache<KeyWrapper<KeyType>, ObjectWrapper<Entry>> = NSCache()

    public init() {
    }

    public func object(forKey key: KeyType) -> Entry? {
        return innerCache.object(forKey: KeyWrapper(key))?.value
    }

    public func setObject(_ obj: Entry, forKey key: KeyType, cost g: Int = 0) {
        return innerCache.setObject(ObjectWrapper(obj), forKey: KeyWrapper(key), cost: g)
    }

    public func removeObject(forKey key: KeyType) {
        return innerCache.removeObject(forKey: KeyWrapper(key))
    }

    public func removeAllObjects() {
        return innerCache.removeAllObjects()
    }
}


extension Dictionary : CacheStorageProtocol {
    public typealias KeyType = Key
    public typealias Entry = Value

    public func object(forKey key: KeyType) -> Entry? {
        return self[key]
    }

    mutating public func setObject(_ obj: Entry, forKey key: KeyType, cost g: Int = 0) {
        return self[key] = obj
    }

    mutating public func removeObject(forKey key: KeyType) {
        return self[key] = nil
    }

    mutating public func removeAllObjects() {
        return self.removeAll()
    }

}



open class Cache<CacheStorage : CacheStorageProtocol, Entry: CacheEntryProtocol> where CacheStorage.Entry == Entry {

    public typealias Value = Entry.Value
    public typealias KeyType = CacheStorage.KeyType

    let onCacheChange: ((KeyType, Value?) -> Void)?
    public init (onFetchResult onChange: @escaping ((KeyType, Value?) -> Void)) {
        onCacheChange = onChange
    }

    public init () {
        onCacheChange = nil
    }

    private var innerCache = CacheStorage.init()

    public func object(forKey key: KeyType) -> Value? {
        return innerCache.object(forKey: key)?.future.value
    }

    private func setCacheObject(entry: Entry, key: KeyType, cost: Int? = nil) {
        let cost = cost ?? 0
        innerCache.setObject(entry, forKey: key, cost: cost)

        if let onFetchResult = self.onCacheChange {
            entry.future.onComplete { onFetchResult(key, $0.value) }
        }

    }
    public func setObject(_ obj: Value, forKey key: KeyType) {
        let entry = Entry(value: obj)
        self.setCacheObject(entry: entry, key: key)
    }

    public func setObject(_ obj: Value, expireTime: Date? = nil, forKey key: KeyType) {
        let entry = Entry(value: obj, expireTime: expireTime)

        let cacheCost: Int
        if Value.self is HasCacheCost.Type {
            cacheCost = (obj as? HasCacheCost)?.cacheCost ?? 0
        } else {
            cacheCost = 0
        }
        self.setCacheObject(entry: entry, key: key, cost: cacheCost)
    }

    public func setObject(_ obj: Value, expireAfter: TimeInterval, forKey key: KeyType) {
        self.setObject(obj, expireTime: Date(timeIntervalSinceNow: expireAfter), forKey: key)
    }


    public func setObject(_ obj: Value, expireTime: Date? = nil, forKey key: KeyType, cost g: Int) {
        let entry = Entry(value:obj, expireTime: expireTime)
        self.setCacheObject(entry: entry, key: key, cost: g)
    }
    
    public func removeObject(forKey key: KeyType) {
        innerCache.removeObject(forKey: key)
        self.onCacheChange?(key, nil)
    }
    
    public func removeAllObjects() {
        innerCache.removeAllObjects()
    }
    

    private func getCacheEntry(key : KeyType, onFetch: @escaping () -> Future<Value>, forceRefresh: Bool, mapExpireTime: ((FutureResult<Value>) -> Date?)? = nil) -> Entry {

        if !forceRefresh, let entry = self.innerCache.object(forKey: key) {
            if let expireTime = entry.expireTime {
                if expireTime.timeIntervalSinceNow > 0 {
                    return entry
                }
            }
            else {
                return entry
            }
        }
        let f = onFetch()
        let entry = Entry.init(f, expireTime: nil, refreshCommand: onFetch)
        // it's important to call setObject before adding the onFailorCancel handler, since some futures will fail immediatey!
        self.setCacheObject(entry: entry, key: key)

        f.onComplete { result in
            if Value.self is HasCacheCost.Type {
                if let cacheCost = (result.value as? HasCacheCost)?.cacheCost {
                    self.setCacheObject(entry: entry, key: key, cost: cacheCost)
                }
            }
            if let expireTime = mapExpireTime?(result) {
                entry.expireTime = expireTime
            } else if !result.isSuccess {
                self.removeObject(forKey: key)
            }
        }
        return entry
    }

    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, mapExpireTime: @escaping ((FutureResult<Value>) -> Date?), onFetch:@escaping () -> Future<Value>) -> Future<Value> {

        return getCacheEntry(key: key, onFetch: onFetch, forceRefresh: forceRefresh, mapExpireTime: mapExpireTime).future
    }

    public func refresh(key : KeyType) -> Future<Value> {

        if let refresh = self.innerCache.object(forKey: key)?.refresh() {
            return refresh
        }
        return .fail(FutureKitError.refreshFailed(key: key))
    }


    /**
    Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
                             There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, expireTime: Date? = nil, onFetch:@escaping () -> Future<Value>) -> Future<Value> {

        let mapExpireTime: ((FutureResult<Value>) -> Date?)
        if let expireTime = expireTime {
            mapExpireTime = { (result) -> Date? in
                switch result {
                case .success:
                    return expireTime
                default:
                    return nil
                }
            }
        } else {
            mapExpireTime = { _ in return nil }
        }

        return self.findOrFetch(key: key, forceRefresh: forceRefresh, mapExpireTime:mapExpireTime, onFetch: onFetch)
    }

    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, expireAfter: TimeInterval?, onFailExpireAfter: TimeInterval? = nil, onFetch:@escaping () -> Future<Value>) -> Future<Value> {

        return self.findOrFetch(key: key,
                                forceRefresh: forceRefresh,
                                mapExpireTime: { (result) -> Date? in
                                    switch result {
                                    case .success:
                                        return expireAfter.flatMap { Date(timeIntervalSinceNow: $0) }
                                    case .fail:
                                        return onFailExpireAfter.flatMap { Date(timeIntervalSinceNow: $0) }
                                    case .cancelled:
                                        return nil
                                    }
        }, onFetch: onFetch)

    }

}

extension Cache {

    public func fetchAndCache(key: KeyType, options: CacheOptions = .useCache, fetchCommand: @escaping () -> Future<Value>) -> Future<Value> {

        if options.useExistingValueOnFail, let currentValue = self.object(forKey: key) {
            return self.findOrFetch(
                key: key,
                forceRefresh: options.forceRefresh,
                expireAfter: options.expireAfter,
                onFailExpireAfter: options.onFailExpireAfter) {
                    return fetchCommand().onComplete { result -> Completion<Value> in
                        switch result {
                        case .success(let value):
                            return .success(value)
                        case .fail:
                            return .success(currentValue)
                        case .cancelled:
                            return .cancelled
                        }
                    }
            }

        }
        return self.findOrFetch(key: key,
                                forceRefresh: options.forceRefresh,
                                expireAfter: options.expireAfter,
                                onFailExpireAfter: options.onFailExpireAfter,
                                onFetch: fetchCommand)
    }
}


open class FutureCache2<KeyType : Hashable, T>: Cache<NSCacheWrapper<KeyType, CacheEntry<T>>,CacheEntry<T>>  {
}

open class RefreshableFutureCache<KeyType : Hashable, T>: Cache<NSCacheWrapper<KeyType, RefreshingCacheEntry<T>>,RefreshingCacheEntry<T>>  {
}

open class RefreshableFutureDictionary<KeyType : Hashable, T>: Cache<Dictionary<KeyType, RefreshingCacheEntry<T>>,RefreshingCacheEntry<T>>  {

}

