//
//  Executor.swift
//  FutureKit
//
//  Created by Michael Gray on 4/13/15.
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
import CoreData


public extension NSQualityOfService {
    
    public var qos_class : qos_class_t {
        get {
            switch self {
            case .UserInteractive:
                return QOS_CLASS_USER_INTERACTIVE
            case .UserInitiated:
                return QOS_CLASS_USER_INITIATED
            case .Default:
                return QOS_CLASS_DEFAULT
            case .Utility:
                return QOS_CLASS_UTILITY
            case .Background:
                return QOS_CLASS_BACKGROUND
            }
        }
    }
}

final public class Box<T> {
    public let value: T
    public init(_ v: T) { self.value = v }
}

public enum QosCompatible : Int {
    /* UserInteractive QoS is used for work directly involved in providing an interactive UI such as processing events or drawing to the screen. */
    case UserInteractive
    
    /* UserInitiated QoS is used for performing work that has been explicitly requested by the user and for which results must be immediately presented in order to allow for further user interaction.  For example, loading an email after a user has selected it in a message list. */
    case UserInitiated
    
    /* Utility QoS is used for performing work which the user is unlikely to be immediately waiting for the results.  This work may have been requested by the user or initiated automatically, does not prevent the user from further interaction, often operates at user-visible timescales and may have its progress indicated to the user by a non-modal progress indicator.  This work will run in an energy-efficient manner, in deference to higher QoS work when resources are constrained.  For example, periodic content updates or bulk file operations such as media import. */
    case Utility
    
    /* Background QoS is used for work that is not user initiated or visible.  In general, a user is unaware that this work is even happening and it will run in the most efficient manner while giving the most deference to higher QoS work.  For example, pre-fetching content, search indexing, backups, and syncing of data with external systems. */
    case Background
    
    /* Default QoS indicates the absence of QoS information.  Whenever possible QoS information will be inferred from other sources.  If such inference is not possible, a QoS between UserInitiated and Utility will be used. */
    case Default
    
    
   var qos_class : qos_class_t {
        switch self {
        case .UserInteractive:
            return QOS_CLASS_USER_INTERACTIVE
        case .UserInitiated:
            return QOS_CLASS_USER_INITIATED
        case .Utility:
            return QOS_CLASS_UTILITY
        case .Background:
            return QOS_CLASS_BACKGROUND
        case .Default:
            return QOS_CLASS_DEFAULT
        }

    }
    
    var queue : dispatch_queue_t {
        
        switch self {
        case .UserInteractive:
            return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE,0)
        case .UserInitiated:
            return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0)
        case .Utility:
            return dispatch_get_global_queue(QOS_CLASS_UTILITY,0)
        case .Background:
            return dispatch_get_global_queue(QOS_CLASS_BACKGROUND,0)
        case .Default:
            return dispatch_get_global_queue(QOS_CLASS_DEFAULT,0)
            
        }
    }
    
    public func createQueue(label: String?,
        q_attr : dispatch_queue_attr_t!,
        relative_priority: Int32 = 0) -> dispatch_queue_t {
            
            let qos_class = self.qos_class
            let nq_attr = dispatch_queue_attr_make_with_qos_class(q_attr,qos_class, relative_priority)
            let q : dispatch_queue_t
            if let l = label {
                q = dispatch_queue_create(l, nq_attr)
            }
            else {
                q = dispatch_queue_create(nil, nq_attr)
            }
            return q
    }

    
}

private func make_dispatch_block<T>(q: dispatch_queue_t, _ block: (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        dispatch_async(q) {
            block(t)
        }
    }
    return newblock
}

private func make_dispatch_block<T>(q: NSOperationQueue, _ block: (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        q.addOperationWithBlock({ () -> Void in
            block(t)
        })
    }
    return newblock
}

public enum SerialOrConcurrent: Int {
    case Serial
    case Concurrent
    
    public var q_attr : dispatch_queue_attr_t! {
        switch self {
        case .Serial:
            return DISPATCH_QUEUE_SERIAL
        case .Concurrent:
            return DISPATCH_QUEUE_CONCURRENT
        }
    }
    
}

