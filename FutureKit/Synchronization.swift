//
//  NSData-Ext.swift
//  FutureKit
//
//  Created by Michael Gray on 4/21/15.
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


// Don't know what sort of synchronization is perfect?
// try them all!
// testing different strategys may result in different performances (depending on your implementations)
public protocol SynchronizationProtocol {
    init()
    
    // modify your shared object and return some value in the process
    // the "then" block could execute inside ANY thread/queue so care should be taken.
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    func lockAndModify<T>(waitUntilDone wait: Bool, modifyBlock:() -> T,
        then : ((T) -> Void)?)

    
    // modify your shared object and return some value in the process
    // the "then" block could execute inside ANY thread/queue so care should be taken.
    // the "then" block is NOT protected by synchronization, but can process a value that was returned from 
    // the read block (ex: returned a lookup value from a shared Dictionary).
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    func lockAndRead<T>(waitUntilDone wait: Bool, readBlock:() -> T,
        then : ((T) -> Void)?)

    
    // -- The rest of these are convience methods.
    
    // modify your object.  The block() code may run asynchronously, but doesn't return any result
    func lockAndModify(modifyBlock:() -> Void)
    
    // modify your shared object and return some value in the process
    // the "done" block could execute inside ANY thread/queue so care should be taken.
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void)
    
    // modify your container and retrieve a result/element to the same calling thread
    // current thread will block until the modifyBlock is done running.
    func lockAndModifySync<T>(modifyBlock:() -> T) -> T

    
    // read your object.  The block() code may run asynchronously, but doesn't return any result
    // if you need to read the block and return a result, use readAsync/readSync
    func lockAndRead(readBlock:() -> Void)
    
    // perform a readonly query of your shared object and return some value/element T
    // current thread may block until the read block is done running.
    // do NOT modify your object inside this block
    func lockAndReadSync<T>(readBlock:() -> T) -> T
    
    // perform a readonly query of your object and return some value/element of type T.
    // the results are delivered async inside the done() block.
    // the done block is NOT protected by the synchronization - do not modify your shared data inside the "done:" block
    // the done block could execute inside ANY thread/queue so care should be taken
    // do NOT modify your object inside this block
    func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void)
    
    func readFuture<T>(executor _ : Executor, block:() -> T) -> Future<T>
    func modifyFuture<T>(executor _ : Executor, block:() -> T) -> Future<T>


}

public enum SynchronizationType : CustomStringConvertible, CustomDebugStringConvertible {
    case BarrierConcurrent
    case BarrierSerial
    case SerialQueue
    case NSObjectLock
    case NSLock
    case NSRecursiveLock
    case OSSpinLock
    case PThreadMutex
//	case NSLockWithSafetyChecks
//	case NSRecursiveLockWithSafetyChecks
    case Unsafe
    
    public var maxLockWaitTimeAllowed : NSTimeInterval {
        return 30.0
    }
    
    public static let allValues = [BarrierConcurrent, BarrierSerial, SerialQueue,NSObjectLock,NSLock,NSRecursiveLock,OSSpinLock,PThreadMutex]

    public func lockObject() -> SynchronizationProtocol {
        switch self {
        case BarrierConcurrent:
            return QueueBarrierSynchronization(type: DISPATCH_QUEUE_CONCURRENT)
        case BarrierSerial:
            return QueueBarrierSynchronization(type: DISPATCH_QUEUE_SERIAL)
        case SerialQueue:
            return QueueSerialSynchronization()
        case NSObjectLock:
            return NSObjectLockSynchronization()
        case NSLock:
            return NSLockSynchronization()
        case NSRecursiveLock:
            return NSRecursiveLockSynchronization()
        case OSSpinLock:
            return OSSpinLockSynchronization()
        case PThreadMutex:
            return PThreadMutexSynchronization()
/*        case NSLockWithSafetyChecks:
            return NSLockSynchronizationWithSafetyChecks()
        case NSRecursiveLockWithSafetyChecks:
            return NSRecursiveLockSynchronizationWithSafetyChecks() */
        case Unsafe:
            return UnsafeSynchronization()
        }
    }
    
    public var description : String {
        switch self {
        case BarrierConcurrent:
            return "BarrierConcurrent"
        case BarrierSerial:
            return "BarrierSerial"
        case SerialQueue:
            return "SerialQueue"
        case NSObjectLock:
            return "NSObjectLock"
        case NSLock:
            return "NSLock"
        case NSRecursiveLock:
            return "NSRecursiveLock"
        case OSSpinLock:
            return "OSSpinLock"
        case PThreadMutex:
            return "PThreadMutex"
        case Unsafe:
            return "Unsafe"
        }
        
    }
    public var debugDescription : String {
        return self.description
    }
    
