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
    
    public init(_ f: Future<T>, expireTime e: Date? = nil) {
        self.future = f
        self.expireTime = e
    }

    public init(value: T, expireTime e: Date? = nil) {
        self.future = Future(success: value)
        self.expireTime = e
    }

}

final public class HashableBox<T: Hashable> {
    public let value: T
    public init(_ v: T) { self.value = v }

    public var hashValue: Int {
        return value.hashValue
    }
    
    public static func == (lhs: HashableBox<T>, rhs: HashableBox<T>) -> Bool {
        return lhs.value == rhs.value
    }
    
}

  
public class FutureCache<KeyType: Hashable, T> {

    let cache = NSCache<HashableBox<KeyType>, FutureCacheEntry<T>>()

    private final func futureCacheEntry(forKey key: KeyType) -> FutureCacheEntry<T>? {
        return cache.object(forKey: HashableBox(key))
    }

    private final func set(_ obj: FutureCacheEntry<T>, forKey key: KeyType) {
        cache.setObject(obj, forKey: HashableBox(key))
    }
    private final func set(_ obj: FutureCacheEntry<T>, forKey key: KeyType, cost g: Int) {
        cache.setObject(obj, forKey: HashableBox(key), cost: g)
    }

    public final func setObject(_ obj: T, forKey key: KeyType) {
        let entry = FutureCacheEntry(value:obj)
        cache.setObject(entry, forKey: HashableBox(key))
    }

    public final func setObject(_ obj: T, forKey key: KeyType, cost g: Int) {
        let entry = FutureCacheEntry(value:obj)
        cache.setObject(entry, forKey: HashableBox(key), cost: g)
    }
    
    public final func removeObject(forKey key: KeyType) {
        cache.removeObject(forKey: HashableBox(key))
    }
    
    public final func removeAllObjects() {
        cache.removeAllObjects()
    }
    

    private final func findOrFetchEntry<C: CompletionConvertable>(key : KeyType, expireTime: Date? = nil, onFetch:() throws -> C) -> FutureCacheEntry<T> where C.T == T {
        
        if let entry = self.futureCacheEntry(forKey: key) {
            if let expireTime = entry.expireTime {
                if expireTime.timeIntervalSinceNow > 0 {
                    return entry
                }
            }
            else {
                return entry
            }
        }
        let future: Future<T>
        do {
            future = try onFetch().future
        } catch {
            future = .fail(error)
        }
        let entry = FutureCacheEntry(future, expireTime: expireTime)
        // it's important to call setObject before adding the onFailorCancel handler, since some futures will fail immediatey!
        self.set(entry, forKey: key)
        future.onFailorCancel { result -> Void in
            self.removeObject(forKey: key)
        }
        return entry
    }
    
    /**
    Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
                             There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public final func findOrFetch<C: CompletionConvertable>(key : KeyType, expireTime: Date? = nil, onFetch:() throws -> C) -> Future<T> where C.T == T {
        
        return findOrFetchEntry(key: key, expireTime: expireTime,onFetch: onFetch).future
    }
}

public extension FutureCache where T: HasCacheCost {

    /**
     Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
     There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public final func findOrFetch<C: CompletionConvertable>(key : KeyType, expireTime: Date? = nil, onFetch:() -> C) -> Future<T>  where C.T == T  {
        
        let entry = findOrFetchEntry(key: key,expireTime: expireTime,onFetch: onFetch)
        return entry.future.onSuccess { value in
            self.set(entry, forKey: key, cost: value.cacheCost)
            return value
        }
    }

    
}
