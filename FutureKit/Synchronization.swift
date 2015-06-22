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

    
    // read your object.  The block() code may run asynchronously, but doesn't return any result
    // if you need to read the block and return a result, use readAsync/readSync
    func read(block:() -> Void)
    
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

public enum SynchronizationType : String {
    case BarrierConcurrent = "BarrierConcurrent"
    case BarrierSerial = "BarrierSerial"
    case SerialQueue = "SerialQueue"
    case NSObjectLock = "NSObjectLock"
    case NSLock = "NSLock"
    case NSRecursiveLock = "NSRecursiveLock"
    case OSSpinLock = "OSSpinLock"
    case PThreadMutex = "PThreadMutex"
    
    
    #if os(osx)
    public static let allValues = [BarrierConcurrent, BarrierSerial, SerialQueue,NSObjectLock,NSLock,NSRecursiveLock,OSSpinLock,PThreadMutex]
    #else
    public static let allValues = [BarrierConcurrent, BarrierSerial, SerialQueue,NSObjectLock,NSLock,NSRecursiveLock,OSSpinLock]
    #endif

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
        case PThreadMutex:
            return NSLockSynchronization()
        }
    }
}


let DispatchQueuePoolIsActive = false

public class DispatchQueuePool {
    
    let attr : dispatch_queue_attr_t
    let qos : QosCompatible
    let relative_priority : Int32
    
    let syncObject : SynchronizationProtocol
    
    var queues : [dispatch_queue_t] = []
    
    init(a : dispatch_queue_attr_t, qos q: QosCompatible = .Default, relative_priority p :Int32 = 0) {
        
        self.attr = a
        self.qos = q
        self.relative_priority = p
        let synchObjectBarrierQueue = q.createQueue("DispatchQueuePool-Root", q_attr: a, relative_priority: p)
        self.syncObject = QueueBarrierSynchronization(queue: synchObjectBarrierQueue)
        
    }
    
    final func createNewQueue() -> dispatch_queue_t {
        return self.qos.createQueue(nil, q_attr: self.attr, relative_priority: self.relative_priority)
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
        self.q = QosCompatible.Default.createQueue("QueueBarrierSynchronization", q_attr: DISPATCH_QUEUE_CONCURRENT, relative_priority: 0)
    }
    
    
    public init(type : dispatch_queue_attr_t!, _ q: QosCompatible = .Default, _ p :Int32 = 0) {
        self.q = q.createQueue("QueueBarrierSynchronization", q_attr: type, relative_priority: p)
    }


    public func read(block:() -> Void) {
        dispatch_async(self.q,block)
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
        self.q = QosCompatible.Default.createQueue("QueueSynchronization", q_attr: DISPATCH_QUEUE_SERIAL, relative_priority: 0)
    }
    
