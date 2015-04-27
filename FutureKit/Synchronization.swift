//
//  DispatchQueue.swift
//  Bikey
//
//  Created by Michael Gray on 4/10/15.
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

// this adds some missing feature that we don't have with normal dispatch_queue_t
// like .. what DispatchQueue am I currently running in?
// Add assertions to make sure logic is always running on a specific Queue


// Don't know what sort of synchronization is perfect?
// try them all!
// testing different strategys may result in different performances (depending on your implementations)
public protocol SynchronizationProtocol {
    init()
    
    // modify your object.  The block() code may run asynchronously, but doesn't return any result
    func modify(block:() -> Void)
    
    // modify your shared object and return some value in the process
    // the "done" block could execute inside ANY thread/queue so care should be taken.
    // will try NOT to block the current thread (for Barrier/Queue strategies)
    // Lock strategies may still end up blocking the calling thread.
    func modifyAsync<_ANewType>(block:() -> _ANewType, done : (_ANewType) -> Void)
    
    // modify your container and retrieve a result/element to the same calling thread
    // current thread will block until the modifyBlock is done running.
    func modifySync<_ANewType>(block:() -> _ANewType) -> _ANewType

    // perform a readonly query of your shared object and return some value/element T
    // current thread may block until the read block is done running.
    // do NOT modify your object inside this block
    func readSync<_ANewType>(block:() -> _ANewType) -> _ANewType
    
    // perform a readonly query of your object and return some value/element of type _ANewType.
    // the results are delivered async inside the done() block.
    // the done block is NOT protected by the synchronization - do not modify your shared data inside the "done:" block
    // the done block could execute inside ANY thread/queue so care should be taken
    // do NOT modify your object inside this block
    func readAsync<_ANewType>(block:() -> _ANewType, done : (_ANewType) -> Void)

}

public enum SynchronizationType {
    case BarrierConcurrent
    case BarrierSerial
    case SerialQueue
    case NSObjectLock
    case NSLock
    case NSRecursiveLock
    case OSSpinLock
    
    func lockObject() -> SynchronizationProtocol {
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
        }
    }
}


let DispatchQueuePoolIsActive = false

class DispatchQueuePool {
    
    let attr : dispatch_queue_attr_t
    let qos : qos_class_t
    let relative_priority : Int32
    
    let syncObject : SynchronizationProtocol
    
    var queues : [dispatch_queue_t] = []
    
    init(a : dispatch_queue_attr_t, qos q: qos_class_t = QOS_CLASS_DEFAULT, relative_priority p :Int32 = 0) {
        self.attr = a
        self.qos = q
        self.relative_priority = p
        
        let c_attr = dispatch_queue_attr_make_with_qos_class(self.attr,self.qos, self.relative_priority)
        let synchObjectBarrierQueue = dispatch_queue_create("DispatchQueuePool-Root", c_attr)
        
        self.syncObject = QueueBarrierSynchronization(queue: synchObjectBarrierQueue)
        
    }
    
    final func createNewQueue() -> dispatch_queue_t {
        let c_attr = dispatch_queue_attr_make_with_qos_class(self.attr,self.qos, self.relative_priority)
        return dispatch_queue_create(nil, c_attr)
    }
    
    func getQueue() -> dispatch_queue_t {
        if (DispatchQueuePoolIsActive) {
            let queue = self.syncObject.modifySync { () -> dispatch_queue_t? in
                if let q = self.queues.last {
                    self.queues.removeLast()
                    return q
                }
                else {
                    return nil
                }
            }
            if let q = queue {
                return q
            }
        }
        return self.createNewQueue()
    }
    
    func recycleQueue(q: dispatch_queue_t) {
        if (DispatchQueuePoolIsActive) {
            self.syncObject.modify { () -> Void in
                self.queues.append(q)
            }
        }
    }
    func flushQueue(keepCapacity : Bool = false) {
        self.syncObject.modify { () -> Void in
            self.queues.removeAll(keepCapacity: keepCapacity)
        }
        
    }
    
}

/* public var serialQueueDispatchPool = DispatchQueuePool(a: DISPATCH_QUEUE_SERIAL, qos: QOS_CLASS_DEFAULT, relative_priority: 0)
public var concurrentQueueDispatchPool = DispatchQueuePool(a: DISPATCH_QUEUE_CONCURRENT, qos: QOS_CLASS_DEFAULT, relative_priority: 0)

public var defaultBarrierDispatchPool = concurrentQueueDispatchPool */

public class QueueBarrierSynchronization : SynchronizationProtocol {
    
    var q : dispatch_queue_t
    
    init(queue : dispatch_queue_t) {
        self.q = queue
    }
    
