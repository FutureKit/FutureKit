//
//  NSObject-Ext-ThreadSafe.swift
//  Shimmer
//
//  Created by Michael Gray on 12/15/14.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
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
        let retVal: T = closure()
        objc_sync_exit(self.lockObject)
        return retVal
    }
    
    func EFFICIENT_THREAD_SAFE_SYNC<T>(@noescape closure: ()->T) -> T
    {
        objc_sync_enter(self)
        let retVal: T = closure()
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
    let lock_result = objc_sync_enter(lock)
    assert(Int(lock_result) == OBJC_SYNC_SUCCESS,"Failed to lock object!")
    let retVal: T = closure()
    let exit_result = objc_sync_exit(lock)
    assert(Int(exit_result) == OBJC_SYNC_SUCCESS,"Failed to release object!")
    return retVal
}
