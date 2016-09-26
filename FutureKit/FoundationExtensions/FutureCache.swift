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
        self.future = Future(success: value)
        self.expireTime = e
    }

}


open class FutureCache<KeyType : AnyObject, T> {
    
    
    public init () {
        
    }
    var cache = NSCache<KeyType,FutureCacheEntry<T>>()
    
    
    open func object(forKey key: KeyType) -> T? {
        return cache.object(forKey: key)?.future.value
    }

    open func setObject(_ obj: T, forKey key: KeyType) {
        let entry = FutureCacheEntry(value:obj)
        cache.setObject(entry, forKey: key)
    }

    open func setObject(_ obj: T, forKey key: KeyType, cost g: Int) {
        let entry = FutureCacheEntry(value:obj)
        cache.setObject(entry, forKey: key, cost: g)
    }
    
    open func removeObject(forKey key: KeyType) {
        cache.removeObject(forKey: key)
    }
    
    open func removeAllObjects() {
        cache.removeAllObjects()
    }
    

    fileprivate func _findOrFetch(key : KeyType, expireTime: Date? = nil, onFetch:() -> Future<T>) -> FutureCacheEntry<T> {
        
        if let entry = self.cache.object(forKey: key) {
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
        let entry = FutureCacheEntry(f,expireTime: expireTime)
        // it's important to call setObject before adding the onFailorCancel handler, since some futures will fail immediatey!
        self.cache.setObject(entry, forKey: key)
        f.onFailorCancel { (result) -> Void in
            self.cache.removeObject(forKey: key)
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
    public func findOrFetch(key : KeyType, expireTime: Date? = nil, onFetch:() -> Future<T>) -> Future<T> {
        
        return _findOrFetch(key: key, expireTime: expireTime,onFetch: onFetch).future
    }
}

public  extension FutureCache where T:HasCacheCost {

    /**
     Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
     There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public func findOrFetch(key : KeyType, expireTime: Date? = nil, onFetch:() -> Future<T>) -> Future<T>  {
        
        let entry =  _findOrFetch(key: key,expireTime: expireTime,onFetch: onFetch)
        return entry.future.onSuccess { value in
            self.cache.setObject(entry, forKey: key, cost: value.cacheCost)
            return value
        }
    }

    
}