    required public init() {
        let c_attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT,QOS_CLASS_DEFAULT, 0)
        self.q = dispatch_queue_create("QueueBarrierSynchronization", c_attr)
    }
    
    
    init(type : dispatch_queue_attr_t, _ q: qos_class_t = QOS_CLASS_DEFAULT, _ p :Int32 = 0) {
        let c_attr = dispatch_queue_attr_make_with_qos_class(type,q, p)
        self.q = dispatch_queue_create("QueueBarrierSynchronization", c_attr)
    }

    
    public func readSync<T>(block:() -> T) -> T {
        var ret : T?
        dispatch_sync(self.q) {
            ret = block()
        }
        return ret!
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        dispatch_async(self.q) {
            done(block())
        }
    }
    
    public func modify(block:() -> Void) {
        dispatch_barrier_async(self.q,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        dispatch_barrier_async(self.q) {
            done(block())
        }
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        var ret : T?
        dispatch_barrier_sync(self.q) {
            ret = block()
        }
        return ret!
    }
    
}

public class QueueSerialSynchronization : SynchronizationProtocol {
    
    var q : dispatch_queue_t
    
    init(queue : dispatch_queue_t) {
        self.q = queue
    }
    
    required public init() {
        let c_attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_DEFAULT, 0)
        self.q = dispatch_queue_create("QueueSynchronization", c_attr)
    }
    
    public func readSync<T>(block:() -> T) -> T {
        var ret : T?
        dispatch_sync(self.q) {
            ret = block()
        }
        return ret!
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        dispatch_async(self.q) {
            done(block())
        }
    }
    
    public func modify(block:() -> Void) {
        dispatch_async(self.q,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        dispatch_async(self.q) {
            done(block())
        }
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        var ret : T?
        dispatch_sync(self.q) {
            ret = block()
        }
        return ret!
    }
    
}

class NSObjectLockSynchronization : SynchronizationProtocol {

    var lock : AnyObject
    
    required init() {
        self.lock = NSObject()
    }
    
    init(lock l: AnyObject) {
        self.lock = l
    
    }
    
    func synchronized<T>(block:() -> T) -> T {
        return SYNCHRONIZED(self.lock) { () -> T in
            return block()
        }
    }
    
    func readSync<T>(block:() -> T) -> T {
        return self.synchronized(block)
    }
    
    func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = self.synchronized(block)
        done(ret)
    }

    func modify(block:() -> Void) {
        self.synchronized(block)
    }

    func modifySync<T>(block:() -> T) -> T {
        return self.synchronized(block)
    }
    
    func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = self.synchronized(block)
        done(ret)
    }
}

