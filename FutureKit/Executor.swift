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

#if os(iOS)
    import UIKit
    #else
    import Foundation
#endif
import CoreData


public extension NSQualityOfService {
    
    public var qos_class : qos_class_t {
        get {
            switch self {
            case UserInteractive:
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


private func make_dispatch_block<T>(q: dispatch_queue_t, block: (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        dispatch_async(q) {
            block(t)
        }
    }
    return newblock
}

private func make_dispatch_block<T>(q: NSOperationQueue, block: (T) -> Void) -> ((T) -> Void) {
    
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
    
    public var q_attr : dispatch_queue_attr_t {
        switch self {
        case .Serial:
            return DISPATCH_QUEUE_SERIAL
        case .Concurrent:
            return DISPATCH_QUEUE_CONCURRENT
        }
    }
    
}

public enum Executor {
    case Primary                    // use the default configured executor.  Current set to Immediate.
                                    // There are deep philosphical arguments about Immediate vs Async.
                                    // So whenever we figure out what's better we will set the Primary to that!
    
    case Main                       // will use MainAsync or MainImmediate based on MainStrategy

    case Async                      // Always performs an Async Dispatch to some non-main q (usually Default)
                                    // If you want to put all of these in a custom queue, you can set AsyncStrategy to .Queue(q)
    
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
    
    case Custom(CustomCallBackBlock)         // Don't lile any of these?  Bake your own Executor!
    
    public typealias customTaskHandlerBlock = ((Any) -> Void)
    
    // define a Block with the following signature.
    // we give you some taskInfo and a block called executeMe
    // just call "executeMe(taskInfo)" in your execution context of choice.
    public typealias CustomCallBackBlock = ((taskInfo:Any,executeMe:customTaskHandlerBlock) -> Void)
    
    // TODO - should these be configurable? Eventually I guess.
    public static var PrimaryExecutor = Executor.Immediate {
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
                assertionFailure("MainStrategy must be either .MainImmediate or .MainAsync")
            }
        }
    }
    public static var AsyncExecutor = Executor.Default {
        willSet(newValue) {
            switch newValue {
            case .Immediate, .StackCheckingImmediate,.MainImmediate:
                assertionFailure("AsyncStrategy can't be Immediate!")
            case .Async, .Main, .Primary:
                assertionFailure("Nope.  Nope. Nope.")
            case .Main,.MainAsync:
                NSLog("it's probably a bad idea to set .Async to the Main Queue. You have been warned")
            case let .Queue(q):
                assert(q != dispatch_get_main_queue(), "Async is not for the mainq")
            default:
                break
            }
        }
    }
    
    private static let mainQ            = dispatch_get_main_queue()
    private static let userInteractiveQ = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE,0)
    private static let userInitiatedQ   = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0)
    private static let defaultQ         = dispatch_get_global_queue(QOS_CLASS_DEFAULT,0)
    private static let utilityQ         = dispatch_get_global_queue(QOS_CLASS_UTILITY,0)
    private static let backgroundQ      = dispatch_get_global_queue(QOS_CLASS_BACKGROUND,0)
    
    init(qos: NSQualityOfService) {
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
    
    init(qos_class: qos_class_t) {
        switch qos_class.value {
        case QOS_CLASS_USER_INTERACTIVE.value:
            self = .UserInteractive
        case QOS_CLASS_USER_INITIATED.value:
            self = .UserInitiated
        case QOS_CLASS_DEFAULT.value:
            self = .Default
        case QOS_CLASS_UTILITY.value:
            self = .Utility
        case QOS_CLASS_BACKGROUND.value:
            self = .Background
        case QOS_CLASS_UNSPECIFIED.value:
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
        qos : NSQualityOfService = .Default,
        relative_priority: Int32 = 0) -> Executor {
            let qos_class = qos.qos_class
            let q_attr = type.q_attr
            let c_attr = dispatch_queue_attr_make_with_qos_class(q_attr,qos_class, relative_priority)
            let q : dispatch_queue_t
            if let l = label {
                q = dispatch_queue_create(l, c_attr)
            }
            else {
                q = dispatch_queue_create(nil, c_attr)
            }
            return .Queue(q)
    }
    public static func createOperationQueue(name: String?,
        maxConcurrentOperationCount : Int) -> Executor {
            
            let oq = NSOperationQueue()
            oq.name = name
            
            return .OperationQueue(oq)
            
    }
    
    public static func createConcurrentQueue(label : String? = nil,qos : NSQualityOfService = .Default) -> Executor  {
        return self.createQueue(label, type: .Concurrent, qos: qos, relative_priority: 0)
    }
    public static func createConcurrentQueue() -> Executor  {
        return self.createQueue(nil, type: .Concurrent, qos: .Default, relative_priority: 0)
    }
    public static func createSerialQueue(label : String? = nil,qos : NSQualityOfService = .Default) -> Executor  {
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
    public func execute(block b: dispatch_block_t) {
        let executionBlock = self.callbackBlockFor(b)
        executionBlock()
    }
    
    public func executeAfterDelay(nanosecs : Int64, block b: dispatch_block_t)  {
        let executionBlock = self.callbackBlockFor(b)
        let popTime = dispatch_time(DISPATCH_TIME_NOW, nanosecs)
        let q = self.underlyingQueue ?? Executor.defaultQ
        dispatch_after(popTime, q, {
            executionBlock()
        });
    }
    public func executeAfterDelay(secs : NSTimeInterval,block b: dispatch_block_t)  {
        let nanosecsDouble = secs * NSTimeInterval(NSEC_PER_SEC)
        let nanosecs = Int64(nanosecsDouble)
        self.executeAfterDelay(nanosecs,block: b)
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
    
    
    public func callbackBlockFor<T>(block: (T) -> Void) -> ((T) -> Void) {
        
        switch self {
        case .Primary:
            return Executor.PrimaryExecutor.callbackBlockFor(block)
        case .Main:
            return Executor.MainExecutor.callbackBlockFor(block)
        case .Async:
            return Executor.AsyncExecutor.callbackBlockFor(block)
            
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
                return Executor.MainExecutor.callbackBlockFor(block)
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
                    let b = Executor.Default.callbackBlockFor(block)
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
                let a = t as Any
                customCallBack(taskInfo: a, executeMe: { (taskInfo) -> Void in
                    let payloadasT = taskInfo as! T
                    block(payloadasT)
                })
            }
            
            return b
        }
    }
    
}

let example_of_a_Custom_Executor_That_Is_The_Same_As_MainAsync = Executor.Custom { (taskInfo, executeMe) -> Void in
    dispatch_async(dispatch_get_main_queue()) {
        executeMe(taskInfo)
    }
}

let example_Of_a_Custom_Executor_That_Is_The_Same_As_Immediate = Executor.Custom { (taskInfo, executeMe) -> Void in
    executeMe(taskInfo)
}

let example_Of_A_Custom_Executor_That_has_uneeded_dispatches = Executor.Custom { (taskInfo, executeMe) -> Void in
    
    Executor.Background.execute {
        Executor.Async.execute {
            Executor.Background.execute {
                executeMe(taskInfo)
            }
        }
    }
}
