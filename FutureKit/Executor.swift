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


// swiftlint:disable file_length type_body_length function_body_length

import Foundation
import CoreData
import Dispatch

final public class Box<T> {
    public let value: T
    public init(_ v: T) { self.value = v }
}

private func make_dispatch_block(_ q: DispatchQueue, _ block: @escaping () -> Void) -> (() -> Void) {

    let newblock = { () -> Void in
        q.async {
            block()
        }
    }
    return newblock
}

private func make_dispatch_block(_ q: OperationQueue, _ block: @escaping () -> Void) -> (() -> Void) {

    let newblock = { () -> Void in
        q.addOperation({ () -> Void in
            block()
        })
    }
    return newblock
}

public enum SerialOrConcurrent: Int {
    case serial
    case concurrent

    public var q_attr: DispatchQueue.Attributes! {
        switch self {
        case .serial:
            return DispatchQueue.Attributes()
        case .concurrent:
            return DispatchQueue.Attributes.concurrent
        }
    }

}

public extension Date {
    public static var now: Date {
        return Date()
    }
}

internal extension DispatchWallTime {
    internal init(_ date: Date) {
        let secsSinceEpoch = date.timeIntervalSince1970
        let spec = timespec(
            tv_sec: __darwin_time_t(secsSinceEpoch),
            tv_nsec: Int((secsSinceEpoch - floor(secsSinceEpoch)) * Double(NSEC_PER_SEC))
        )
        self.init(timespec: spec)
    }
}

internal extension DispatchTimeInterval {
    internal init(_ interval: TimeInterval) {
        let nanoSecs = Int(interval * Double(NSEC_PER_SEC))
        self = .nanoseconds(nanoSecs)
    }
}

internal extension DispatchQueue {
    internal func async(afterDelay interval: TimeInterval, execute block: @escaping @convention(block) () -> Void) {
        self.asyncAfter(deadline: DispatchTime.now() + interval, execute: block)
    }

    internal func async(after date: Date, execute block: @escaping @convention(block) () -> Void) {
        self.asyncAfter(wallDeadline: DispatchWallTime(date), execute: block)
    }
}

// remove in Swift 2.0

extension qos_class_t {
    var rawValue: UInt32 {
        return self.rawValue
    }
}

public enum When {
    case asap
    case async
    case after(Date)

}

extension When {
    static public func delay(_ interval: TimeInterval) -> When {
        let date = Date(timeIntervalSinceNow: interval)
        return .after(date)
    }

    public var forceAsync: When {
        switch self {
        case .asap:
            return .async
        default:
            return self
        }
    }
}

public protocol ExecutorWrapper: ExecutorConvertable {
    var relatedQueue: DispatchQueue { get }
    func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void)

    var innerWrapper: ExecutorWrapper { get }
    var description: String { get }

}

extension ExecutorWrapper {
    public var innerWrapper: ExecutorWrapper {
        return self
    }

    public var relatedQueue: DispatchQueue {
        return CurrentExecutor.innerWrapper.relatedQueue
    }

    public var description: String {
        return "ExecutorWrapper<\(Self.self)>"
    }
}
public struct ImmediateExecutor: ExecutorWrapper {

    public static var instance = ImmediateExecutor()

    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        switch when {
        case .asap:
            return {
                block()
            }
        default:
            return MainQueueExecutor.wrapExecution(for: when, block: block)
        }
    }

}

public struct StackCheckingImmediateExecutor: ExecutorWrapper {

    public static var instance = ImmediateExecutor()

    public var asyncInstance: ExecutorWrapper {
        return MainQueueExecutor.instance
    }

    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        let wrappedBlock  = { () -> Void in
            let threadDict = Thread.current.threadDictionary
            let currentDepth = (threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] as? Int32) ??  0
            if currentDepth > GLOBAL_PARMS.STACK_CHECKING_MAX_DEPTH {
                self.asyncInstance.wrapExecution(for: when, block: block)()
            } else {
                let newDepth = currentDepth + 1
                threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = newDepth
                block()
                threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = currentDepth
            }
        }
        switch when {
        case .asap:
            return {
                wrappedBlock()
            }
        default:
            return self.asyncInstance.wrapExecution(for: when, block: block)
        }
    }

}
public struct MainQueueExecutor: ExecutorWrapper {

    public static var instance = MainQueueExecutor()

    public var relatedQueue: DispatchQueue {
        return DispatchQueue.main
    }

    public static func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        switch when {
        case .asap:
            return {
                if !Thread.isMainThread {
                    block()
                } else {
                    DispatchQueue.main.async(execute: block)
                }
            }
        case .async:
            return {
                DispatchQueue.main.async(execute: block)
            }
        case let .after(date):
            return {
                DispatchQueue.main.asyncAfter(wallDeadline: DispatchWallTime(date), execute: block)
            }
        }
    }
    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        return MainQueueExecutor.wrapExecution(for: when, block: block)
    }
}

public struct CustomExecutor: ExecutorWrapper {

