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
public protocol HasCacheCost {
    var cacheCost : Int { get }
}


open class FutureCacheEntry<T> {

    var future : Future<T>
    var expireTime: Date?
    
    public init(_ f: Future<T>,expireTime e: Date? = nil) {
        self.future = f
        self.expireTime = e
    }

    public init(value: T,expireTime e: Date? = nil) {
        self.future = .success(value)
        self.expireTime = e
    }

}


private class ObjectWrapper {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }
}

private class KeyWrapper<KeyType: Hashable>: NSObject {
    let key: KeyType
    init(_ key: KeyType) {
        self.key = key
    }

    override var hash: Int {
        return key.hashValue
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? KeyWrapper<KeyType> else {
            return false
        }
        return key == other.key
    }
}


public class FutureCache<KeyType : Hashable, T> {
    
    
    public init () {
        
    }

    private let cache: NSCache<KeyWrapper<KeyType>, FutureCacheEntry<T>> = NSCache()

    public func object(forKey key: KeyType) -> T? {
        return cache.object(forKey: KeyWrapper(key))?.future.value
    }

    public func setObject(_ obj: T, forKey key: KeyType) {
        let entry = FutureCacheEntry(value: obj)
        cache.setObject(entry, forKey: KeyWrapper(key))
    }

    public func setObject(_ obj: T, expireTime: Date? = nil, forKey key: KeyType) {
        let entry = FutureCacheEntry(value: obj, expireTime: expireTime)

        if T.self is HasCacheCost.Type {
            if let cacheCost = (obj as? HasCacheCost)?.cacheCost {
                self.cache.setObject(entry, forKey: KeyWrapper(key), cost: cacheCost)
                return
            }
        }
        cache.setObject(entry, forKey: KeyWrapper(key))
    }

    public func setObject(_ obj: T, expireAfter: TimeInterval, forKey key: KeyType) {
        self.setObject(obj, expireTime: Date(timeIntervalSinceNow: expireAfter), forKey: key)
    }


    public func setObject(_ obj: T, expireTime: Date? = nil, forKey key: KeyType, cost g: Int) {
        let entry = FutureCacheEntry(value:obj, expireTime: expireTime)
        cache.setObject(entry, forKey: KeyWrapper(key), cost: g)
    }
    
    public func removeObject(forKey key: KeyType) {
        cache.removeObject(forKey: KeyWrapper(key))
    }
    
    public func removeAllObjects() {
        cache.removeAllObjects()
    }
    

    private func getCacheEntry(wrappedKey : KeyWrapper<KeyType>, onFetch:() -> Future<T>, forceRefresh: Bool, mapExpireTime: ((FutureResult<T>) -> Date?)? = nil) -> FutureCacheEntry<T> {

        if !forceRefresh, let entry = self.cache.object(forKey: wrappedKey) {
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
        let entry = FutureCacheEntry(f)
        // it's important to call setObject before adding the onFailorCancel handler, since some futures will fail immediatey!
        self.cache.setObject(entry, forKey: wrappedKey)

        f.onComplete { result in
            if T.self is HasCacheCost.Type {
                if let cacheCost = (result.value as? HasCacheCost)?.cacheCost {
                    self.cache.setObject(entry, forKey: wrappedKey, cost: cacheCost)
                }
            }
            if let expireTime = mapExpireTime?(result) {
                entry.expireTime = expireTime
            } else if !result.isSuccess {
                self.cache.removeObject(forKey: wrappedKey)
            }
        }
        return entry
    }

    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, mapExpireTime: @escaping ((FutureResult<T>) -> Date?), onFetch:() -> Future<T>) -> Future<T> {

        let wrappedKey = KeyWrapper(key)
        return getCacheEntry(wrappedKey: wrappedKey, onFetch: onFetch, forceRefresh: forceRefresh, mapExpireTime: mapExpireTime).future
    }

    /**
    Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
                             There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, expireTime: Date? = nil, onFetch:() -> Future<T>) -> Future<T> {

        let mapExpireTime: ((FutureResult<T>) -> Date?)
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

    public func findOrFetch(key : KeyType, forceRefresh: Bool = false, expireAfter: TimeInterval?, onFailExpireAfter: TimeInterval? = nil, onFetch:() -> Future<T>) -> Future<T> {

        return self.findOrFetch(key: key,
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

public struct CacheOptions {

    public let forceRefresh: Bool
    public let expireAfter: TimeInterval?
    public let onFailExpireAfter: TimeInterval?
    public let useExistingValueOnFail: Bool

    public init(forceRefresh: Bool,
                expireAfter: TimeInterval?,
                onFailExpireAfter: TimeInterval?,
                useExistingValueOnFail: Bool) {
        self.forceRefresh = forceRefresh
        self.expireAfter = expireAfter
        self.onFailExpireAfter = onFailExpireAfter
        self.useExistingValueOnFail = useExistingValueOnFail
    }

    public static func retryFailures(after: TimeInterval) -> CacheOptions {
        return CacheOptions(forceRefresh: false,
                            expireAfter: nil,
                            onFailExpireAfter: after,
                            useExistingValueOnFail: true)
    }

    public static var useCache = CacheOptions(forceRefresh: false,
                                              expireAfter: nil,
                                              onFailExpireAfter: nil,
                                              useExistingValueOnFail: true)

    public static var forceRefresh = CacheOptions(forceRefresh: true,
                                                  expireAfter: nil,
                                                  onFailExpireAfter: nil,
                                                  useExistingValueOnFail: false)

    public static var tryRefresh = CacheOptions(forceRefresh: true,
                                                expireAfter: nil,
                                                onFailExpireAfter: nil,
                                                useExistingValueOnFail: true)
}


extension FutureCache {

    public func fetchAndCache(key: KeyType, options: CacheOptions = .useCache, fetchCommand: @escaping () -> Future<T>) -> Future<T> {

        if options.useExistingValueOnFail, let currentValue = self.object(forKey: key) {
            return self.findOrFetch(
                key: key,
                forceRefresh: options.forceRefresh,
                expireAfter: options.expireAfter,
                onFailExpireAfter: options.onFailExpireAfter) {
                    return fetchCommand().onComplete { result -> Completion<T> in
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


