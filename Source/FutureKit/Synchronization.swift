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
    func lockAndModify<T>(waitUntilDone: Bool,
                       modifyBlock: @escaping () -> T,
                       then : @escaping (T) -> Void)

    
    // modify your shared object and return some value in the process
    // the "then" block could execute inside ANY thread/queue so care should be taken.
    // the "then" block is NOT protected by synchronization, but can process a value that was returned from 
    // the read block (ex: returned a lookup value from a shared Dictionary).
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    func lockAndRead<T>(waitUntilDone: Bool,
                     readBlock: @escaping () -> T,
                     then : @escaping (T) -> Void)
}

public extension SynchronizationProtocol {

    // -- The rest of these are convience methods.
    
    // modify your object.  The block() code may run asynchronously, but doesn't return any result
    public func lockAndModify(modifyBlock: @escaping () -> Void) {
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock) { (_) in
            return
        }
    }
    
    // modify your shared object and return some value in the process
    // the "done" block could execute inside ANY thread/queue so care should be taken.
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    public func lockAndModifyAsync<T>(modifyBlock:@escaping () -> T, then : @escaping (T) -> Void) {
        self.lockAndModify(waitUntilDone: false, modifyBlock: modifyBlock, then: then)
    }
    
    // modify your container and retrieve a result/element to the same calling thread
    // current thread will block until the modifyBlock is done running.
    @discardableResult
    public func lockAndModifySync<T>(_ modifyBlock:@escaping () -> T) -> T {
        
        var retVal : T?
        self.lockAndModify(waitUntilDone: true, modifyBlock: modifyBlock) { (modifyBlockReturned) -> Void in
            retVal = modifyBlockReturned
        }
        return retVal!
    }
    
    // read your object.  The block() code may run asynchronously, but doesn't return any result
    // if you need to read the block and return a result, use readAsync/readSync
    public func lockAndRead(readBlock: @escaping () -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock) { (_) in
            return
        }
    }
    
    // perform a readonly query of your object and return some value/element of type T.
    // the results are delivered async inside the done() block.
    // the done block is NOT protected by the synchronization - do not modify your shared data inside the "done:" block
    // the done block could execute inside ANY thread/queue so care should be taken
    // do NOT modify your object inside this block
    public func lockAndReadAsync<T>(readBlock:@escaping () -> T, then : @escaping (T) -> Void) {
        self.lockAndRead(waitUntilDone: false, readBlock: readBlock, then: then)
    }
    
    // perform a readonly query of your shared object and return some value/element T
    // current thread may block until the read block is done running.
    // do NOT modify your object inside this block
    @discardableResult
    public func lockAndReadSync<T>(_ readBlock:@escaping () -> T) -> T {
        
        var retVal : T?
        self.lockAndRead(waitUntilDone: true, readBlock: readBlock) { (readBlockReturned) -> Void in
            retVal = readBlockReturned
        }
        return retVal!
    }
    
    public func readFuture<T>(executor : Executor = .primary, block:@escaping () -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndRead(waitUntilDone: false, readBlock: block) { (readBlockReturned) -> Void in
            p.completeWithSuccess(readBlockReturned)
        }
        
        return p.future
    }
    public func modifyFuture<T>(executor : Executor = .primary, block:@escaping () -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.lockAndModify(waitUntilDone: false, modifyBlock: block) { (modifyBlockReturned) -> Void in
            p.completeWithSuccess(modifyBlockReturned)
        }
        return p.future
    }


}

public enum SynchronizationType : CustomStringConvertible, CustomDebugStringConvertible {
    case barrierConcurrent
    case barrierSerial
    case serialQueue
    case nsObjectLock
    case nsLock
    case nsRecursiveLock
    case pThreadMutex
//	case NSLockWithSafetyChecks
//	case NSRecursiveLockWithSafetyChecks
    case unsafe
    
    public var maxLockWaitTimeAllowed : TimeInterval {
        return 30.0
    }
    
    public static let allValues = [barrierConcurrent, barrierSerial, serialQueue,nsObjectLock,nsLock,nsRecursiveLock,pThreadMutex]

    public func lockObject() -> SynchronizationProtocol {
        switch self {
        case .barrierConcurrent:
            return QueueBarrierSynchronization(attributes: .concurrent)
        case .barrierSerial:
            return QueueBarrierSynchronization(attributes: DispatchQueue.Attributes())
        case .serialQueue:
            return QueueSerialSynchronization()
        case .nsObjectLock:
            return NSObjectLockSynchronization()
        case .nsLock:
            return NSLockSynchronization()
        case .nsRecursiveLock:
            return NSRecursiveLockSynchronization()
        case .pThreadMutex:
            return PThreadMutexSynchronization()
/*        case NSLockWithSafetyChecks:
            return NSLockSynchronizationWithSafetyChecks()
        case NSRecursiveLockWithSafetyChecks:
            return NSRecursiveLockSynchronizationWithSafetyChecks() */
        case .unsafe:
            return UnsafeSynchronization()
        }
    }
    