func synchronizedWithLock<T>(l: NSLocking, @noescape closure:  ()->T) -> T {
    l.lock()
    var retVal: T = closure()
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
    
    public func readSync<T>(block:() -> T) -> T {
        return synchronizedWithLock(lock,block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithLock(lock,block)
        done(ret)
    }
    
    public func modify(block:() -> Void) {
        synchronizedWithLock(lock,block)
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        return synchronizedWithLock(lock,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithLock(lock,block)
        done(ret)
    }
}

func synchronizedWithSpinLock<T>(l: UnSafeMutableContainer<OSSpinLock>, @noescape closure:  ()->T) -> T {
    OSSpinLockLock(l.unsafe_pointer)
    var retVal: T = closure()
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
    
    public func readSync<T>(block:() -> T) -> T {
        return synchronizedWithSpinLock(lock,block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithSpinLock(lock,block)
        done(ret)
    }
    
    public func modify(block:() -> Void) {
        synchronizedWithSpinLock(lock,block)
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        return synchronizedWithSpinLock(lock,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithSpinLock(lock,block)
        done(ret)
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
    
    public func readSync<T>(block:() -> T) -> T {
        return synchronizedWithLock(lock,block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithLock(lock,block)
        done(ret)
    }
    
    public func modify(block:() -> Void) {
        synchronizedWithLock(lock,block)
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        return synchronizedWithLock(lock,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithLock(lock,block)
        done(ret)
    }
}



// wraps your synch strategy into a Future
// increases 'composability'
// warning: Future has it's own lockObject (usually NSLock)
public class SynchronizationObject<P : SynchronizationProtocol> {
    
    let sync : P
    let defaultExecutor : Executor // used to execute 'done' blocks for async lookups
    
    public init(_ p : P) {
        self.sync = p
        self.defaultExecutor = Executor.Immediate
    }
    
    public init(_ p : P, _ executor : Executor) {
        self.sync = p
        self.defaultExecutor = executor
    }
    
    public func readSync<T>(block:() -> T) -> T {
        return self.sync.readSync(block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        return self.sync.readAsync(block,done: done)
    }
    
    public func modify(block:() -> Void) {
        self.sync.modify(block)
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        return self.sync.modifySync(block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        return self.sync.modifyAsync(block,done: done)
    }

    
    public func modify<T>(future b:() -> T) -> Future<T> {
        return self.modify(b, executor: self.defaultExecutor)
    }
    
    public func read<T>(future b:() -> T) -> Future<T> {
        return self.read(b, executor: self.defaultExecutor)
    }
    
    public func read<T>(block:() -> T, executor : Executor) -> Future<T> {
        let p = Promise<T>()
        
        self.sync.readAsync({ () -> T in
            return block()
        }, done: { (result) -> Void in
            p.completeWithSuccess(result)
        })
        
        return p.future
    }
    public func modify<T>(block:() -> T, executor : Executor) -> Future<T> {
        let p = Promise<T>()
        self.sync.modifyAsync({ () -> T in
            return block()
        }, done: { (t) -> Void in
            p.completeWithSuccess(t)
        })
        return p.future
    }

    
}

class CollectionAccessControl<C : MutableCollectionType, S: SynchronizationProtocol> {
    
    typealias Index  = C.Index
    typealias Element = C.Generator.Element
   
    var syncObject : SynchronizationObject<S>
    var collection : C
    
    init(c : C, _ s: SynchronizationObject<S>) {
        self.collection = c
        self.syncObject = s
    }

    func getValue(key : Index) -> Future<Element> {
        return self.syncObject.read(future: { () -> Element in
            return self.collection[key]
        })
    }
    
    subscript (key: Index) -> Element {
        get {
            return self.syncObject.readSync { () -> Element in
                return self.collection[key]
            }
        }
        set(newValue) {
            self.syncObject.modifySync {
                self.collection[key] = newValue
            }
        }
    }

}

class DictionaryAccessControl<Key : Hashable, Value, S: SynchronizationProtocol> {
    
    typealias Index  = Key
    typealias Element = Value
    typealias DictionaryType = Dictionary<Key,Value>
    
    var syncObject : SynchronizationObject<S>
    var dictionary : DictionaryType
    
    init(_ d : DictionaryType, _ s: SynchronizationObject<S>) {
        self.dictionary = d
        self.syncObject = s
    }

    init(_ s: SynchronizationObject<S>) {
        self.dictionary = DictionaryType()
        self.syncObject = s
    }
    
    func getValue(key : Key) -> Future<Value?> {
        return self.syncObject.read(future: { () -> Value? in
            return self.dictionary[key]
        })
    }

    
    var count: Int {
        get {
            return self.syncObject.readSync { () -> Int in
                return self.dictionary.count
            }
        }
    }
    
    var isEmpty: Bool {
        get {
            return self.syncObject.readSync { () -> Bool in
                return self.dictionary.isEmpty
            }
        }
    }

    subscript (key: Key) -> Value? {
        get {
            return self.syncObject.readSync { () -> Element? in
                return self.dictionary[key]
            }
        }
        set(newValue) {
            self.syncObject.modifySync {
                self.dictionary[key] = newValue
            }
        }
    }
}


class ArrayAccessControl<T, S: SynchronizationProtocol> : CollectionAccessControl< Array<T> , S> {
    
    var array : Array<T> {
        get {
            return self.collection
        }
    }
    
    init(array : Array<T>, _ a: SynchronizationObject<S>) {
        super.init(c: array, a)
    }
    
    init(a: SynchronizationObject<S>) {
        super.init(c: Array<T>(), a)
    }
    
    
    var count: Int {
        get {
            return self.syncObject.readSync { () -> Int in
                return self.collection.count
            }
        }
    }

    var isEmpty: Bool {
        get {
            return self.syncObject.readSync { () -> Bool in
                return self.collection.isEmpty
            }
        }
    }

    var first: T? {
        get {
            return self.syncObject.readSync { () -> T? in
                return self.collection.first
            }
        }
    }
    var last: T? {
        get {
            return self.syncObject.readSync { () -> T? in
                return self.collection.last
            }
        }
    }
    
    func append(newElement: T) {
        self.syncObject.modify {
            self.collection.append(newElement)
        }
    }
    
    func removeLast() -> T {
        return self.syncObject.modifySync {
            self.collection.removeLast()
        }
    }
    
    func insert(newElement: T, atIndex i: Int) {
        self.syncObject.modify {
            self.collection.insert(newElement,atIndex: i)
        }
    }
    
    func removeAtIndex(index: Int) -> T {
        return self.syncObject.modifySync {
            self.collection.removeAtIndex(index)
        }
    }


}

class DictionaryWithLockAccess<Key : Hashable, Value> : DictionaryAccessControl<Key,Value,NSObjectLockSynchronization> {
    
    typealias LockObjectType = SynchronizationObject<NSObjectLockSynchronization>
    
    init() {
        super.init(LockObjectType(NSObjectLockSynchronization()))
    }
    init(d : Dictionary<Key,Value>) {
        super.init(d,LockObjectType(NSObjectLockSynchronization()))
    }
    
}

class DictionaryWithBarrierAccess<Key : Hashable, Value> : DictionaryAccessControl<Key,Value,QueueBarrierSynchronization> {

    typealias LockObjectType = SynchronizationObject<QueueBarrierSynchronization>

    init(queue : dispatch_queue_t) {
        super.init(LockObjectType(QueueBarrierSynchronization(queue: queue)))
    }
    init(d : Dictionary<Key,Value>,queue : dispatch_queue_t) {
        super.init(d,LockObjectType(QueueBarrierSynchronization(queue: queue)))
    }
}


func dispatch_queue_create_compatibleIOS8(label : String,
    attr : dispatch_queue_attr_t,
    qos_class : dispatch_qos_class_t,relative_priority : Int32) -> dispatch_queue_t
{
        let c_attr = dispatch_queue_attr_make_with_qos_class(attr,qos_class, relative_priority)
        let queue = dispatch_queue_create(label, c_attr)
        return queue;
}



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