    let wrapper: ((@escaping () -> Void) -> Void)

    init(_ wrapper: @escaping ((@escaping () -> Void) -> Void)) {
        self.wrapper = wrapper
    }

    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        let wrappedBlock = {
            self.wrapper(block)
        }
        switch when {
        case .asap:
            return wrappedBlock
        default:
            return CurrentAsyncExecutor.instance.wrapExecution(for: when, block: wrappedBlock)
        }
    }
}

extension DispatchQueue: ExecutorWrapper {

    public var relatedQueue: DispatchQueue {
        return self
    }
    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        switch when {
        case .asap, .async:
            return {
                self.async(execute: block)
            }
        case let .after(date):
            return {
                self.asyncAfter(wallDeadline: DispatchWallTime(date), execute: block)
            }
        }
    }
}

extension OperationQueue: ExecutorWrapper {
    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        switch when {
        case .asap, .async:
            return {
                self.addOperation(block)
            }
        case let .after(date):
            return {
                self.relatedQueue.asyncAfter(wallDeadline: DispatchWallTime(date), execute: block)
            }
        }
    }

}

extension NSManagedObjectContext: ExecutorWrapper {
    public var relatedQueue: DispatchQueue {
        switch self.concurrencyType {
        case .mainQueueConcurrencyType:
            return DispatchQueue.main
        default:
            return DispatchQueue.global(qos: .default)
        }
    }
    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {

        switch self.concurrencyType {
        case .confinementConcurrencyType:
            preconditionFailure("confinement type is not supported")
        case .mainQueueConcurrencyType:
            return MainQueueExecutor.instance.wrapExecution(for: when, block: block)
        case .privateQueueConcurrencyType:
            let wrappedBlock = { () -> Void in
                self.perform(block)
            }
            switch when {
            case .asap, .async:
                return wrappedBlock
            case let .after(date):
                return {
                    self.relatedQueue.asyncAfter(wallDeadline: DispatchWallTime(date), execute: wrappedBlock)
                }
            }

        }

    }
}

public struct CurrentExecutor: ExecutorWrapper {
    public static var instance = CurrentExecutor()

    @discardableResult
    internal static func setCurrent(_ e: ExecutorWrapper?) -> ExecutorWrapper? {
        assert(e == nil || !(e is CurrentExecutor), "do not set CurrentExecutor via setExecutor()")
        let threadDict = Thread.current.threadDictionary
        let key = GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY
        let current = threadDict[key] as? Box<ExecutorWrapper>
        if let ex = e {
            threadDict.setObject(Box<ExecutorWrapper>(ex), forKey: key)
        } else {
            threadDict.removeObject(forKey: key)
        }
        return current?.value
    }
    internal static func getCurrent() -> ExecutorWrapper? {
        let threadDict = Thread.current.threadDictionary
        let r = threadDict[GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY] as? Box<ExecutorWrapper>
        return r?.value
    }

    static public var innerWrapper: ExecutorWrapper {
        if let current = CurrentExecutor.getCurrent() {
            return current
        }
        if Thread.isMainThread {
            return MainQueueExecutor.instance
        }
        return DispatchQueue.global(qos: .default)

    }

    static func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        return self.innerWrapper.wrapExecution(for: when, block: block)
    }
    public var innerWrapper: ExecutorWrapper {
        return CurrentExecutor.innerWrapper
    }
    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        return CurrentExecutor.wrapExecution(for: when, block: block)
    }

}
public struct CurrentAsyncExecutor: ExecutorWrapper {

    public static var instance = CurrentAsyncExecutor()

    public var innerWrapper: ExecutorWrapper {
        return CurrentExecutor.innerWrapper
    }

    public func wrapExecution(for when: When, block: @escaping () -> Void) -> (() -> Void) {
        return CurrentExecutor.wrapExecution(for: when.forceAsync, block: block)
    }

}

public typealias Executor = ExecutorNew

extension ExecutorWrapper {
    public var executor: ExecutorNew {
        return ExecutorNew(self)
    }
    public func wrapExecution(block: @escaping () -> Void) -> (() -> Void) {
        return self.wrapExecution(for: .asap, block: block)
    }
}

public protocol ExecutorConvertable {
    var executor: ExecutorNew { get }
}

public struct ExecutorNew: ExecutorConvertable {

    public var executor: ExecutorNew {
        return self
    }
    public var wrapper: ExecutorWrapper

    public init(_ wrapper: ExecutorWrapper) {
        self.wrapper = wrapper
    }

    public var description: String {
        return "Executor<\(self.wrapper.description)>"
    }

    public static var primary: ExecutorNew {
        return CurrentExecutor.instance.executor
    }