    // some typealias for the default recommended Objects
    typealias LightAndFastSyncType = OSSpinLockSynchronization
    typealias SlowOrComplexSyncType = QueueBarrierSynchronization

}

public class QueueBarrierSynchronization : SynchronizationProtocol {
    
    var q : dispatch_queue_t
    
    init(queue : dispatch_queue_t) {
        self.q = queue
    }
    
    required public init() {
        self.q = QosCompatible.Default.createQueue("QueueBarrierSynchronization", q_attr: DISPATCH_QUEUE_CONCURRENT, relative_priority: 0)
    }
    
    
    public init(type : dispatch_queue_attr_t!, _ q: QosCompatible = .Default, _ p :Int32 = 0) {
        self.q = q.createQueue("QueueBarrierSynchronization", q_attr: type, relative_priority: p)
    }

    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
    
        if (wait) {
            dispatch_barrier_sync(self.q) {
                let r = modifyBlock()
                then?(r)
            }
        }
        else {
            dispatch_barrier_async(self.q) {
                let r = modifyBlock()
                then?(r)
            }
        }
    }

    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
    
            if (wait) {
                dispatch_sync(self.q) {
                    let r = readBlock()
                    then?(r)
                }
            }
            else {
                dispatch_async(self.q) {
                    let r = readBlock()
                    then?(r)
                }
            }
    }


    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }

    
}

public class QueueSerialSynchronization : SynchronizationProtocol {
    
    var q : dispatch_queue_t
    
    init(queue : dispatch_queue_t) {
        self.q = queue
    }
    
    required public init() {
        self.q = QosCompatible.Default.createQueue("QueueSynchronization", q_attr: DISPATCH_QUEUE_SERIAL, relative_priority: 0)
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if (wait) {
                dispatch_sync(self.q) { // should this dispatch_barrier_sync?  let's see if there's a performance difference
                    let r = modifyBlock()
                    then?( r)
                }
            }
            else {
                dispatch_async(self.q) {
                    let r = modifyBlock()
                    then?( r)
                }
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if (wait) {
                dispatch_sync(self.q) {
                    let r = readBlock()
                    then?( r)
                }
            }
            else {
                dispatch_async(self.q) {
                    let r = readBlock()
                    then?( r)
                }
            }
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }

}

public class NSObjectLockSynchronization : SynchronizationProtocol {

    var lock : AnyObject
    
    required public init() {
        self.lock = NSObject()
    }
    
    public init(lock l: AnyObject) {
        self.lock = l
    
    }
    
    func synchronized<T>(block:() -> T) -> T {
        return SYNCHRONIZED(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = self.synchronized(modifyBlock)
                then( retVal)
            }
            else {
                self.synchronized(modifyBlock)
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }
    
}

func synchronizedWithLock<T>(l: NSLocking, @noescape closure:  ()->T) -> T {
    l.lock()
    let retVal: T = closure()
    l.unlock()
    return retVal
}


public class NSLockSynchronization : SynchronizationProtocol {
    
    var lock = NSLock()
    
    required public init() {
    }
    
    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = self.synchronized(modifyBlock)
                then( retVal)
            }
            else {
                self.synchronized(modifyBlock)
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }

    
}

func synchronizedWithSpinLock<T>(l: UnSafeMutableContainer<OSSpinLock>, @noescape closure:  ()->T) -> T {
    OSSpinLockLock(l.unsafe_pointer)
    let retVal: T = closure()
    OSSpinLockUnlock(l.unsafe_pointer)
    return retVal
}

public class OSSpinLockSynchronization : SynchronizationProtocol {
    
    var lock = UnSafeMutableContainer<OSSpinLock>(OS_SPINLOCK_INIT)

    required public init() {

    }
    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithSpinLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = self.synchronized(modifyBlock)
                then( retVal)
            }
            else {
                self.synchronized(modifyBlock)
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }

    
}


func synchronizedWithMutexLock<T>(mutex: UnsafeMutablePointer<pthread_mutex_t>, @noescape closure:  ()->T) -> T {
    pthread_mutex_lock(mutex)
    let retVal: T = closure()
    pthread_mutex_unlock(mutex)
    return retVal
}

public class PThreadMutexSynchronization : SynchronizationProtocol {
    

    var mutex_container: UnSafeMutableContainer<pthread_mutex_t>
 
