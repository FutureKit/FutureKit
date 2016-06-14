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


class FutureCacheEntry<T> {

    var future : Future<T>
    var expireTime: NSDate?
    
    init(f: Future<T>,expireTime e: NSDate? = nil) {
        self.future = f
        self.expireTime = e
    }
    
}



public extension NSCache {
    
    private func _findOrFetch<T>(key : String, expireTime: NSDate? = nil, onFetch:() -> Future<T>) -> FutureCacheEntry<T> {
        
        if let entry = self.objectForKey(key) as? FutureCacheEntry<T> {
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
        let entry = FutureCacheEntry(f: f,expireTime: expireTime)
        // it's important to call setObject before adding the onFailorCancel handler, since some futures will fail immediatey!
        self.setObject(entry, forKey: key)
        f.onFailorCancel { (result) -> Void in
            self.removeObjectForKey(key)
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
    public func findOrFetch<T>(key : String, expireTime: NSDate? = nil, onFetch:() -> Future<T>) -> Future<T> {
        
        return _findOrFetch(key,expireTime: expireTime,onFetch: onFetch).future
    }
    
    
    /**
     Utlity method for storing "Futures" inside a NSCache
     
     - parameter key:        key
     - parameter expireTime: an optional date that this key will 'expire'
     There is no logic to 'flush' expired keys.  They are just checked when retreived.
     - parameter onFetch:    A block to execute when the cache doesn't contain the key.
     
     - returns: Either a copy of the cached future, or the result of the onFetch() block
     */
    public func findOrFetch<T : HasCacheCost>(key : String, expireTime: NSDate? = nil, onFetch:() -> Future<T>) -> Future<T> {
        
        let entry =  _findOrFetch(key,expireTime: expireTime,onFetch: onFetch)
        return entry.future.onSuccess { value in
            self.setObject(entry, forKey: key, cost: value.cacheCost)
            return value
        }
    }

    
}