    public static var main: ExecutorNew {
        return MainQueueExecutor.instance.executor
    }
    public static var async: ExecutorNew {
        return DispatchQueue.global(qos: .default).executor
    }
    public static var current: ExecutorNew {
        return CurrentExecutor.instance.executor
    }
    public static var currentAsync: ExecutorNew {
        return CurrentAsyncExecutor.instance.executor
    }
    public static var immediate: ExecutorNew {
        return ImmediateExecutor.instance.executor
    }
    public static var mainAsync: ExecutorNew {
        return DispatchQueue.main.executor
    }
    public static var mainImmediate: ExecutorNew {
        return MainQueueExecutor.instance.executor
    }
    public static var userInteractive: ExecutorNew {
        return DispatchQueue.global(qos: .userInteractive).executor
    }
    public static var userInitiated: ExecutorNew {
        return DispatchQueue.global(qos: .userInitiated).executor
    }
    public static var `default`: ExecutorNew {
        return DispatchQueue.global(qos: .default).executor
    }
    public static var utility: ExecutorNew {
        return DispatchQueue.global(qos: .utility).executor
    }
    public static var background: ExecutorNew {
        return DispatchQueue.global(qos: .background).executor
    }
    public static func queue(_ queue: DispatchQueue) -> ExecutorNew {
        return queue.executor
    }
    public static func custom(_ wrapper: @escaping (@escaping () -> Void) -> Void) -> ExecutorNew {
        return CustomExecutor(wrapper).executor
    }
    public static func operationQueue(_ opQueue: OperationQueue) -> ExecutorNew {
        return opQueue.executor
    }
    public static func managedObjectContext(_ context: NSManagedObjectContext) -> ExecutorNew {
        return context.executor
    }

    public init(qos: DispatchQoS.QoSClass) {
        self.wrapper = DispatchQueue.global(qos: qos)
    }

    public init(queue: DispatchQueue) {
        self.wrapper = queue
    }
    public init(opqueue: Foundation.OperationQueue) {
        self.wrapper = opqueue
    }

    public static func createQueue(label: String = "futurekit-q",
                                   type: SerialOrConcurrent,
                                   qos: DispatchQoS = DispatchQoS.default,
                                   attributes: DispatchQueue.Attributes = DispatchQueue.Attributes(rawValue: 0),
                                   autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit
        ) -> ExecutorNew {

        let queue = DispatchQueue(label: label,
                                  qos: qos,
                                  attributes: attributes,
                                  autoreleaseFrequency: autoreleaseFrequency,
                                  target: nil)
        return queue.executor
    }

    public static func createOperationQueue(_ name: String?,
                                            maxConcurrentOperationCount: Int) -> ExecutorNew {

        let opqueue = Foundation.OperationQueue()
        opqueue.name = name
        return opqueue.executor

    }

    public static func createConcurrentQueue(label: String = "futurekit-concurrentq", qos: DispatchQoS = DispatchQoS.default) -> ExecutorNew {
        return self.createQueue(label: label, type: .concurrent, qos: qos)
    }
    public static func createConcurrentQueue() -> ExecutorNew {
        return self.createQueue(label: "futurekit-concurrentq", type: .concurrent, qos: .default)
    }
    public static func createSerialQueue(label: String = "futurekit-serialq", qos: DispatchQoS = DispatchQoS.default) -> ExecutorNew {
        return self.createQueue(label: label, type: .serial, qos: qos)
    }
    public static func createSerialQueue() -> ExecutorNew {
        return self.createQueue(label: "futurekit-serialq", type: .serial, qos: .default)
    }

    internal func callbackBlock<T>(when: When = .asap, for type: T.Type, _ block: @escaping (T) -> Void) -> ((T) -> Void) {

        return { (t: T) -> Void in

            self.callbackBlock(when: when) { () -> Void in
                block(t)
                }()
        }
    }

    internal func callbackBlock(when: When = .asap, _ block: @escaping () -> Void) -> (() -> Void) {

        let currentWrapper = self.wrapper.innerWrapper
        assert(!(currentWrapper is CurrentExecutor), "innerwrapper can't be CurrentExecutor")

        switch currentWrapper {
        case is ImmediateExecutor:
            return currentWrapper.wrapExecution(for: when, block: block)
        case is StackCheckingImmediateExecutor:
            return currentWrapper.wrapExecution(for: when, block: block)
        default:
            let wrappedBlock = { () -> Void in
                let previous = CurrentExecutor.setCurrent(currentWrapper)
                block()
                CurrentExecutor.setCurrent(previous)
            }
            return currentWrapper.wrapExecution(for: when, block: wrappedBlock)
        }
    }
}

extension ExecutorConvertable {

    public func executeBlock(when: When = .asap, block b: @escaping () -> Void) {
        let executionBlock = self.executor.callbackBlock(when: when, b)
        executionBlock()
    }