// remove in Swift 2.0

extension qos_class_t {
    var rawValue : UInt32 {
        return self.rawValue
    }
}
public enum Executor {
    case Primary                    // use the default configured executor.  Current set to Immediate.
                                    // There are deep philosphical arguments about Immediate vs Async.
                                    // So whenever we figure out what's better we will set the Primary to that!
    
    case Main                       // will use MainAsync or MainImmediate based on MainStrategy

    case Async                      // Always performs an Async Dispatch to some non-main q (usually Default)
                                    // If you want to put all of these in a custom queue, you can set AsyncStrategy to .Queue(q)

    case Current                    // Will try to use the current Executor.
                                    // If the current block isn't running in an Executor, will return Main if running in the main thread, otherwise .Async

    case CurrentAsync               // Will try to use the current Executor, but guarantees that the operation will always call a dispatch_async() before executing.
                                    // If the current block isn't running in an Executor, will return MainAsync if running in the main thread, otherwise .Async
    

    case Immediate                  // Never performs an Async Dispatch, Ok for simple mappings. But use with care!
    // Blocks using the Immediate executor can run in ANY Block

    case StackCheckingImmediate     // Will try to perform immediate, but does some stack checking.  Safer than Immediate
                                    // But is less efficient.  
                                    // Maybe useful if an Immediate handler is somehow causing stack overflow issues
    
    
    case MainAsync                  // will always do a dispatch_async to the mainQ
    case MainImmediate              // will try to avoid dispatch_async if already on the MainQ
    
    case UserInteractive            // QOS_CLASS_USER_INTERACTIVE
    case UserInitiated              // QOS_CLASS_USER_INITIATED
    case Default                    // QOS_CLASS_DEFAULT
    case Utility                    // QOS_CLASS_UTILITY
    case Background                 // QOS_CLASS_BACKGROUND
    
    case Queue(dispatch_queue_t)    // Dispatch to a Queue of your choice!
                                    // Use this for your own custom queues
    
    
    case OperationQueue(NSOperationQueue)    // Dispatch to a Queue of your choice!
                                             // Use this for your own custom queues
    
    case ManagedObjectContext(NSManagedObjectContext)   // block will run inside the managed object's context via context.performBlock()
    
    case Custom(((() -> Void) -> Void))         // Don't like any of these?  Bake your own Executor!
    
    
    public var description : String {
        switch self {
        case .Primary:
            return "Primary"
        case .Main:
            return "Main"
        case .Async:
            return "Async"
        case .Current:
            return "Current"
        case .CurrentAsync:
            return "CurrentAsync"
        case .Immediate:
            return "Immediate"
        case .StackCheckingImmediate:
            return "StackCheckingImmediate"
        case .MainAsync:
            return "MainAsync"
        case .MainImmediate:
            return "MainImmediate"
        case .UserInteractive:
            return "UserInteractive"
        case .UserInitiated:
            return "UserInitiated"
        case .Default:
            return "Default"
        case .Utility:
            return "Utility"
        case .Background:
            return "Background"
        case let .Queue(q):
            let clabel = dispatch_queue_get_label(q)
            let (s, _) = String.fromCStringRepairingIllFormedUTF8(clabel)
            let n = s ?? "(null)"
            return "Queue(\(n))"
        case let .OperationQueue(oq):
            let name = oq.name ?? "??"
            return "OperationQueue(\(name))"
        case .ManagedObjectContext:
            return "ManagedObjectContext"
        case .Custom:
            return "Custom"
        }
    }
    
    public typealias CustomCallBackBlock = ((block:() -> Void) -> Void)