    public func read(block:() -> Void) {
        dispatch_async(self.q,block)
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
    
    public func read(block:() -> Void) {
        self.synchronized(block)
    }

    public func readSync<T>(block:() -> T) -> T {
        return self.synchronized(block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = self.synchronized(block)
        done(ret)
    }

    public func modify(block:() -> Void) {
        self.synchronized(block)
    }

    public func modifySync<T>(block:() -> T) -> T {
        return self.synchronized(block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = self.synchronized(block)
        done(ret)
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
    
    public func read(block:() -> Void) {
        synchronizedWithLock(lock,block)
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
    
    public func read(block:() -> Void) {
        synchronizedWithSpinLock(lock,block)
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


func synchronizedWithMutexLock<T>(inout mutex: pthread_mutex_t, @noescape closure:  ()->T) -> T {
    pthread_mutex_lock(&mutex)
    let retVal: T = closure()
    pthread_mutex_unlock(&mutex)
    return retVal
}

#if os(osx)
    
public class PThreadMutexSynchronization : SynchronizationProtocol {
    
    
    var mutex: pthread_mutex_t
    
    required public init() {
        
        // Omg.  Yes.  This is how it's done.
        self.mutex = pthread_mutex_t(__sig: 0, __opaque: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

        pthread_mutex_init(&mutex, nil)
    
    }
    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithMutexLock(&mutex) { () -> T in
            return block()
        }
    }
    
    public func read(block:() -> Void) {
        synchronizedWithMutexLock(&mutex,block)
    }
    
    public func readSync<T>(block:() -> T) -> T {
        return synchronizedWithMutexLock(&mutex,block)
    }
    
    public func readAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithMutexLock(&mutex,block)
        done(ret)
    }
    
    public func modify(block:() -> Void) {
        synchronizedWithMutexLock(&mutex,block)
    }
    
    public func modifySync<T>(block:() -> T) -> T {
        return synchronizedWithMutexLock(&mutex,block)
    }
    
    public func modifyAsync<T>(block:() -> T, done : (T) -> Void) {
        let ret = synchronizedWithMutexLock(&mutex,block)
        done(ret)
    }
    
    deinit {
        pthread_mutex_destroy(&mutex)
    }
}
#else

public typealias PThreadMutexSynchronization = NSLockSynchronization

#endif

public class NSRecursiveLockSynchronization : SynchronizationProtocol {
    
    var lock = NSRecursiveLock()
    
    required public init() {
    }
    
    final func synchronized<T>(block:() -> T) -> T {
        return synchronizedWithLock(self.lock) { () -> T in
            return block()
        }
    }
    
    public func read(block:() -> Void) {
        synchronizedWithLock(lock,block)
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

    public init() {
        self.sync = P()
        self.defaultExecutor = Executor.Immediate
    }

    public init(_ p : P) {
        self.sync = p
        self.defaultExecutor = Executor.Immediate
    }
    
    public init(_ p : P, _ executor : Executor) {
        self.sync = p
        self.defaultExecutor = executor
    }

    public func read(block:() -> Void) {
        self.sync.read(block)
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

    
    public func modifyFuture<T>(block:() -> T) -> Future<T> {
        return self.modifyFuture(self.defaultExecutor,block: block)
    }
    
    public func readFuture<T>(block:() -> T) -> Future<T> {
        return self.readFuture(self.defaultExecutor,block: block)
    }
    
    public func readFuture<T>(executor : Executor, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        
        self.sync.readAsync({ () -> T in
            return block()
        }, done: { (result) -> Void in
            p.completeWithSuccess(result)
        })
        
        return p.future
    }
    public func modifyFuture<T>(executor : Executor, block:() -> T) -> Future<T> {
        let p = Promise<T>()
        self.sync.modifyAsync({ () -> T in
            return block()
        }, done: { (t) -> Void in
            p.completeWithSuccess(t)
        })
        return p.future
    }

    
}

public class CollectionAccessControl<C : MutableCollectionType, S: SynchronizationProtocol> {
    
    public typealias Index  = C.Index
    public typealias Element = C.Generator.Element
   
    var syncObject : SynchronizationObject<S>
    var collection : C
    
    public init(c : C, _ s: SynchronizationObject<S>) {
        self.collection = c
        self.syncObject = s
    }

    public func getValue(key : Index) -> Future<Element> {
        return self.syncObject.readFuture { () -> Element in
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
            self.syncObject.modifySync {
                self.collection[key] = newValue
            }
        }
    } */

}

public class DictionaryWithSynchronization<Key : Hashable, Value, S: SynchronizationProtocol> {
    
    typealias Index  = Key
    typealias Element = Value
    typealias DictionaryType = Dictionary<Key,Value>
    
    var syncObject : SynchronizationObject<S>
    var dictionary : DictionaryType
    
    public init() {
        self.dictionary = DictionaryType()
        self.syncObject = SynchronizationObject<S>()
    }
    
    public init(_ d : DictionaryType, _ s: SynchronizationObject<S>) {
        self.dictionary = d
        self.syncObject = s
    }

    public init(_ s: SynchronizationObject<S>) {
        self.dictionary = DictionaryType()
        self.syncObject = s
    }
    
    public func getValue(key : Key) -> Future<Value?> {
        return self.syncObject.readFuture { () -> Value? in
            return self.dictionary[key]
        }
    }

    public func getValueSync(key : Key) -> Value? {
        let value = self.syncObject.readSync { () -> Element? in
            let e = self.dictionary[key]
            return e
        }
        return value
    }

    public func setValue(value: Value, forKey key: Key) -> Future<Any> {
        return self.syncObject.modifyFuture { () -> Any in
            self.dictionary[key] = value
        }
    }

    public func updateValue(value: Value, forKey key: Key) -> Future<Value?> {
        return self.syncObject.modifyFuture { () -> Value? in
            return self.dictionary.updateValue(value, forKey: key)
        }
    }

    public var count: Int {
        get {
            return self.syncObject.readSync { () -> Int in
                return self.dictionary.count
            }
        }
    }
    
    public var isEmpty: Bool {
        get {
            return self.syncObject.readSync { () -> Bool in
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
//            self.syncObject.modifySync {
//                self.dictionary[key] = newValue
//            }
        }
    } */
}


public class ArrayAccessControl<T, S: SynchronizationProtocol> : CollectionAccessControl< Array<T> , S> {
    
    var array : Array<T> {
        get {
            return self.collection
        }
    }
    
    public init() {
        super.init(c: Array<T>(), SynchronizationObject<S>())
    }
    
    public init(array : Array<T>, _ a: SynchronizationObject<S>) {
        super.init(c: array, a)
    }
    
    public init(a: SynchronizationObject<S>) {
        super.init(c: Array<T>(), a)
    }
    
    
    public var count: Int {
        get {
            return self.syncObject.readSync { () -> Int in
                return self.collection.count
            }
        }
    }

    public var isEmpty: Bool {
        get {
            return self.syncObject.readSync { () -> Bool in
                return self.collection.isEmpty
            }
        }
    }

    public var first: T? {
        get {
            return self.syncObject.readSync { () -> T? in
                return self.collection.first
            }
        }
    }
    public var last: T? {
        get {
            return self.syncObject.readSync { () -> T? in
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
        return self.syncObject.readFuture { () -> T in
            return self.collection[i]
        }
    }

    public func append(newElement: T) {
        self.syncObject.modify {
            self.collection.append(newElement)
        }
    }
    
    public func removeLast() -> T {
        return self.syncObject.modifySync {
            self.collection.removeLast()
        }
    }
    
    public func insert(newElement: T, atIndex i: Int) {
        self.syncObject.modify {
            self.collection.insert(newElement,atIndex: i)
        }
    }
    
    public func removeAtIndex(index: Int) -> T {
        return self.syncObject.modifySync {
            self.collection.removeAtIndex(index)
        }
    }


}

public  class DictionaryWithLockAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,NSObjectLockSynchronization> {
    
    typealias LockObjectType = SynchronizationObject<NSObjectLockSynchronization>
    
    public  override init() {
        super.init(LockObjectType(NSObjectLockSynchronization()))
    }
    public  init(d : Dictionary<Key,Value>) {
        super.init(d,LockObjectType(NSObjectLockSynchronization()))
    }
    
}

public class DictionaryWithBarrierAccess<Key : Hashable, Value> : DictionaryWithSynchronization<Key,Value,QueueBarrierSynchronization> {

    typealias LockObjectType = SynchronizationObject<QueueBarrierSynchronization>

    public  init(queue : dispatch_queue_t) {
        super.init(LockObjectType(QueueBarrierSynchronization(queue: queue)))
    }
    public  init(d : Dictionary<Key,Value>,queue : dispatch_queue_t) {
        super.init(d,LockObjectType(QueueBarrierSynchronization(queue: queue)))
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