    public var description : String {
        switch self {
        case .barrierConcurrent:
            return "BarrierConcurrent"
        case .barrierSerial:
            return "BarrierSerial"
        case .serialQueue:
            return "SerialQueue"
        case .nsObjectLock:
            return "NSObjectLock"
        case .nsLock:
            return "NSLock"
        case .nsRecursiveLock:
            return "NSRecursiveLock"
        case .pThreadMutex:
            return "PThreadMutex"
        case .unsafe:
            return "Unsafe"
        }
        
    }
    public var debugDescription : String {
        return self.description
    }
    
    // some typealias for the default recommended Objects
    public typealias LightAndFastSyncType = PThreadMutexSynchronization
    public typealias SlowOrComplexSyncType = QueueBarrierSynchronization

}

open class QueueBarrierSynchronization : SynchronizationProtocol {
    
    var q : DispatchQueue
    
    init(queue : DispatchQueue) {
        self.q = queue
    }
    
    required public init() {
        self.q = DispatchQueue(label: "QueueBarrierSynchronization", qos: .default, attributes: .concurrent)
    }
    
    public init(qos: DispatchQoS = .default, attributes :DispatchQueue.Attributes = .concurrent) {
        self.q = DispatchQueue(label: "QueueBarrierSynchronization", qos: qos, attributes: attributes)
    }

    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
    
        if (wait) {
            self.q.sync(flags: .barrier, execute: {
                let r = modifyBlock()
                then(r)
            }) 
        }
        else {
            self.q.async(flags: .barrier, execute: {
                let r = modifyBlock()
                then(r)
            }) 
        }
    }

    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
    
            if (wait) {
                self.q.sync {
                    let r = readBlock()
                    then(r)
                }
            }
            else {
                self.q.async {
                    let r = readBlock()
                    then(r)
                }
            }
    }



    
}

open class QueueSerialSynchronization : SynchronizationProtocol {
 
    var q : DispatchQueue
    
    public required init() {
        self.q = DispatchQueue(label: "QueueSerialSynchronization", qos: .default, attributes: DispatchQueue.Attributes())
    }

    
    public init(queue : DispatchQueue = .global(qos: .default)) {
        self.q = queue
    }
 
    public init(qos: DispatchQoS = .default, attributes :DispatchQueue.Attributes = DispatchQueue.Attributes()) {
        self.q = DispatchQueue(label: "QueueSerialSynchronization", qos: qos, attributes: attributes)
    }

    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            if (wait) {
                self.q.sync { // should this dispatch_barrier_sync?  let's see if there's a performance difference
                    let r = modifyBlock()
                    then( r)
                }
            }
            else {
                self.q.async {
                    let r = modifyBlock()
                    then( r)
                }
            }
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
        
            if (wait) {
                self.q.sync {
                    let r = readBlock()
                    then( r)
                }
            }
            else {
                self.q.async {
                    let r = readBlock()
                    then( r)
                }
            }
    }
    
    
}

open class NSObjectLockSynchronization : SynchronizationProtocol {

    var lock : AnyObject
    
    required public init() {
        self.lock = NSObject()
    }
    
    public init(lock l: AnyObject) {
        self.lock = l
    
    }
    