    public static var PrimaryExecutor = Executor.Current {
        willSet(newValue) {
            switch newValue {
            case .Primary:
                assertionFailure("Nope.  Nope. Nope.")
            case .Main,.MainAsync,MainImmediate:
                NSLog("it's probably a bad idea to set .Primary to the Main Queue. You have been warned")
            default:
                break
            }
        }
    }
    public static var MainExecutor = Executor.MainImmediate {
        willSet(newValue) {
            switch newValue {
            case .MainImmediate, .MainAsync, .Custom:
                break
            default:
                assertionFailure("MainStrategy must be either .MainImmediate or .MainAsync or .Custom")
            }
        }
    }
    public static var AsyncExecutor = Executor.Default {
        willSet(newValue) {
            switch newValue {
            case .Immediate, .StackCheckingImmediate,.MainImmediate:
                assertionFailure("AsyncStrategy can't be Immediate!")
            case .Async, .Main, .Primary, .Current, .CurrentAsync:
                assertionFailure("Nope.  Nope. Nope. AsyncStrategy can't be .Async, .Main, .Primary, .Current!, .CurrentAsync")
            case .MainAsync:
                NSLog("it's probably a bad idea to set .Async to the Main Queue. You have been warned")
            case let .Queue(q):
                assert(!(q !== dispatch_get_main_queue()),"Async is not for the mainq")
            default:
                break
            }
        }
    }
    
    private static let mainQ            = dispatch_get_main_queue()
    private static let userInteractiveQ = QosCompatible.UserInteractive.queue
    private static let userInitiatedQ   = QosCompatible.UserInitiated.queue
    private static let defaultQ         = QosCompatible.Default.queue
    private static let utilityQ         = QosCompatible.Utility.queue
    private static let backgroundQ      = QosCompatible.Background.queue
    
    init(qos: QosCompatible) {
        switch qos {
        case .UserInteractive:
            self = .UserInteractive
        case .UserInitiated:
            self = .UserInitiated
        case .Default:
            self = .Default
        case .Utility:
            self = .Utility
        case .Background:
            self = .Background
        }
    }
    
    @available(iOS 8.0, *)
    init(qos_class: qos_class_t) {
        switch qos_class.rawValue {
        case QOS_CLASS_USER_INTERACTIVE.rawValue:
            self = .UserInteractive
        case QOS_CLASS_USER_INITIATED.rawValue:
            self = .UserInitiated
        case QOS_CLASS_DEFAULT.rawValue:
            self = .Default
        case QOS_CLASS_UTILITY.rawValue:
            self = .Utility
        case QOS_CLASS_BACKGROUND.rawValue:
            self = .Background
        case QOS_CLASS_UNSPECIFIED.rawValue:
            self = .Default
        default:
            assertionFailure("invalid argument \(qos_class)")
            self = .Default
        }
    }
    init(queue: dispatch_queue_t) {
        self = .Queue(queue)
    }
    init(opqueue: NSOperationQueue) {
        self = .OperationQueue(opqueue)
    }

    public static func createQueue(label: String?,
        type : SerialOrConcurrent,
        qos : QosCompatible = .Default,
        relative_priority: Int32 = 0) -> Executor {
            
            let q = qos.createQueue(label, q_attr: type.q_attr, relative_priority: relative_priority)
            return .Queue(q)
    }
    
    public static func createOperationQueue(name: String?,
        maxConcurrentOperationCount : Int) -> Executor {
            
            let oq = NSOperationQueue()
            oq.name = name
            return .OperationQueue(oq)
            
    }
    
    public static func createConcurrentQueue(label : String? = nil,qos : QosCompatible = .Default) -> Executor  {
        return self.createQueue(label, type: .Concurrent, qos: qos, relative_priority: 0)
    }
    public static func createConcurrentQueue() -> Executor  {
        return self.createQueue(nil, type: .Concurrent, qos: .Default, relative_priority: 0)
    }
    public static func createSerialQueue(label : String? = nil,qos : QosCompatible = .Default) -> Executor  {
        return self.createQueue(label, type: .Serial, qos: qos, relative_priority: 0)
    }
    public static func createSerialQueue() -> Executor  {
        return self.createQueue(nil, type: .Serial, qos: .Default, relative_priority: 0)
    }

    // immediately 'dispatches' and executes a block on an Executor
    // example:
    //
    //    Executor.Background.execute {
    //          // insert code to run in the QOS_CLASS_BACKGROUND queue!
    //     }
    //
    public func executeBlock(block b: dispatch_block_t) {
        let executionBlock = self.callbackBlockFor(b)
        executionBlock()
    }

