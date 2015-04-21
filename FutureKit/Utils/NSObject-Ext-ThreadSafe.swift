//
//  NSObject-Ext-ThreadSafe.swift
//  Shimmer
//
//  Created by Michael Gray on 12/15/14.
//  Copyright (c) 2014 FlybyMedia. All rights reserved.
//

import Foundation

private var _lockObjectHandler = ExtensionVarHandler()

extension NSObject {
    // This is technically the SAFER implementation of thread_safe_access
    var lockObject : AnyObject {
        get {
            return _lockObjectHandler.getValueFrom(self, defaultvalueblock: { () -> AnyObject in
                    return NSObject()
            })
        }
    }
    func SAFER_THREAD_SAFE_SYNC<T>(@noescape closure: ()->T) -> T
    {
        objc_sync_enter(self.lockObject)
        var retVal: T = closure()
        objc_sync_exit(self.lockObject)
        return retVal
    }
    
    func EFFICIENT_THREAD_SAFE_SYNC<T>(@noescape closure: ()->T) -> T
    {
        objc_sync_enter(self)
        var retVal: T = closure()
        objc_sync_exit(self)
        return retVal
    }
    
     func THREAD_SAFE_SYNC<T>(@noescape closure:  ()->T) -> T
    {
        //  Uncomment this version if you want 100% safe data locking.
        //  Introduces an extra NSObject
        //        return SAFER_THREAD_SAFE_SYNC(closure)
        
        // but we are gonna live dangerous and enjoy the performance of not creating an additional NSObject
        // Just don't objc_sync_enter() directly on objects!
        // (likewise don't use @synchronized(object) in Objective-C
        // If you need that switch to SAFER_THREAD_SAFE_SYNC
        return EFFICIENT_THREAD_SAFE_SYNC(closure)
    }
    
}

func SYNCHRONIZED<T>(lock: AnyObject, @noescape closure:  ()->T) -> T {
    objc_sync_enter(lock)
    var retVal: T = closure()
    objc_sync_exit(lock)
    return retVal
}