    var mutex: UnsafeMutablePointer<pthread_mutex_t> {
        return self.mutex_container.unsafe_pointer
    }
    
    required public init() {
        
        self.mutex_container = UnSafeMutableContainer<pthread_mutex_t>()
        pthread_mutex_init(self.mutex, nil)
    }
    
    deinit {
        pthread_mutex_destroy(mutex)
        self.mutex.destroy()
    }

    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithMutexLock(mutex) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = self.synchronized(modifyBlock)
                then( retVal)
            }
            else {
                self.synchronized(modifyBlock)
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }

    
}

public class NSRecursiveLockSynchronization : SynchronizationProtocol {
    
    var lock = NSRecursiveLock()
    
    required public init() {
    }
    
    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = self.synchronized(modifyBlock)
                then( retVal)
            }
            else {
                self.synchronized(modifyBlock)
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }
    
}


// this class offers no actual synchronization protection!!
// all blocks are executed immediately in the current calling thread.
// Useful for implementing a muteable-to-immuteable design pattern in your objects.
// You replace the Synchroniztion object once your object reaches an immutable state.
// USE WITH CARE.
public class UnsafeSynchronization : SynchronizationProtocol {
    
    required public init() {
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            if let then = then {
                let retVal = modifyBlock()
                then( retVal)
            }
            else {
                modifyBlock()
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:() -> T,
        then : ((T) -> Void)? = nil) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    // this should be in the swift 2.0 protocol extension, for now we do a big cut/paste
    
    public final func lockAndModify(modifyBlock:() -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: nil)
    }
    