    @discardableResult
    public func execute<S>(when: When = .asap, _ block: @escaping () throws -> S) -> Future<S> {
        let p = Promise<S>()
        self.executeBlock(when: when) { () -> Void in
            do {
                let s = try block()
                p.completeWithSuccess(s)
            } catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }

    @discardableResult
    public func execute<C: CompletionConvertable>(when: When = .asap,
                                                  _ block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        self.executeBlock(when: when) { () -> Void in
            do {
                let c = try block()
                p.complete(c)
            } catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }

    @discardableResult
    public func execute<C: CompletionConvertable>(afterDelay secs: TimeInterval, block: @escaping () throws -> C) -> Future<C.T> {

        return self.execute(when: .delay(secs), block)
    }

    @discardableResult
    public func execute<S>(afterDelay secs: TimeInterval, block: @escaping () throws -> S) -> Future<S> {
        return self.execute(when: .delay(secs), block)
    }

    public func execute<C: CompletionConvertable>(after date: Date, block: @escaping () throws -> C) -> Future<C.T> {
        return self.execute(when: .after(date), block)
    }

    public func execute<S>(after date: Date, block: @escaping () throws -> S) -> Future<S> {
        return self.execute(when: .after(date), block)
    }

    /**
     repeatExecution
     
     - parameter startingAt:     date to start repeating
     - parameter repeatingEvery: interval to repeat
     - parameter action:         action to execute
     
     - returns: CancellationToken
     */
    public func repeatExecution(startingAt date: Date = .now, repeatingEvery: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        return self.repeatExecution(startingAt: date,
                                    repeatingEvery: repeatingEvery,
                                    withLeeway: repeatingEvery * 0.1,
                                    action: action)
    }

    /**
     schedule to repeat execution inside this executor
     
     - parameter startingAt:     date to start repeatin
     - parameter repeatingEvery: interval to repeat
     - parameter leeway:         the 'leeway' execution is allowed. default is 10% of repeatingEvery
     - parameter action:         action to execute
     
     - returns: CancellationToken that can be used to stop the execution
     */
    public func repeatExecution(startingAt date: Date = Date.now, repeatingEvery: TimeInterval, withLeeway leeway: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        precondition(repeatingEvery >= 0)
        precondition(leeway >= 0)

        let timerSource = DispatchSource.makeTimerSource()
        #if swift(>=4.0)
        timerSource.schedule(wallDeadline: DispatchWallTime(date),
                             repeating: DispatchTimeInterval(repeatingEvery),
                             leeway: DispatchTimeInterval(leeway))
        #else
        timerSource.scheduleRepeating(wallDeadline: DispatchWallTime(date),
                                      interval: DispatchTimeInterval(repeatingEvery),
                                      leeway: DispatchTimeInterval(leeway))
        #endif

        timerSource.setEventHandler {
            self.execute(when: .asap, action)
        }

        let p = Promise<Void>()

        p.onRequestCancel { _ -> CancelRequestResponse<Void> in
            timerSource.cancel()
            return .complete(.cancelled)
        }

        return p.future.getCancelToken()

    }

}

public enum ExecutorOld {
    case primary                    // use the default configured executor.  Current set to Immediate.
                                    // There are deep philosphical arguments about Immediate vs Async.
                                    // So whenever we figure out what's better we will set the Primary to that!

    case main                       // will use MainAsync or MainImmediate based on MainStrategy

    case async                      // Always performs an Async Dispatch to some non-main q (usually Default)
                                    // If you want to put all of these in a custom queue, you can set AsyncStrategy to .Queue(q)

    case current                    // Will try to use the current Executor.
                                    // If the current block isn't running in an Executor, will return Main if running in the main thread, otherwise .Async

    case currentAsync               // Will try to use the current Executor, but guarantees that the operation will
                                    // always call a dispatch_async() before executing.
                                    // If the current block isn't running in an Executor,
                                    // will return MainAsync if running in the main thread, otherwise .Async

    case immediate                  // Never performs an Async Dispatch, Ok for simple mappings. But use with care!
    // Blocks using the Immediate executor can run in ANY Block

    case stackCheckingImmediate     // Will try to perform immediate, but does some stack checking.
                                    // Safer than Immediate
                                    // But is less efficient.
                                    // Maybe useful if an Immediate handler is somehow causing stack overflow issues

    case mainAsync                  // will always do a dispatch_async to the mainQ
    case mainImmediate              // will try to avoid dispatch_async if already on the MainQ

    case userInteractive            // QOS_CLASS_USER_INTERACTIVE
    case userInitiated              // QOS_CLASS_USER_INITIATED
    case `default`                    // QOS_CLASS_DEFAULT
    case utility                    // QOS_CLASS_UTILITY
    case background                 // QOS_CLASS_BACKGROUND

    case queue(DispatchQueue)    // Dispatch to a Queue of your choice!
                                    // Use this for your own custom queues

    case operationQueue(Foundation.OperationQueue)    // Dispatch to a Queue of your choice!
                                                      // Use this for your own custom queues

    case managedObjectContext(NSManagedObjectContext)   // block will run inside the managed object's context
                                                        // via context.performBlock()

    case custom(((@escaping () -> Void) -> Void))        // Don't like any of these?  Bake your own Executor!

    public var description: String {
        switch self {
        case .primary:
            return "Primary"
        case .main:
            return "Main"
        case .async:
            return "Async"
        case .current:
            return "Current"
        case .currentAsync:
            return "CurrentAsync"
        case .immediate:
            return "Immediate"
        case .stackCheckingImmediate:
            return "StackCheckingImmediate"
        case .mainAsync:
            return "MainAsync"
        case .mainImmediate:
            return "MainImmediate"
        case .userInteractive:
            return "UserInteractive"
        case .userInitiated:
            return "UserInitiated"
        case .default:
            return "Default"
        case .utility:
            return "Utility"
        case .background:
            return "Background"
        case let .queue(q):
            return "Queue(\(q.label))"
        case let .operationQueue(oq):
            let name = oq.name ?? "??"
            return "OperationQueue(\(name))"
        case .managedObjectContext:
            return "ManagedObjectContext"
        case .custom:
            return "Custom"
        }
    }

    public typealias CustomCallBackBlock = ((_ block:() -> Void) -> Void)

    public static var PrimaryExecutor = ExecutorOld.current {
        willSet(newValue) {
            switch newValue {
            case .primary:
                assertionFailure("Nope.  Nope. Nope.")
            case .main, .mainAsync, mainImmediate:
                NSLog("it's probably a bad idea to set .Primary to the Main Queue. You have been warned")
            default:
                break
            }
        }
    }
    public static var MainExecutor = ExecutorOld.mainImmediate {
        willSet(newValue) {
            switch newValue {
            case .mainImmediate, .mainAsync, .custom:
                break
            default:
                assertionFailure("MainStrategy must be either .MainImmediate or .MainAsync or .Custom")
            }
        }
    }
    public static var AsyncExecutor = ExecutorOld.default {
        willSet(newValue) {
            switch newValue {
            case .immediate, .stackCheckingImmediate, .mainImmediate:
                assertionFailure("AsyncStrategy can't be Immediate!")
            case .async, .main, .primary, .current, .currentAsync:
                assertionFailure("Nope.  Nope. Nope. AsyncStrategy can't be .Async, .Main, .Primary, .Current!, .CurrentAsync") // swiftlint:disable:this line_length
            case .mainAsync:
                NSLog("it's probably a bad idea to set .Async to the Main Queue. You have been warned")
            case let .queue(q):
                assert(!(q !== DispatchQueue.main), "Async is not for the mainq")
            default:
                break
            }
        }
    }

    fileprivate static let mainQ            = DispatchQueue.main
    fileprivate static let userInteractiveQ = DispatchQueue.global(qos: .userInteractive)
    fileprivate static let userInitiatedQ   = DispatchQueue.global(qos: .userInitiated)
    fileprivate static let defaultQ         = DispatchQueue.global(qos: .default)
    fileprivate static let utilityQ         = DispatchQueue.global(qos: .utility)
    fileprivate static let backgroundQ      = DispatchQueue.global(qos: .background)

    init(qos: DispatchQoS.QoSClass) {
        switch qos {
        case .userInteractive:
            self = .userInteractive
        case .userInitiated:
            self = .userInitiated
        case .default:
            self = .default
        case .utility:
            self = .utility
        case .background:
            self = .background
        case .unspecified:
            self = .default
        }
    }

    init(queue: DispatchQueue) {
        self = .queue(queue)
    }
    init(opqueue: Foundation.OperationQueue) {
        self = .operationQueue(opqueue)
    }

    public static func createQueue(label: String = "futurekit-q",
                                   type: SerialOrConcurrent,
                                   qos: DispatchQoS = DispatchQoS.default,
                                   attributes: DispatchQueue.Attributes = DispatchQueue.Attributes(rawValue: 0),
                                   autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit
        ) -> ExecutorOld {
        
        let q = DispatchQueue(label: label,
                              qos: qos,
                              attributes: attributes,
                              autoreleaseFrequency: autoreleaseFrequency,
                              target: nil)
        return .queue(q)
    }

    public static func createOperationQueue(_ name: String?,
                                            maxConcurrentOperationCount: Int) -> ExecutorOld {

            let oq = Foundation.OperationQueue()
            oq.name = name
            return .operationQueue(oq)

    }

    public static func createConcurrentQueue(label: String = "futurekit-concurrentq", qos: DispatchQoS = DispatchQoS.default) -> ExecutorOld {
        return self.createQueue(label: label, type: .concurrent, qos: qos)
    }
    public static func createConcurrentQueue() -> ExecutorOld {
        return self.createQueue(label: "futurekit-concurrentq", type: .concurrent, qos: .default)
    }
    public static func createSerialQueue(label: String = "futurekit-serialq", qos: DispatchQoS = DispatchQoS.default) -> ExecutorOld {
        return self.createQueue(label: label, type: .serial, qos: qos)
    }
    public static func createSerialQueue() -> ExecutorOld {
        return self.createQueue(label: "futurekit-serialq", type: .serial, qos: .default)
    }

    // immediately 'dispatches' and executes a block on an Executor
    // example:
    //
    //    Executor.Background.execute {
    //          // insert code to run in the QOS_CLASS_BACKGROUND queue!
    //     }
    //
    public func executeBlock(block b: @escaping () -> Void) {
        let executionBlock = self.callbackBlock(b)
        executionBlock()
    }

    @available(*, deprecated: 1.1, message: "renamed to execute(afterDelay:)")
    @discardableResult
    public func executeAfterDelay<S>(_ delay: TimeInterval, _ block: @escaping () throws -> S) -> Future<S> {
        return self.execute(afterDelay: delay, block: block)
    }
    @available(*, deprecated: 1.1, message: "renamed to execute(after:)")
    @discardableResult
    public func executeAt<S>(_ date: Date, _ block: @escaping () throws -> S) -> Future<S> {
        return self.execute(after: date, block: block)
    }

    @discardableResult
    public func execute<S>(_ block: @escaping () throws -> S) -> Future<S> {
        let p = Promise<S>()
        self.executeBlock { () -> Void in
            do {
                let s = try block()
                p.completeWithSuccess(s)
            } catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }

    @discardableResult
    public func execute<C: CompletionConvertable>(_ block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        self.executeBlock { () -> Void in
            do {
                let c = try block()
                p.complete(c)
            } catch {
                p.completeWithFail(error)
            }
        }
        return p.future
    }

    @discardableResult
    public func execute<C: CompletionConvertable>(afterDelay delay: TimeInterval, block: @escaping () throws -> C) -> Future<C.T> {
        let p = Promise<C.T>()
        let q = self.underlyingQueue ?? ExecutorOld.defaultQ
        q.async(afterDelay: delay) {
            p.completeWithBlock {
                return try block()
            }
        }
        return p.future
    }

    @discardableResult
    public func execute<S>(afterDelay secs: TimeInterval, block: @escaping () throws -> S) -> Future<S> {
        return self.execute(afterDelay: secs) { () -> Completion<S> in
            return .success(try block())
        }
    }

    public func execute<C: CompletionConvertable>(after date: Date, block: @escaping () throws -> C) -> Future<C.T> {
       let p = Promise<C.T>()
       let q = self.underlyingQueue ?? ExecutorOld.defaultQ
        q.async(after: date) {
            p.completeWithBlock {
                return try block()
            }
        }
        return p.future
    }

    public func execute<S>(after date: Date, block: @escaping () throws -> S) -> Future<S> {
        return self.execute(after: date) { () -> Completion<S> in
            return .success(try block())
        }
    }

    /**
     repeatExecution
     
     - parameter startingAt:     date to start repeating
     - parameter repeatingEvery: interval to repeat
     - parameter action:         action to execute
     
     - returns: CancellationToken
     */
    public func repeatExecution(startingAt date: Date = .now, repeatingEvery: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        return self.repeatExecution(startingAt: date,
                                    repeatingEvery: repeatingEvery,
                                    withLeeway: repeatingEvery * 0.1,
                                    action: action)
    }

    /**
     schedule to repeat execution inside this executor
     
     - parameter startingAt:     date to start repeatin
     - parameter repeatingEvery: interval to repeat
     - parameter leeway:         the 'leeway' execution is allowed. default is 10% of repeatingEvery
     - parameter action:         action to execute
     
     - returns: CancellationToken that can be used to stop the execution
     */
    public func repeatExecution(startingAt date: Date = Date.now, repeatingEvery: TimeInterval, withLeeway leeway: TimeInterval, action: @escaping () -> Void) -> CancellationToken {
        precondition(repeatingEvery >= 0)
        precondition(leeway >= 0)

        let timerSource = DispatchSource.makeTimerSource()
        #if swift(>=4.0)
            timerSource.schedule(wallDeadline: DispatchWallTime(date),
                                 repeating: DispatchTimeInterval(repeatingEvery),
                                 leeway: DispatchTimeInterval(leeway))
        #else
            timerSource.scheduleRepeating(wallDeadline: DispatchWallTime(date),
                                          interval: DispatchTimeInterval(repeatingEvery),
                                          leeway: DispatchTimeInterval(leeway))
        #endif

        timerSource.setEventHandler {
            self.execute(action)
        }

        let p = Promise<Void>()

        p.onRequestCancel { _ -> CancelRequestResponse<Void> in
            timerSource.cancel()
            return .complete(.cancelled)
        }

        return p.future.getCancelToken()

    }

    // This returns the underlyingQueue (if there is one).
    // Not all executors have an underlyingQueue.
    // .Custom will always return nil, even if the implementation may include one.
    //
    var underlyingQueue: DispatchQueue? {
        switch self {
        case .primary:
            return ExecutorOld.PrimaryExecutor.underlyingQueue
        case .main, .mainImmediate, .mainAsync:
            return ExecutorOld.mainQ
        case .async:
            return ExecutorOld.AsyncExecutor.underlyingQueue
        case .userInteractive:
            return ExecutorOld.userInteractiveQ
        case .userInitiated:
            return ExecutorOld.userInitiatedQ
        case .default:
            return ExecutorOld.defaultQ
        case .utility:
            return ExecutorOld.utilityQ
        case .background:
            return ExecutorOld.backgroundQ
        case let .queue(q):
            return q
        case let .operationQueue(opQueue):
            return opQueue.underlyingQueue
        case let .managedObjectContext(context):
            if context.concurrencyType == .mainQueueConcurrencyType {
                return ExecutorOld.mainQ
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    public var relatedQueue: DispatchQueue {
        return self.underlyingQueue ?? ExecutorOld.defaultQ
    }

    static var SmartCurrent: ExecutorOld {  // should always return a 'real` executor,
                                            // never a virtual one, like Main, Current, Immediate
        if let current = getCurrentExecutor() {
            return current
        }
        if Thread.isMainThread {
            return self.MainExecutor.real_executor
        }
        return .async
    }

    /**
        So this will try and find the if the current code is running inside of an executor block.
        It uses a Thread dictionary to maintain the current running Executor.
        Will never return .Immediate, instead it will return the actual running Executor if known
    */
    public static func getCurrentExecutor() -> ExecutorOld? {
        let threadDict = Thread.current.threadDictionary
        let r = threadDict[GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY] as? Box<ExecutorOld>
        return r?.value
    }

    public static func getCurrentQueue() -> DispatchQueue? {
        return getCurrentExecutor()?.underlyingQueue
    }

    /**
        Will compare to Executors.
        warning: .Custom Executors can't be compared and will always return 'false' when compared.
    */
//    public func isEqualTo(_ e:Executor) -> Bool {
//        switch self {
//        case .primary:
//            if case .primary = e { return true } else { return false }
//        case .main:
//            if case .main = e { return true } else { return false }
//        case .async:
//            if case .async = e { return true } else { return false }
//        case .current:
//            if case .current = e { return true } else { return false }
//        case .currentAsync:
//            if case .currentAsync = e { return true } else { return false }
//        case .mainImmediate:
//            if case .mainImmediate = e { return true } else { return false }
//        case .mainAsync:
//            if case .mainAsync = e { return true } else { return false }
//        case .userInteractive:
//            if case .userInteractive = e { return true } else { return false }
//        case .userInitiated:
//            if case .userInitiated = e { return true } else { return false }
//        case .default:
//            if case .default = e { return true } else { return false }
//        case .utility:
//            if case .utility = e { return true } else { return false }
//        case .background:
//            if case .background = e { return true } else { return false }
//        case let .queue(q):
//            if case let .queue(q2) = e {
//                return q === q2
//            }
//            return false
//        case let .operationQueue(opQueue):
//            if case let .operationQueue(opQueue2) = e {
//                return opQueue === opQueue2
//            }
//            return false
//        case let .managedObjectContext(context):
//            if case let .managedObjectContext(context2) = e {
//                return context === context2
//            }
//            return false
//        case .immediate:
//            if case .immediate = e { return true } else { return false }
//        case .stackCheckingImmediate:
//            if case .stackCheckingImmediate = e { return true } else { return false }
//        case .custom:
//            // anyone know a good way to compare closures?
//            return false
//        }
//
//    }
//
//    var isTheCurrentlyRunningExecutor : Bool {
//        if case .custom = self {
//            NSLog("we can't compare Custom Executors!  isTheCurrentlyRunningExecutor will always return false when executing .Custom")
//            return false
//        }
//        if let e = Executor.getCurrentExecutor() {
//            return self.isEqualTo(e)
//        }
//        return false
//    }
    // returns the previous Executor
    @discardableResult fileprivate static func setCurrentExecutor(_ e: ExecutorOld?) -> ExecutorOld? {
        let threadDict = Thread.current.threadDictionary
        let key = GLOBAL_PARMS.CURRENT_EXECUTOR_PROPERTY
        let current = threadDict[key] as? Box<ExecutorOld>
        if let ex = e {
            threadDict.setObject(Box<ExecutorOld>(ex), forKey: key)
        } else {
            threadDict.removeObject(forKey: key)
        }
        return current?.value
    }

    internal func callbackBlock<T>(for type: T.Type, _ block: @escaping (T) -> Void) -> ((T) -> Void) {

        return { (t: T) -> Void in

            self.callbackBlock { () -> Void in
                block(t)
            }()
        }
    }

    internal func callbackBlock(_ block: @escaping () -> Void) -> (() -> Void) {

        let currentExecutor = self.real_executor

        switch currentExecutor {
        case .immediate, .stackCheckingImmediate:
            return currentExecutor.getblock_for_callbackBlockFor(block)
        default:
            let wrappedBlock = { () -> Void in
                let previous = ExecutorOld.setCurrentExecutor(currentExecutor)
                block()
                ExecutorOld.setCurrentExecutor(previous)
            }
            return currentExecutor.getblock_for_callbackBlockFor(wrappedBlock)
        }
    }

    /*
        we need to figure out what the real executor we need to guarantee that execution will happen asyncronously.
        This maps the 'best' executor to guarantee a dispatch_async() to use given the current executor
    
        Most executors are already async, and in that case this will return 'self'
    */
    fileprivate var asyncExecutor: ExecutorOld {

        switch self {
        case .primary:
            return ExecutorOld.PrimaryExecutor.asyncExecutor
        case .main, .mainImmediate:
            return .mainAsync
        case .current, .currentAsync:
            return ExecutorOld.SmartCurrent.asyncExecutor
        case .immediate, .stackCheckingImmediate:
            return ExecutorOld.AsyncExecutor

        case let .managedObjectContext(context):
            if context.concurrencyType == .mainQueueConcurrencyType {
                return .mainAsync
            } else {
                return self
            }
        default:
            return self
        }
    }

    /*  we need to figure out what the real executor will be used
        'unwraps' the virtual Executors like .Primary,.Main,.Async,.Current
    */
    fileprivate var real_executor: ExecutorOld {

        switch self {
        case .primary:
            return ExecutorOld.PrimaryExecutor.real_executor
        case .main:
            return ExecutorOld.MainExecutor.real_executor
        case .async:
            return ExecutorOld.AsyncExecutor.real_executor
        case .current:
            return ExecutorOld.SmartCurrent
        case .currentAsync:
            return ExecutorOld.SmartCurrent.asyncExecutor
        case let .managedObjectContext(context):
            if context.concurrencyType == .mainQueueConcurrencyType {
                return ExecutorOld.MainExecutor.real_executor
            } else {
                return self
            }
        default:
            return self
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    fileprivate func getblock_for_callbackBlockFor(_ block: @escaping () -> Void) -> (() -> Void) {

        switch self {
        case .primary:
            return ExecutorOld.PrimaryExecutor.getblock_for_callbackBlockFor(block)
        case .main:
            return ExecutorOld.MainExecutor.getblock_for_callbackBlockFor(block)
        case .async:
            return ExecutorOld.AsyncExecutor.getblock_for_callbackBlockFor(block)

        case .current:
            return ExecutorOld.SmartCurrent.getblock_for_callbackBlockFor(block)

        case .currentAsync:
            return ExecutorOld.SmartCurrent.asyncExecutor.getblock_for_callbackBlockFor(block)

        case .mainImmediate:
            let newblock = { () -> Void in
                if Thread.isMainThread {
                    block()
                } else {
                    ExecutorOld.mainQ.async {
                        block()
                    }
                }
            }
            return newblock
        case .mainAsync:
            return make_dispatch_block(ExecutorOld.mainQ, block)

        case .userInteractive:
            return make_dispatch_block(ExecutorOld.userInteractiveQ, block)
        case .userInitiated:
            return make_dispatch_block(ExecutorOld.userInitiatedQ, block)
        case .default:
            return make_dispatch_block(ExecutorOld.defaultQ, block)
        case .utility:
            return make_dispatch_block(ExecutorOld.utilityQ, block)
        case .background:
            return make_dispatch_block(ExecutorOld.backgroundQ, block)

        case let .queue(q):
            return make_dispatch_block(q, block)

        case let .operationQueue(opQueue):
            return make_dispatch_block(opQueue, block)

        case let .managedObjectContext(context):
            if context.concurrencyType == .mainQueueConcurrencyType {
                return ExecutorOld.MainExecutor.getblock_for_callbackBlockFor(block)
            } else {
                let newblock = { () -> Void in
                    context.perform {
                        block()
                    }
                }
                return newblock
            }

        case .immediate:
            return block
        case .stackCheckingImmediate:
            let b  = { () -> Void in
                let threadDict = Thread.current.threadDictionary
                let currentDepth = (threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] as? Int32) ??  0
                if currentDepth > GLOBAL_PARMS.STACK_CHECKING_MAX_DEPTH {
                    let b = ExecutorOld.AsyncExecutor.callbackBlock(block)
                    b()
                } else {
                    let newDepth = currentDepth + 1
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = newDepth
                    block()
                    threadDict[GLOBAL_PARMS.STACK_CHECKING_PROPERTY] = currentDepth
                }
            }
            return b

        case let .custom(customCallBack):

            let b = { () -> Void in
                customCallBack { () -> Void in
                    block()
                }
            }

            return b
        }
    }

}

let example_of_a_Custom_Executor_That_Is_The_Same_As_MainAsync = Executor.custom { (callback) -> Void in
    DispatchQueue.main.async {
        callback()
    }
}

let example_Of_a_Custom_Executor_That_Is_The_Same_As_Immediate = Executor.custom { (callback) -> Void in
    callback()
}

let example_Of_A_Custom_Executor_That_has_unneeded_dispatches = Executor.custom { (callback) -> Void in

    ExecutorOld.background.execute {
        ExecutorOld.async.execute {
            ExecutorOld.background.execute {
                callback()
            }
        }
    }
}

let example_Of_A_Custom_Executor_Where_everthing_takes_5_seconds = Executor.custom { (callback) -> Void in

    ExecutorOld.primary.execute(afterDelay: 5.0) { () -> Void in
        callback()
    }

}