    public func execute<__Type>(block: () throws -> __Type) -> Future<__Type> {
        let p = Promise<__Type>()
        self.executeBlock { () -> Void in
            do {
                let s = try block()
                p.completeWithSuccess(s)
            }
            catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }
    
    public func execute<__Type>(block: () throws -> Future<__Type>) -> Future<__Type> {
        let p = Promise<__Type>()
        self.executeBlock { () -> Void in
            do {
                try block().onComplete { (value) -> Void in
                    p.complete(value)
                }
            }
            catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }
    
    public func execute<__Type>(block: () throws -> Completion<__Type>) -> Future<__Type> {
        let p = Promise<__Type>()
        self.executeBlock { () -> Void in
            do {
                let c = try block()
                p.complete(c)
            }
            catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }

    
    internal func _executeAfterDelay<__Type>(nanosecs n: Int64, block: () throws -> Completion<__Type>) -> Future<__Type> {
        let p = Promise<__Type>()
        let popTime = dispatch_time(DISPATCH_TIME_NOW, n)
        let q = self.underlyingQueue ?? Executor.defaultQ
        dispatch_after(popTime, q, {
            p.completeWithBlock {
                return try block()
            }
        })
        return p.future
    }
    public func executeAfterDelay<__Type>(secs : NSTimeInterval,  block: () throws -> Future<__Type>) -> Future<__Type> {
        let nanosecsDouble = secs * NSTimeInterval(NSEC_PER_SEC)
        let nanosecs = Int64(nanosecsDouble)
        return self._executeAfterDelay(nanosecs: nanosecs) { () -> Completion<__Type> in
            return .CompleteUsing(try block())
        }
    }
    public func executeAfterDelay<__Type>(secs : NSTimeInterval,  block: () throws -> __Type) -> Future<__Type> {
        let nanosecsDouble = secs * NSTimeInterval(NSEC_PER_SEC)
        let nanosecs = Int64(nanosecsDouble)
        return self._executeAfterDelay(nanosecs: nanosecs) { () -> Completion<__Type> in
            return .Success(try block())
        }
    }

    // This returns the underlyingQueue (if there is one).
    // Not all executors have an underlyingQueue.
    // .Custom will always return nil, even if the implementation may include one.
    //
    var underlyingQueue: dispatch_queue_t? {
        get {
            switch self {
            case .Primary:
                return Executor.PrimaryExecutor.underlyingQueue
            case .Main, MainImmediate, MainAsync:
                return Executor.mainQ
            case .Async:
                return Executor.AsyncExecutor.underlyingQueue
            case UserInteractive:
                return Executor.userInteractiveQ
            case UserInitiated:
                return Executor.userInitiatedQ
            case Default:
                return Executor.defaultQ
            case Utility:
                return Executor.utilityQ
            case Background:
                return Executor.backgroundQ
            case let .Queue(q):
                return q
            case let .OperationQueue(opQueue):
                return opQueue.underlyingQueue
            case let .ManagedObjectContext(context):
                if (context.concurrencyType == .MainQueueConcurrencyType) {
                    return Executor.mainQ
                }
                else {
                    return nil
                }
            default:
                return nil
            }
        }
    }
    
    static var SmartCurrent : Executor {  // should always return a 'real` executor, never a virtual one, like Main, Current, Immediate
        get {
            if let current = getCurrentExecutor() {
                return current
            }
            if (NSThread.isMainThread()) {
                return self.MainExecutor.real_executor
            }
            return .Async
        }
    }
    
    /**
        So this will try and find the if the current code is running inside of an executor block.
        It uses a Thread dictionary to maintain the current running Executor.
        Will never return .Immediate, instead it will return the actual running Executor if known
    */
    public static func getCurrentExecutor() -> Executor? {
        let threadDict = NSThread.currentThread().threadDictionary
        let r = threadDict[GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY] as? Box<Executor>
        return r?.value
    }
    
    public static func getCurrentQueue() -> dispatch_queue_t? {
        return getCurrentExecutor()?.underlyingQueue
    }
    
    
    
    /**
        Will compare to Executors.
        warning: .Custom Executors can't be compared and will always return 'false' when compared.
    */
    public func isEqualTo(e:Executor) -> Bool {
        switch self {
        case .Primary:
            if case .Primary = e { return true } else { return false }
        case .Main:
            if case .Main = e { return true } else { return false }
        case .Async:
            if case .Async = e { return true } else { return false }
        case .Current:
            if case .Current = e { return true } else { return false }
        case .CurrentAsync:
            if case .CurrentAsync = e { return true } else { return false }
        case .MainImmediate:
            if case .MainImmediate = e { return true } else { return false }
        case .MainAsync:
            if case .MainAsync = e { return true } else { return false }
        case UserInteractive:
            if case .UserInteractive = e { return true } else { return false }
        case UserInitiated:
            if case .UserInitiated = e { return true } else { return false }
        case Default:
            if case .Default = e { return true } else { return false }
        case Utility:
            if case .Utility = e { return true } else { return false }
        case Background:
            if case .Background = e { return true } else { return false }
        case let .Queue(q):
            if case let .Queue(q2) = e {
                return q === q2
            }
            return false
        case let .OperationQueue(opQueue):
            if case let .OperationQueue(opQueue2) = e {
                return opQueue === opQueue2
            }
            return false
        case let .ManagedObjectContext(context):
            if case let .ManagedObjectContext(context2) = e {
                return context === context2
            }
            return false
        case .Immediate:
            if case .Immediate = e { return true } else { return false }
        case .StackCheckingImmediate:
            if case .StackCheckingImmediate = e { return true } else { return false }
        case .Custom:
            // anyone know a good way to compare closures?
            return false
        }
        
    }
    
    var isTheCurrentlyRunningExecutor : Bool {
        if case .Custom = self {
            NSLog("we can't compare Custom Executors!  isTheCurrentlyRunningExecutor will always return false when executing .Custom")
            return false
        }
        if let e = Executor.getCurrentExecutor() {
            return self.isEqualTo(e)
        }
        return false
    }
    // returns the previous Executor
    private static func setCurrentExecutor(e:Executor?) -> Executor? {
        let threadDict = NSThread.currentThread().threadDictionary
        let key = GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY
        let current = threadDict[key] as? Box<Executor>
        if let ex = e {
            threadDict.setObject(Box<Executor>(ex), forKey: key)
        }
        else {
            threadDict.removeObjectForKey(key)
        }
        return current?.value
    }

    public func callbackBlockFor<T>(block: (T) -> Void) -> ((T) -> Void) {
        
        let currentExecutor = self.real_executor
        
        switch currentExecutor {
        case .Immediate,.StackCheckingImmediate:
            return currentExecutor.getblock_for_callbackBlockFor(block)
        default:
            let wrappedBlock = { (t:T) -> Void in
                let previous = Executor.setCurrentExecutor(currentExecutor)
                block(t)
                Executor.setCurrentExecutor(previous)
            }
            return currentExecutor.getblock_for_callbackBlockFor(wrappedBlock)
        }
    }

    
    /*  
        we need to figure out what the real executor we need to guarantee that execution will happen asyncronously.
        This maps the 'best' executor to guarantee a dispatch_async() to use given the current executor
    
        Most executors are already async, and in that case this will return 'self'
    */
    private var asyncExecutor : Executor {
        
        switch self {
        case .Primary:
            return Executor.PrimaryExecutor.asyncExecutor
        case .Main, .MainImmediate:
            return .MainAsync
        case .Current, .CurrentAsync:
            return Executor.SmartCurrent.asyncExecutor
        case .Immediate, .StackCheckingImmediate:
            return Executor.AsyncExecutor
            
        case let .ManagedObjectContext(context):
            if (context.concurrencyType == .MainQueueConcurrencyType) {
                return .MainAsync
            }
            else {
                return self
            }
        default:
            return self
        }
    }
    
    /*  we need to figure out what the real executor will be used
        'unwraps' the virtual Executors like .Primary,.Main,.Async,.Current
    */
    private var real_executor : Executor {
        
        switch self {
        case .Primary:
            return Executor.PrimaryExecutor.real_executor
        case .Main:
            return Executor.MainExecutor.real_executor
        case .Async:
            return Executor.AsyncExecutor.real_executor
        case .Current:
            return Executor.SmartCurrent
        case .CurrentAsync:
            return Executor.SmartCurrent.asyncExecutor
        case let .ManagedObjectContext(context):
            if (context.concurrencyType == .MainQueueConcurrencyType) {
                return Executor.MainExecutor.real_executor
            }
            else {
                return self
            }
        default:
            return self
        }
    }
    
    private func getblock_for_callbackBlockFor<T>(block: (T) -> Void) -> ((T) -> Void) {
        
        switch self {
        case .Primary:
            return Executor.PrimaryExecutor.getblock_for_callbackBlockFor(block)
        case .Main:
            return Executor.MainExecutor.getblock_for_callbackBlockFor(block)
        case .Async:
            return Executor.AsyncExecutor.getblock_for_callbackBlockFor(block)
            
        case .Current:
            return Executor.SmartCurrent.getblock_for_callbackBlockFor(block)

        case .CurrentAsync:
            return Executor.SmartCurrent.asyncExecutor.getblock_for_callbackBlockFor(block)

        case .MainImmediate:
            let newblock = { (t:T) -> Void in
                if (NSThread.isMainThread()) {
                    block(t)
                }
                else {
                    dispatch_async(Executor.mainQ) {
                        block(t)
                    }
                }
            }
            return newblock
        case .MainAsync:
            return make_dispatch_block(Executor.mainQ,block)
            
        case UserInteractive:
            return make_dispatch_block(Executor.userInteractiveQ,block)
        case UserInitiated:
            return make_dispatch_block(Executor.userInitiatedQ,block)
        case Default:
            return make_dispatch_block(Executor.defaultQ,block)
        case Utility:
            return make_dispatch_block(Executor.utilityQ,block)
        case Background:
            return make_dispatch_block(Executor.backgroundQ,block)
            
        case let .Queue(q):
            return make_dispatch_block(q,block)
            
        case let .OperationQueue(opQueue):
            return make_dispatch_block(opQueue,block)
            
        case let .ManagedObjectContext(context):
            if (context.concurrencyType == .MainQueueConcurrencyType) {
                return Executor.MainExecutor.getblock_for_callbackBlockFor(block)
            }
            else {
                let newblock = { (t:T) -> Void in
                    context.performBlock {
                        block(t)
                    }
                }
                return newblock
            }
            
            
        case .Immediate:
            return block
        case .StackCheckingImmediate:
            let b  = { (t:T) -> Void in
                var currentDepth : NSNumber
                let threadDict = NSThread.currentThread().threadDictionary
                if let c = threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] as? NSNumber {
                    currentDepth = c
                }
                else {
                    currentDepth = 0
                }
                if (currentDepth.integerValue > GLOBAL_PARMS.STACK_CHECKING_MAX_DEPTH) {
                    let b = Executor.AsyncExecutor.callbackBlockFor(block)
                    b(t)
                }
                else {
                    let newDepth = NSNumber(int:currentDepth.integerValue+1)
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = newDepth
                    block(t)
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = currentDepth
                }
            }
            return b
            
        case let .Custom(customCallBack):
            
            let b = { (t:T) -> Void in
                customCallBack { () -> Void in
                    block(t)
                }
            }
            
            return b
        }
    }
    
}

let example_of_a_Custom_Executor_That_Is_The_Same_As_MainAsync = Executor.Custom { (callback) -> Void in
    dispatch_async(dispatch_get_main_queue()) {
        callback()
    }
}

let example_Of_a_Custom_Executor_That_Is_The_Same_As_Immediate = Executor.Custom { (callback) -> Void in
    callback()
}

let example_Of_A_Custom_Executor_That_has_unneeded_dispatches = Executor.Custom { (callback) -> Void in
    
    Executor.Background.execute {
        Executor.Async.execute {
            Executor.Background.execute {
                callback()
            }
        }
    }
}

let example_Of_A_Custom_Executor_Where_everthing_takes_5_seconds = Executor.Custom { (callback) -> Void in
    
    Executor.Primary.executeAfterDelay(5.0) { () -> Void in
        callback()
    }
    
}