    public final func lockAndModifyAsync<T>(modifyBlock:() -> T, then : (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    public final func lockAndModifySync<T>(modifyBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    public final func lockAndRead(readBlock:() -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: nil)
    }
    
    public final func lockAndReadAsync<T>(readBlock:() -> T, then : (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    public final func lockAndReadSync<T>(readBlock:() -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    public final func readFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public final func modifyFuture<T>(executor executor : Executor = .Primary, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }
    
}


public class CollectionAccessControl<C : MutableCollectionType, S: SynchronizationProtocol> {
    
    public typealias Index  = C.Index
    public typealias Element = C.Generator.Element
   
    var syncObject : S
    var collection : C
    
    public init(c : C, _ s: S) {
        self.collection = c
        self.syncObject = s
    }

    public func getValue(key : Index) -> Future<Element> {
        return self.syncObject.readFuture(executor: .Primary) { () -> Element in
            return self.collection[key]
        }
    }
    
/*    subscript (key: Index) -> Element {
        get {
            return self.syncObject.readSync { () -> Element in
                return self.collection[key]
            }
        }
        set(newValue) {
            self.syncObject.lockAndModifySync {
                self.collection[key] = newValue
            }
        }
    } */

}

public class DictionaryWithSynchronization<Key : Hashable, Value, S: SynchronizationProtocol> {
    
    public typealias Index  = Key
    public typealias Element = Value
    public typealias DictionaryType = Dictionary<Key,Value>
    
    var syncObject : S
    var dictionary : DictionaryType
    
    public init() {
        self.dictionary = DictionaryType()
        self.syncObject = S()
    }
    
    public init(_ d : DictionaryType, _ s: S) {
        self.dictionary = d
        self.syncObject = s
    }

    public init(_ s: S) {
        self.dictionary = DictionaryType()
        self.syncObject = s
    }
    
    public func getValue(key : Key) -> Future<Value?> {
        return self.syncObject.readFuture(executor: .Primary) { () -> Value? in
            return self.dictionary[key]
        }
    }

    public func getValueSync(key : Key) -> Value? {
        let value = self.syncObject.lockAndReadSync { () -> Element? in
            let e = self.dictionary[key]
            return e
        }
        return value
    }

    public func setValue(value: Value, forKey key: Key) -> Future<Any> {
        return self.syncObject.modifyFuture(executor: .Primary) { () -> Any in
            self.dictionary[key] = value
        }
    }

    public func updateValue(value: Value, forKey key: Key) -> Future<Value?> {
        return self.syncObject.modifyFuture(executor: .Primary) { () -> Value? in
            return self.dictionary.updateValue(value, forKey: key)
        }
    }

    public var count: Int {
        get {
            return self.syncObject.lockAndReadSync { () -> Int in
                return self.dictionary.count
            }
        }
    }
    
    public var isEmpty: Bool {
        get {
            return self.syncObject.lockAndReadSync { () -> Bool in
                return self.dictionary.isEmpty
            }
        }
    }

    // THIS operation may hang swift 1.2 and CRASHES the Swift 2.0 xcode7.0b1 compiler!
/*   subscript (key: Key) -> Value? {
        get {
            let value = self.syncObject.readSync { () -> Element? in
                let e = self.dictionary[key]
                return e
            }
            return value
        }
        set(newValue) {
//            self.syncObject.lockAndModifySync {
//                self.dictionary[key] = newValue
//            }
        }
    } */
}


public class ArrayWithSynchronization<T, S: SynchronizationProtocol> : CollectionAccessControl< Array<T> , S> {
    
    var array : Array<T> {
        get {
            return self.collection
        }
    }
    
    public init() {
        super.init(c: Array<T>(), S())
    }
    
    public init(array : Array<T>, _ a: S) {
        super.init(c: array, a)
    }
    
    public init(a: S) {
        super.init(c: Array<T>(), a)
    }
    
    
    public var count: Int {
        get {
            return self.syncObject.lockAndReadSync { () -> Int in
                return self.collection.count
            }
        }
    }

    public var isEmpty: Bool {
        get {
            return self.syncObject.lockAndReadSync { () -> Bool in
                return self.collection.isEmpty
            }
        }
    }

    public var first: T? {
        get {
            return self.syncObject.lockAndReadSync { () -> T? in
                return self.collection.first
            }
        }
    }
    public var last: T? {
        get {
            return self.syncObject.lockAndReadSync { () -> T? in
                return self.collection.last
            }
        }
    }
    
/*    subscript (future index: Int) -> Future<T> {
        return self.syncObject.readFuture { () -> T in
            return self.collection[index]
        }
    } */

    
    public func getValue(atIndex i: Int) -> Future<T> {
        return self.syncObject.readFuture(executor: .Primary) { () -> T in
            return self.collection[i]
        }
    }

    public func append(newElement: T) {
        self.syncObject.lockAndModify {
            self.collection.append(newElement)
        }
    }
    
    public func removeLast() -> T {
        return self.syncObject.lockAndModifySync {
            self.collection.removeLast()
        }
    }
    
    public func insert(newElement: T, atIndex i: Int) {
        self.syncObject.lockAndModify {
            self.collection.insert(newElement,atIndex: i)
        }
    }
    
    public func removeAtIndex(index: Int) -> T {
        return self.syncObject.lockAndModifySync {
            self.collection.removeAtIndex(index)
        }
    }


}

public class DictionaryWithFastLockAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,SynchronizationType.LightAndFastSyncType> {
    
    typealias LockObjectType = SynchronizationType.LightAndFastSyncType
    
    public  override init() {
        super.init(LockObjectType())
    }
    public  init(d : Dictionary<Key,Value>) {
        super.init(d,LockObjectType())
    }
    
}

public class DictionaryWithBarrierAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,QueueBarrierSynchronization> {

    typealias LockObjectType = QueueBarrierSynchronization

    public  init(queue : dispatch_queue_t) {
        super.init(LockObjectType(queue: queue))
    }
    public  init(d : Dictionary<Key,Value>,queue : dispatch_queue_t) {
        super.init(d,LockObjectType(queue: queue))
    }
}



public class ArrayWithFastLockAccess<T> : ArrayWithSynchronization<T,SynchronizationType.LightAndFastSyncType> {
    
    
}

/* func dispatch_queue_create_compatibleIOS8(label : String,
    attr : dispatch_queue_attr_t,
    qos_class : dispatch_qos_class_t,relative_priority : Int32) -> dispatch_queue_t
{
        let c_attr = dispatch_queue_attr_make_with_qos_class(attr,qos_class, relative_priority)
        let queue = dispatch_queue_create(label, c_attr)
        return queue;
} */



/* class DispatchQueue: NSObject {
    
    enum QueueType {
        case Serial
        case Concurrent
    }

    enum QueueClass {
        case Main
        case UserInteractive            // QOS_CLASS_USER_INTERACTIVE
        case UserInitiated              // QOS_CLASS_USER_INITIATED
        case Default                    // QOS_CLASS_DEFAULT
        case Utility                    // QOS_CLASS_UTILITY
        case Background                 // QOS_CLASS_BACKGROUND
    }

    
    var q : dispatch_queue_t
    var type : QueueType
    
    
    init(name : String, type : QueueType, relative_priority : Int32) {
        
        var attr = (type == .Concurrent) ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL
        
        let c_attr = dispatch_queue_attr_make_with_qos_class(attr,qos_class, relative_priority);
        dispatch_queue_t queue = dispatch_queue_create(label, c_attr);
        return queue;
        
    }
   
} */