    func synchronized<T>(_ block:@escaping () -> T) -> T {
        return SYNCHRONIZED(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            let retVal = self.synchronized(modifyBlock)
            then( retVal)
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
        
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
}

func synchronizedWithLock<T>(_ l: NSLocking, closure:  ()->T) -> T {
    l.lock()
    let retVal: T = closure()
    l.unlock()
    return retVal
}


open class NSLockSynchronization : SynchronizationProtocol {
    
    var lock = NSLock()
    
    required public init() {
    }
    
    final func synchronized<T>(_ block:() -> T) -> T {
        return synchronizedWithLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            then(self.synchronized(modifyBlock))
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
            
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
}


func synchronizedWithMutexLock<T>(_ mutex: UnsafeMutablePointer<pthread_mutex_t>, closure:  ()->T) -> T {
    pthread_mutex_lock(mutex)
    let retVal: T = closure()
    pthread_mutex_unlock(mutex)
    return retVal
}

open class PThreadMutexSynchronization : SynchronizationProtocol {
    

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
    }

    final func synchronized<T>(_ block:() -> T) -> T {
        return synchronizedWithMutexLock(mutex) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            then(self.synchronized(modifyBlock))
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
        
            self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
    
    
}

open class NSRecursiveLockSynchronization : SynchronizationProtocol {
    
    var lock = NSRecursiveLock()
    
    required public init() {
    }
    
    final func synchronized<T>(_ block:() -> T) -> T {
        return synchronizedWithLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            then(self.synchronized(modifyBlock))
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
        
        self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    
}


// this class offers no actual synchronization protection!!
// all blocks are executed immediately in the current calling thread.
// Useful for implementing a muteable-to-immuteable design pattern in your objects.
// You replace the Synchroniztion object once your object reaches an immutable state.
// USE WITH CARE.
open class UnsafeSynchronization : SynchronizationProtocol {
    
    required public init() {
    }
    
    public final func lockAndModify<T>(
        waitUntilDone wait: Bool = false,
        modifyBlock: @escaping () -> T,
        then : @escaping (T) -> Void) {
        
            then( modifyBlock())
    }
    
    public final func lockAndRead<T>(
        waitUntilDone wait: Bool = false,
        readBlock:@escaping () -> T,
        then : @escaping ((T) -> Void)) {
        
        self.lockAndModify(waitUntilDone: wait, modifyBlock: readBlock, then: then)
    }
    

}


open class CollectionAccessControl<C : MutableCollection, S: SynchronizationProtocol> {
    
    public typealias Index  = C.Index
    public typealias Element = C.Iterator.Element
   
    var syncObject : S
    var collection : C
    
    public init(c : C, _ s: S) {
        self.collection = c
        self.syncObject = s
    }

    open func getValue(_ key : Index) -> Future<Element> {
        return self.syncObject.readFuture(executor: .primary) { () -> Element in
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

open class DictionaryWithSynchronization<Key : Hashable, Value, S: SynchronizationProtocol> {
    
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
    
    open func getValue(_ key : Key) -> Future<Value?> {
        return self.syncObject.readFuture(executor: .primary) { () -> Value? in
            return self.dictionary[key]
        }
    }

    open func getValueSync(_ key : Key) -> Value? {
        let value = self.syncObject.lockAndReadSync { () -> Element? in
            let e = self.dictionary[key]
            return e
        }
        return value
    }

    open func setValue(_ value: Value, forKey key: Key) -> Future<Any> {
        return self.syncObject.modifyFuture(executor: .primary) { () -> Any in
            self.dictionary[key] = value
        }
    }

    open func updateValue(_ value: Value, forKey key: Key) -> Future<Value?> {
        return self.syncObject.modifyFuture(executor: .primary) { () -> Value? in
            return self.dictionary.updateValue(value, forKey: key)
        }
    }

    open var count: Int {
        get {
            return self.syncObject.lockAndReadSync { () -> Int in
                return self.dictionary.count
            }
        }
    }
    
    open var isEmpty: Bool {
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


open class ArrayWithSynchronization<T, S: SynchronizationProtocol> : CollectionAccessControl< Array<T> , S> {
    
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
    
    
    open var count: Int {
        get {
            return self.syncObject.lockAndReadSync { () -> Int in
                return self.collection.count
            }
        }
    }

    open var isEmpty: Bool {
        get {
            return self.syncObject.lockAndReadSync { () -> Bool in
                return self.collection.isEmpty
            }
        }
    }

    open var first: T? {
        get {
            return self.syncObject.lockAndReadSync { () -> T? in
                return self.collection.first
            }
        }
    }
    open var last: T? {
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

    
    open func getValue(atIndex i: Int) -> Future<T> {
        return self.syncObject.readFuture(executor: .primary) { () -> T in
            return self.collection[i]
        }
    }

    open func append(_ newElement: T) {
        self.syncObject.lockAndModify {
            self.collection.append(newElement)
        }
    }
    
    open func removeLast() -> T {
        return self.syncObject.lockAndModifySync {
            self.collection.removeLast()
        }
    }
    
    open func insert(_ newElement: T, atIndex i: Int) {
        self.syncObject.lockAndModify {
            self.collection.insert(newElement,at: i)
        }
    }
    
    open func removeAtIndex(_ index: Int) -> T {
        return self.syncObject.lockAndModifySync {
            self.collection.remove(at: index)
        }
    }


}

open class DictionaryWithFastLockAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,SynchronizationType.LightAndFastSyncType> {
    
    typealias LockObjectType = SynchronizationType.LightAndFastSyncType
    
    public  override init() {
        super.init(LockObjectType())
    }
    public  init(d : Dictionary<Key,Value>) {
        super.init(d,LockObjectType())
    }
    
}

open class DictionaryWithBarrierAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,QueueBarrierSynchronization> {

    typealias LockObjectType = QueueBarrierSynchronization

    public  init(queue : DispatchQueue) {
        super.init(LockObjectType(queue: queue))
    }
    public  init(d : Dictionary<Key,Value>,queue : DispatchQueue) {
        super.init(d,LockObjectType(queue: queue))
    }
}



open class ArrayWithFastLockAccess<T> : ArrayWithSynchronization<T,SynchronizationType.LightAndFastSyncType> {
    
    override public init() {
        super.init(array: Array<T>(), SynchronizationType.LightAndFastSyncType())
    }
    
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
