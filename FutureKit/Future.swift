//
//  Future.swift
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

// swiftlint:disable file_length

import Foundation

public struct GLOBAL_PARMS { // swiftlint:disable:this type_name
    // WOULD LOVE TO TURN THESE INTO COMPILE TIME PROPERTIES
    // MAYBE VIA an Objective C Header file?
    static let ALWAYS_ASYNC_DISPATCH_DEFAULT_TASKS = false
    static let WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING = false
    static let CANCELLATION_CHAINING = true

    static let STACK_CHECKING_PROPERTY = "FutureKit.immediate.TaskDepth"
    static let CURRENT_EXECUTOR_PROPERTY = NSString(string: "FutureKit.Executor.Current")
    static let STACK_CHECKING_MAX_DEPTH: Int32 = 20

    static var CONVERT_COMMON_NSERROR_VALUES_TO_CANCELLATIONS = true

    public static var LOCKING_STRATEGY: SynchronizationType = .pThreadMutex

}

public enum FutureKitError: Error, Equatable {
    case genericError(String)
    case resultConversionError(String)
    case completionConversionError(String)
    case continueWithConversionError(String)
    case errorForMultipleErrors(String, [Error])
    case exceptionCaught(NSException, [AnyHashable: Any]?)

    public init(genericError: String) {
        self = .genericError(genericError)
    }

    public init(exception: NSException) {
        var userInfo: [AnyHashable: Any]
        if exception.userInfo != nil {
            userInfo = exception.userInfo!
        } else {
            userInfo = [AnyHashable: Any]()
        }
        userInfo["exception"] = NSException(name: exception.name, reason: exception.reason, userInfo: nil)
        userInfo["callStackReturnAddresses"] = exception.callStackReturnAddresses
        userInfo["callStackSymbols"] = exception.callStackSymbols
        self = .exceptionCaught(exception, userInfo)
    }

}

public func == (l: FutureKitError, r: FutureKitError) -> Bool {
    switch (l, r) {
    case let (.genericError(lhs), .genericError(rhs)) :
        return (lhs == rhs)
    case let (.resultConversionError(lhs), .resultConversionError(rhs)) :
        return (lhs == rhs)
    case let (.completionConversionError(lhs), .completionConversionError(rhs)) :
        return (lhs == rhs)
    case let (.continueWithConversionError(lhs), .continueWithConversionError(rhs)) :
        return (lhs == rhs)
    case let (.errorForMultipleErrors(lhs, _), .errorForMultipleErrors(rhs, _)) :
        return (lhs == rhs)
    case let (.exceptionCaught(lhs, _), .exceptionCaught(rhs, _)) :
        return (lhs == rhs)
    default:
        return false
    }
}

internal class CancellationTokenSource {

    // we are going to keep a weak copy of each token we give out.
    // as long as there
    internal typealias CancellationTokenPtr = Weak<CancellationToken>

    fileprivate var tokens: [CancellationTokenPtr] = []

    // once we have triggered cancellation, we can't do it again
    fileprivate var canBeCancelled = true

    // this is to flag that someone has made a non-forced cancel request, but we are ignoring it due to other valid tokens
    // if those tokens disappear, we will honor the cancel request then.
    fileprivate var pendingCancelRequestActive = false

    fileprivate var handler: CancellationHandler?
    fileprivate var forcedCancellationHandler: CancellationHandler

    init(forcedCancellationHandler h: @escaping CancellationHandler) {
        self.forcedCancellationHandler = h
    }

    fileprivate var cancellationIsSupported: Bool {
        return (self.handler != nil)
    }

    // add blocks that will be called as soon as we initiate cancelation
    internal func addHandler(_ h : @escaping CancellationHandler) {
        if !self.canBeCancelled {
            return
        }
        if let oldhandler = self.handler {
            self.handler = { (options) in
                oldhandler(options)
                h(options)
            }
        } else {
            self.handler = h
        }
    }

    internal func clear() {
        self.handler = nil
        self.canBeCancelled = false
        self.tokens.removeAll()
    }

    internal func getNewToken(_ synchObject: SynchronizationProtocol, lockWhenAddingToken: Bool) -> CancellationToken {

        if !self.canBeCancelled {
            return self._createUntrackedToken()
        }
        let token = self._createTrackedToken(synchObject)

        if lockWhenAddingToken {
            synchObject.lockAndModify { () -> Void in
                if self.canBeCancelled {
                    self.tokens.append(CancellationTokenPtr(token))
                }
            }
        } else {
            self.tokens.append(CancellationTokenPtr(token))
        }
        return token
    }

    fileprivate func _createUntrackedToken() -> CancellationToken {

        return CancellationToken(

            onCancel: { [weak self] (options, _) -> Void in
                self?._performCancel(options)
            },

            onDeinit: nil)

    }
    fileprivate func _createTrackedToken(_ synchObject: SynchronizationProtocol) -> CancellationToken {

        return CancellationToken(

            onCancel: { [weak self] (options, token) -> Void in
                self?._cancelRequested(token, options, synchObject)
            },

            onDeinit: { [weak self] (token) -> Void in
                self?._clearInitializedToken(token, synchObject)
            })

    }

    fileprivate func _removeToken(_ cancelingToken: CancellationToken) {
        // so remove tokens that no longer exist and the requested token
        self.tokens = self.tokens.filter { (tokenPtr) -> Bool in
            if let token = tokenPtr.value {
                return (token !== cancelingToken)
            } else {
                return false
            }
        }
    }

    fileprivate func _performCancel(_ options: CancellationOptions) {

        if self.canBeCancelled {
            if !options.contains(.DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting) {
                self.tokens.removeAll()
            }
            // there are no active tokens remaining, so allow the cancellation
            if self.tokens.count == 0 {
                self.handler?(options)
                self.canBeCancelled = false
                self.handler = nil
            } else {
                self.pendingCancelRequestActive = true
            }
        }
        if options.contains(.ForceThisFutureToBeCancelledImmediately) {
            self.forcedCancellationHandler(options)
        }

    }

    fileprivate func _cancelRequested(_ cancelingToken: CancellationToken, _ options: CancellationOptions, _ synchObject: SynchronizationProtocol) {

        synchObject.lockAndModify { () -> Void in
            self._removeToken(cancelingToken)
        }
        self._performCancel(options)

    }

    fileprivate func _clearInitializedToken(_ token: CancellationToken, _ synchObject: SynchronizationProtocol) {

        synchObject.lockAndModifySync { () -> Void in
            self._removeToken(token)

            if self.pendingCancelRequestActive && self.tokens.count == 0 {
                self.canBeCancelled = false
                self.handler?([])
            }
        }
    }

}

public struct CancellationOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue}

    // swiftlint:disable:next line_length
    @available(*, deprecated: 1.1, message: "depricated, cancellation forwards to all dependent futures by default use onSuccess", renamed: "DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting")
    public static let ForwardCancelRequestEvenIfThereAreOtherFuturesWaiting = CancellationOptions(rawValue: 0)

    /**
    When the request is forwarded to another future, that future should cancel itself - even if there are other futures waiting for a result.
    example:
    
        let future: Future<NSData> = someFunction()
        let firstChildofFuture = future.onComplete { (result) in
            print("firstChildofFuture = \(result)")
        }
        let firstChildCancelToken = firstDependentFuture.getCancelToken()
    
        let secondChildofFuture = future.onComplete { (result) in
            print("secondChildofFuture result = \(result)")
        }
        firstChildCancelToken.cancel([.DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting])
        
    should result in `future` and `secondChildofFuture` not being cancelled.
    otherwise future may ignore the firstChildCancelToken request to cancel, because it is still trying to satisify secondChildofFuture

    */
    public static let DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting = CancellationOptions(rawValue: 1)

    /**
    If this future is dependent on the result of another future (via onComplete or .CompleteUsing(f))
    than this cancellation request should NOT be forwarded to that future.
    depending on the future's implementation, you may need include .ForceThisFutureToBeCancelledImmediately for cancellation to be successful
    
    */
    public static let DoNotForwardRequest = CancellationOptions(rawValue: 2)

    /**
    this is allows you to 'short circuit' a Future's internal cancellation request logic.
    The Cancellation request is still forwarded (unless .DoNotForwardRequest is also sent), but an unfinished Future will be forced into the .Cancelled state early.
    
    */
    public static let ForceThisFutureToBeCancelledImmediately = CancellationOptions(rawValue: 4)

}

internal typealias CancellationHandler = ((_ options: CancellationOptions) -> Void)

public class CancellationToken {

    final public func cancel(_ options: CancellationOptions = []) {
        self.onCancel?(options, self)
        self.onCancel = nil
    }

    public var cancelCanBeRequested: Bool {
        return (self.onCancel != nil)
    }

// private implementation details
    deinit {
        self.onDeinit?(self)
        self.onDeinit = nil
    }

    internal typealias OnCancelHandler = ((_ options: CancellationOptions, _ token: CancellationToken) -> Void)
    internal typealias OnDenitHandler = ((_ token: CancellationToken) -> Void)

    fileprivate var onCancel: OnCancelHandler?
    fileprivate var onDeinit: OnDenitHandler?

    internal init(onCancel c: OnCancelHandler?, onDeinit d: OnDenitHandler?) {
        self.onCancel = c
        self.onDeinit = d
    }
}

//// Type Erased Future
//public protocol AnyFuture {
//
//    var futureAny : Future<Any> { get }
//
//    func mapAs<S>() -> Future<S>
//
//    func mapAs() -> Future<Void>
//
//}

public typealias AnyFuture = Future<Any>

/**

    `Future<T>`

    A Future is a swift generic class that let's you represent an object that will be returned at somepoint in the future.  Usually from some asynchronous operation that may be running in a different thread/dispatch_queue or represent data that must be retrieved from a remote server somewhere.


*/

public protocol BaseFutureProtocol {
    var futureAny: Future<Any> { get }
}

public class Future<T> : BaseFutureProtocol, FutureConvertable {
    
    public indirect enum Result: ResultConvertable {
        
        case success(T)
        case fail(Error)
        case cancelled

    }
    
    public indirect enum Completion: CompletionConvertable {
        
        case success(T)
        case fail(Error)
        case cancelled
        case completeUsing(Future<T>)
    }

    public typealias ReturnType = T

    internal typealias CompletionErrorHandler = Promise<T>.CompletionErrorHandler
    internal typealias CompletionBlockType = ((Future<T>.Result) -> Void)
    internal typealias CancellationHandlerType = (() -> Void)

    fileprivate final var __callbacks: [CompletionBlockType]?

    /**
        this is used as the internal storage for `var completion`
        it is not thread-safe to read this directly. use `var synchObject`
    */
    fileprivate final var __result: Future<T>.Result?

//    private final let lock = NSObject()

    // Warning - reusing this lock for other purposes is dangerous when using LOCKING_STRATEGY.NSLock
    // don't read or write values Future
    /**
        used to synchronize access to both __completion and __callbacks
        
        type of synchronization can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    internal final var synchObject: SynchronizationProtocol = GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()

    /**
    is executed used `cancel()` has been requested.
    
    */

    internal func addRequestHandler(_ h : @escaping CancellationHandler) {

        self.synchObject.lockAndModify { () -> Void in
            self.cancellationSource.addHandler(h)
        }
    }

    lazy var cancellationSource: CancellationTokenSource = {
        return CancellationTokenSource(forcedCancellationHandler: { [weak self] (options) -> Void in

            assert(options.contains(.ForceThisFutureToBeCancelledImmediately),
                   "the forced cancellation handler is only supposed to run when the .ForceThisFutureToBeCancelledImmediately option is on") // swiftlint:disable:this line_length
            self?.completeWith(.cancelled)
        })
    }()

    /**
        returns: the current completion value of the Future
    
        accessing this variable directly requires thread synchronization.
    
        It is more efficient to examine completion values that are sent to an onComplete/onSuccess handler of a future than to examine it directly here.
    
        type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    public private(set) final var result: Future<T>.Result? {
        get {
            return self.synchObject.lockAndReadSync { () -> Future<T>.Result? in
                return self.__result
            }
        }
        set(newValue) {
            return self.synchObject.lockAndModifySync {
                self.__result = newValue
            }

        }
    }
    

    /**
    is true if the Future supports cancellation requests using `cancel()`
    
    May return true, even if the Future has already been completed, and cancellation is no longer possible.
    
    It only informs the user that this type of future can be cancelled.
    */
    public var cancellationIsSupported: Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return (self.cancellationSource.cancellationIsSupported)
        }
    }

    /**
    returns: true if the Future has completed with any completion value.
    
    accessing this variable directly requires thread synchronization.
    */
    public final var isCompleted: Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return self.__result != nil
        }

    }

    /**
    You can't instanciate an incomplete Future directly.  You must use a Promsie, or use an Executor with a block.
    */
    internal init() {
    }

//    internal init(cancellationSource s: CancellationTokenSource) {
//        self.cancellationSource = s
//    }

    public init(result: Future<T>.Result) {
        self.result = result
    }

    /**
     creates a completed Future with a completion == .Cancelled(cancelled)
     */
    public init(completeUsing future: Future<T>) {  // returns an completed Task that has Failed with this error
        self.completeWith(.completeUsing(future))
    }

    /**
     Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = .Success(block())
     
     can only be used to a create a Future that should always succeed.
     */
    public init(_ executor: Executor = .immediate, block: @escaping () throws -> T) {
        let wrappedBlock = executor.callbackBlock { () -> Void in
            do {
                let r = try block()
                self.completeWith(.success(r))
            } catch {
                self.completeWith(.fail(error))

            }
        }
        wrappedBlock()
    }

}

extension Future {

    /**
        creates a completed Future with a completion == .Success(success)
    */
    public convenience init(success: T) {  // returns an completed Task  with result T
        self.init(result: .success(success))
    }
    /**
    creates a completed Future with a completion == .Error(failed)
    */
    public convenience init(fail: Error) {  // returns an completed Task that has Failed with this error
        self.init(result: .fail(fail))
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(failWithErrorMessage))
    */
    public convenience init(failWithErrorMessage errorMessage: String) {
        self.init(result: Result(failWithErrorMessage: errorMessage))
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(exception))
    */
    public convenience init(exception: NSException) {  // returns an completed Task that has Failed with this error
        self.init(result: Result(exception: exception))
    }
    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public convenience init(cancelled:()) {  // returns an completed Task that has Failed with this error
        self.init(result: .cancelled)
    }

    public convenience init<C: CompletionConvertable>(delay: TimeInterval, completeWith: C) where C.T == T {
        let executor: Executor = .primary

        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.execute(afterDelay: delay) { () -> Void in
            p.complete(completeWith)
        }
        self.init(completeUsing: p.future)
    }

    public convenience init(afterDelay delay: TimeInterval, success: T) {    // emits a .Success after delay
        let executor: Executor = .primary

        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.execute(afterDelay: delay) {
            p.completeWithSuccess(success)
        }
        self.init(completeUsing: p.future)
    }

    /**
     creates a completed Future with a completion == .Cancelled(cancelled)
     */
    public convenience init<F: FutureConvertable>(completeUsing future: F) where F.T == T {  // returns an completed Task that has Failed with this error
        self.init(completeUsing: future.future)
    }

    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = block()
    
    can be used to create a Future that may succeed or fail.
    
    the block can return a value of .CompleteUsing(Future<T>) if it wants this Future to complete with the results of another future.
    */
    public convenience init<C: CompletionConvertable>(_ executor: Executor  = .immediate, block: @escaping () throws -> C) where C.T == T {
        self.init()
        executor.execute { () -> Void in
            self.completeWithBlocks(completionBlock: {
                return try block()
            })
        }
    }

    /**
     returns: the result of the Future iff the future has completed successfully.  returns nil otherwise.
     
     accessing this variable directly requires thread synchronization.
     */
    public var value: T? {
        return self.result?.value
    }
    /**
     returns: the error of the Future iff the future has completed with an Error.  returns nil otherwise.
     
     accessing this variable directly requires thread synchronization.
     */
    public var error: Error? {
        return self.result?.error
    }
}

extension Future {

/*    public init<C:CompletionConvertable>(_ executor : Executor  = .immediate, block: @autoclosure @escaping () -> C) where C.T == T {
        executor.execute { () -> Void in
            self.completeWith(block())
        }
    } */

    /**
        will complete the future and cause any registered callback blocks to be executed.
    
        may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
 
        type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
        - parameter completion: the value to complete the Future with
    
    */
    internal final func completeAndNotify<C: CompletionConvertable>(_ completion: C) where C.T == T {

        return self.completeWithBlocks(waitUntilDone: false,
            completionBlock: { () -> C in
                completion
            })
    }

    /**
    will complete the future and cause any registered callback blocks to be executed.
    
    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
    
    if the Future has already been completed, the onCompletionError block will be executed.  This block may be running in any queue (depending on the configure synchronization type).
    
    type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY

    - parameter completion: the value to complete the Future with
    
    - parameter onCompletionError: a block to execute if the Future has already been completed.

    */

    internal final func completeAndNotify<C: CompletionConvertable>(_ completion: C, onCompletionError : @escaping CompletionErrorHandler) where C.T == T {

        self.completeWithBlocks(waitUntilDone: false, completionBlock: { () -> C in
            return completion
        }, onCompletionError: onCompletionError)

    }

    /**
    will complete the future and cause any registered callback blocks to be executed.
    
    may block the current thread (depending on configured LOCKING_STRATEGY)
    
    type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY

    - parameter completion: the value to complete the Future with
    
    - returns: true if Future was successfully completed.  Returns false if the Future has already been completed.

    */
    internal final func completeAndNotifySync<C: CompletionConvertable>(_ completion: C) -> Bool where C.T == T {

        var ret = true
        self.completeWithBlocks(waitUntilDone: true,
                                completionBlock: { () -> C in
                                    return completion
                                },
                                onCompletionError: { () -> Void in
                                    ret = false
                                })

        return ret
   }

    private typealias ModifyBlockReturnType = (callbacks: [CompletionBlockType]?,
        result: Future<T>.Result?,
        continueUsing: Future?)
    
    internal final func completeWithBlocks<C: CompletionConvertable>(
            waitUntilDone wait: Bool = false,
            completionBlock : @escaping () throws -> C,
            onCompletionError : @escaping () -> Void = {}) where C.T == T {


        self.synchObject.lockAndModify(waitUntilDone: wait, modifyBlock: { () -> ModifyBlockReturnType in
            if self.__result != nil {
                // future was already complete!
                return ModifyBlockReturnType(nil, nil, nil)
            }
            let c : Completion
            do {
                c = try completionBlock().completion
            } catch {
                c = .fail(error)
            }
            if c.isCompleteUsing {
                return ModifyBlockReturnType(callbacks: nil,
                                             result: nil,
                                             continueUsing: c.completeUsingFuture)
            } else {
                let callbacks = self.__callbacks
                self.__callbacks = nil
                self.cancellationSource.clear()
                self.__result = c.result
                return ModifyBlockReturnType(callbacks, self.__result, nil)
            }
        }, then: { (modifyBlockReturned: ModifyBlockReturnType) -> Void in
            if let callbacks = modifyBlockReturned.callbacks {
                for callback in callbacks {
                    callback(modifyBlockReturned.result!)
                }
            }
            if let f = modifyBlockReturned.continueUsing {
                f.onComplete(.immediate) { (nextComp) -> Void in
                    self.completeWith(nextComp.completion)
                }
                .ignoreFailures()
                let token = f.getCancelToken()
                if token.cancelCanBeRequested {
                    self.addRequestHandler { (options: CancellationOptions) in
                        if !options.contains(.DoNotForwardRequest) {
                            token.cancel(options)
                        }
                    }
                }
            } else if modifyBlockReturned.result == nil {
                onCompletionError()
            }
        })

    }

    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future iff f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.
    
    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
    
    if the Future has already been completed, this function will do nothing.  No error is generated.

    - parameter completion: the value to complete the Future with

    */
    internal final func completeWith(_ completion: Completion) {
        return self.completeAndNotify(completion)
    }

    internal final func completeWith<C: CompletionConvertable>(_ completion: C) where C.T == T {
        return self.completeAndNotify(completion)
    }

    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.

    may block the current thread

    - parameter completion: the value to complete the Future with
    
    - returns: true if Future was successfully completed.  Returns false if the Future has already been completed.
    */
    internal func completeWithSync<C: CompletionConvertable>(_ completion: C) -> Bool where C.T == T {

        return self.completeAndNotifySync(completion)
    }

    internal func completeWithSync(_ completion: Completion) -> Bool {

        return self.completeAndNotifySync(completion)
    }

    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.
    
    will execute the block onCompletionError if the Future has already been completed. The onCompletionError block  may execute inside any thread/queue, so care should be taken.

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.

    - parameter completion: the value to complete the Future with
    
    - parameter onCompletionError: a block to execute if the Future has already been completed.
    */

    internal func completeWith<C: CompletionConvertable>(_ completion: C, onCompletionError errorBlock: @escaping CompletionErrorHandler) where C.T == T {
        return self.completeAndNotify(completion, onCompletionError: errorBlock)
    }

    /**
    
    takes a user supplied block (usually from func onComplete()) and creates a Promise and a callback block that will complete the promise.
    
    can add Objective-C Exception handling if GLOBAL_PARMS.WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING is enabled.
    
    - parameter forBlock: a user supplied block (via onComplete)
    
    - returns: a tuple (promise,callbackblock) a new promise and a completion block that can be added to __callbacks
    
    */
    internal final func createPromiseAndCallback<C: CompletionConvertable>(_ forBlock: @escaping ((Future<T>.Result) throws -> C)) -> (promise: Promise<C.T>, completionCallback: CompletionBlockType) {

        let promise = Promise<C.T>()

        let completionCallback: CompletionBlockType = {(comp) -> Void in
            do {
                let c = try forBlock(comp)
                promise.complete(c.completion)
            } catch {
                promise.completeWithFail(error)
            }
            return
        }
        return (promise, completionCallback)

    }

    /**
    takes a callback block and determines what to do with it based on the Future's current completion state.

    If the Future has already been completed, than the callback block is executed.

    If the Future is incomplete, it adds the callback block to the futures private var __callbacks

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
   
    - parameter callback: a callback block to be run if and when the future is complete
   */
    fileprivate final func runThisCompletionBlockNowOrLater<S>(_ callback : @escaping CompletionBlockType, promise: Promise<S>) {

        // lock my object, and either return the current completion value (if it's set)
        // or add the block to the __callbacks if not.
        self.synchObject.lockAndModifyAsync(modifyBlock: { () -> Future<T>.Result? in

            // we are done!  return the current completion value.
            if let c = self.__result {
                return c
            } else {
                // we only allocate an array after getting the first __callbacks.
                // cause we are hyper sensitive about not allocating extra stuff for temporary transient Futures.
                switch self.__callbacks {
                case let .some(cb):
                    var newcb = cb
                    newcb.append(callback)
                    self.__callbacks = newcb
                case .none:
                    self.__callbacks = [callback]
                }
                let t = self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken: false)
                promise.onRequestCancel(.immediate) { (options) -> CancelRequestResponse<S> in
                    if !options.contains(.DoNotForwardRequest) {
                        t.cancel(options)
                    }
                    return .continue
                }
                return nil
            }
        }, then: { (currentCompletionValue) -> Void in
            // if we got a completion value, than we can execute the callback now.
            if let c = currentCompletionValue {
                callback(c)
            }
        })
    }

    /**
    convert this future of type `Future<T>` into another future type `Future<S>`
    
    WARNING: if `T as! S` isn't legal, than your code may generate an exception.
    
    works iff the following code works:
    
    let t : T
    let s = t as! S
    
    example:
    
    let f = Future<Int>(success:5)
    let f2 : Future<Int32> = f.As()
    assert(f2.result! == Int32(5))
    
    you will need to formally declare the type of the new variable in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future
    
    let fofany : Future<Any> = f.As()
    let fofvoid: Future<Void> = f.As()
    
    - returns: a new Future of with the result type of S
    */
    public final func mapAs<S>() -> Future<S> {
        return self.map(.immediate) { (result) -> S in
            return result as! S // swiftlint:disable:this force_cast
        }
    }

    public final func mapAs() -> Future<Void> {
        return self.map(.immediate) { _ -> Void in
            return ()
        }
    }

    /**
    convert `Future<T>` into another type `Future<S?>`.
    
    WARNING: if `T as! S` isn't legal, than all Success values may be converted to nil
    
    example:
    
    let f = Future<String>(success:"5")
    let f2 : Future<[Int]?> = f.convertOptional()
    assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    - returns: a new Future of with the result type of S?
    
    */
    public final func mapAsOptional<S>() -> Future<S?> {
        return self.map(.immediate) { (result) -> S? in
            return result as? S
        }
    }

    /**
     executes a block only if the Future has not completed.  Will prevent the Future from completing until AFTER the block finishes.
     
     Warning : do not cause the target to complete or call getCancelationToken() or call cancel() on an existing cancel token for this target inside this block.  On some FutureKit implementations, this will cause a deadlock.
     
     It may be better to safer and easier to just guarantee your onSuccess/onComplete logic run inside the same serial dispatch queue or Executor (eg .Main) and examine the var 'result' or 'isCompleted' inside the same context.
     
     - returns: the value returned from the block if the block executed, or nil if the block didn't execute
     */
    public final func IfNotCompleted<S>(_ block:@escaping () -> S) -> S? {
        return self.synchObject.lockAndReadSync { () -> S? in
            if self.__result == nil {
                return block()
            }
            return nil
        }
    }

    /**
     executes a block and provides a 'thread safe' version of the current result.
     
     In the case where the current result is nil, than the future will be prevented from completing until after this block is done executing.
     
     Warning : do not cause the target to complete or call getCancelationToken() or call cancel() on an existing cancel token for this target inside this block.  On some FutureKit implementations, this will cause a deadlock.
     Instead use a returned value from the function to decide to complete or cancel the target.
     
     It may be better to safer and easier to just guarantee your onSuccess/onComplete logic run inside the same serial dispatch queue or Executor (eg .Main) and examine the var 'result' or 'isCompleted' inside the same context.
     
     - returns: the value returned from the block if the block executed
     */
    public final func checkResult<S>(_ block:@escaping (Future<T>.Result?) -> S) -> S {
        return self.synchObject.lockAndReadSync { () -> S in
            return block(self.__result)
        }
    }

// ---------------------------------------------------------------------------------------------------
// Block Handlers
// ---------------------------------------------------------------------------------------------------

    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future in any completion state, with the user defined type S.
    
    The `completion` argument will be set to the Completion<T> value that completed the target.  It will be one of 3 values (.Success, .Fail, or .Cancelled).
    
    The block must return one of four enumeration values (.Success/.Fail/.Cancelled/.CompleteUsing).
    
    Returning a future `f` using .CompleteUsing(f) causes the future returned from this method to be completed when `f` completes, using the completion value of `f`. (Leaving the Future in an incomplete state, until 'f' completes).
    
    The new future returned from this function will be completed using the completion value returned from this block.

    - parameter S: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, and returns a new completion value for the new completion type.   The block must return a Completion value (Completion<S>).
    - returns: a new Future that returns results of type S  (Future<S>)
    
    */
    @discardableResult public final func onComplete<C: CompletionConvertable>(_ executor: Executor, block:@escaping (_ result: Future<T>.Result) throws -> C) -> Future<C.T> {

        let (promise, completionCallback) = self.createPromiseAndCallback(block)
        let block = executor.callbackBlock(for: Future<T>.Result.self, completionCallback)

        self.runThisCompletionBlockNowOrLater(block, promise: promise)

        return promise.future
    }

    /**
     */
    public final func getCancelToken() -> CancellationToken {
        return self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken: true)
    }

    public final func delay(_ delay: TimeInterval) -> Future<T> {
        let completion: Completion = .completeUsing(self)
        return Future(delay: delay, completeWith: completion)
    }

}

extension Future {

    public convenience init<C: CompletionConvertable>(completion: C) where C.T == T {
        switch completion.completion {
        case let .success(result):
            self.init(success: result)
        case let .fail(error):
            self.init(fail: error)
        case .cancelled:
            self.init(cancelled: ())
        case let .completeUsing(future):
            self.init(completeUsing: future)
        }
    }

    public convenience init(block: () throws -> T) {
        do {
            let t = try block()
            self.init(success: t)
        } catch {
            self.init(fail: error)
        }
    }

    public convenience init<C: CompletionConvertable>(block: () throws -> C) where C.T == T {
        do {
            let completion = try block().completion
            self.init(completion: completion)
        } catch {
            self.init(fail: error)
        }
    }
}

extension FutureConvertable {

    /**
     if we try to convert a future from type T to type T, just ignore the request.
     
     the compile should automatically figure out which version of As() execute
     */
    public func As() -> Future<T> {
        return self.future
    }

    /**
     if we try to convert a future from type T to type T, just ignore the request.
     
     the swift compiler can automatically figure out which version of mapAs() execute
     */
    public func mapAs() -> Self {
        return self
    }

    public func withCancelToken() -> (Self, CancellationToken) {
        return (self, self.future.getCancelToken())
    }

    @discardableResult
    public func onComplete<C: CompletionConvertable>(_ block: @escaping (Future<T>.Result) throws -> C) -> Future<C.T> {
        return self.future.onComplete(.primary, block: block)
    }

    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter S: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type S
    */
    @discardableResult
    public func onComplete<S>(_ executor: Executor = .primary, _ block:@escaping (_ result: Future<T>.Result) throws -> S) -> Future<S> {
        return self.future.onComplete(executor) { (result) -> Completion<S> in
            return .success(try block(result))
        }
    }

    /**
    takes a two block and executes one or the other.  the didComplete() block will be executed if the target completes prior before the timeout.
    
    
    it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed when the future returned from the block is completed.
    
    This is the same as returning Completion<T>.CompleteUsing(f)
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter didComplete: a block that will execute if this future completes.  It will return a completion value that
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
    public func waitForComplete<C: CompletionConvertable>(_ timeout: TimeInterval,
                                                          executor: Executor,
                                                          didComplete:@escaping (Future<T>.Result) throws -> C,
                                                          timedOut:@escaping () throws -> C
        ) -> Future<C.T> {

            let p = Promise<C.T>()
            p.automaticallyCancelOnRequestCancel()
            self.onComplete(executor) { (c) -> Void in
                p.completeWithBlock({ () -> C in
                    return try didComplete(c)
                })
            }
            .ignoreFailures()

            executor.execute(afterDelay: timeout) {
                p.completeWithBlock { () -> C in
                    return try timedOut()
                }
            }

            return p.future
    }

    public func waitForComplete<S>(_ timeout: TimeInterval,
                                   executor: Executor,
                                   didComplete:@escaping (Future<T>.Result) throws -> S,
                                   timedOut:@escaping () throws -> S
        ) -> Future<S> {

            return self.waitForComplete(timeout,
                executor: executor,
                didComplete: {
                    return Completion<S>.success(try didComplete($0))
                },
                timedOut: {
                    .success(try timedOut())
            })
    }

    public func waitForSuccess<C: CompletionConvertable>(_ timeout: TimeInterval,
                                                         executor: Executor,
                                                         didSucceed:@escaping (T) throws -> C.T,
                                                         timedOut:@escaping () throws -> C
        ) -> Future<C.T> {

            let p = Promise<C.T>()
            p.automaticallyCancelOnRequestCancel()
            self.onSuccess { (result) -> Void in
                p.completeWithSuccess(try didSucceed(result))
            }.ignoreFailures()

            executor.execute(afterDelay: timeout) {
                p.completeWithBlock { () -> C in
                    return try timedOut()
                }
            }

            return p.future
    }
    public func waitForSuccess<S>(_ timeout: TimeInterval,
                                  executor: Executor,
                                  didSucceed: (T) throws -> S,
                                  timedOut:() throws -> S
        ) -> Future<S> {

            return self.waitForSuccess(timeout,
                executor: executor,
                didSucceed: {
                    return try didSucceed($0)
                },
                timedOut: {
                    try timedOut()
            })
    }

    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The new future returned from this function will be completed using the completion value returned from this block.

    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
    
    - parameter S: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a new Future of type Future<S>
    */

    public func onSuccess<C: CompletionConvertable>(_ executor: Executor = .primary,
                                                    block:@escaping (T) throws -> C) -> Future<C.T> {
        return self.future.onComplete(executor) { (result) -> Completion<C.T> in
            switch result {
            case let .success(value):
                return try block(value).completion
            case let .fail(error):
                return .fail(error)
            case .cancelled:
                return .cancelled
            }
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Success
     
     If the target is completed with a .Success, then the block will be executed using the supplied Executor.
     
     The new future returned from this function will be completed with `.Success(result)` using the value returned from this block as the result.
     
     If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
     
     If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
     
     *Warning* - as of swift 1.2/2.0, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
     
     - parameter S: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block takes the .Success result of the target Future and returns a new result.
     
     - returns: a new Future of type Future<S>
     */

    public func onSuccess<S>(_ executor: Executor = .primary,
                             block:@escaping (T) throws -> S) -> Future<S> {
        return self.onSuccess(executor) { (value: T) -> Completion<S> in
            return .success(try block(value))
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Fail
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
    
    This method returns a new Future.  Which is identical to the depedent Future, with the added Failure handler, that will execute before the Future completes.
     Failures are still forwarded.  If you need to create side effects on errors, consider onComplete or mapError
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.
    */
    @discardableResult
    public func onFail(_ executor: Executor = .primary,
                       block:@escaping (_ error: Error) -> Void) -> Future<T> {
        return self.future.onComplete(executor) { (result) -> Completion<T> in
            if result.isFail {
                block(result.error)
            }
            return result.completion
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Fail
     
     If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Failures can be be remapped to different Completions.  (Such as consumed or ignored or retried via returning .CompleteUsing()
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block can process the error of a future.
     */
    @discardableResult
    public func onFail<C: CompletionConvertable>(_ executor: Executor = .primary,
                                                 block:@escaping (_ error: Error) -> C) -> Future<T> where C.T == T {
        return self.future.onComplete(executor) { (result) -> Completion<T> in
            if result.isFail {
                return block(result.error).completion
            }
            return result.completion
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.
    
     This method returns a new Future.  Cancellations
     
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    */
    @discardableResult
    public func onCancel(_ executor: Executor = .primary, block:@escaping () -> Void) -> Future<T> {
        return self.future.onComplete(executor) { (result) -> Future<T>.Result in
            if result.isCancelled {
                block()
            }
            return result
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Cancelled
     
     If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Cancellations
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
     */
    @discardableResult
    public func onCancel<C: CompletionConvertable>(_ executor: Executor = .primary, block:@escaping () -> C) -> Future<T> where C.T == T {
        return self.future.onComplete(executor) { (result) -> Completion<T> in
            if result.isCancelled {
                return block().completion
            }
            return result.completion
        }
    }

    /*:
    takes a block and executes it iff the target is completed with a .Fail or .Cancel
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
    If the target is completed with a .Cancel, then the block will be executed using the supplied Executor.
    
    This method returns a new Future.  Which is identical to the depedent Future, with the added Fail/Cancel handler, that will execute after the dependent completes.
    Cancelations and Failures are still forwarded.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.  error will be nil when the Future was canceled
    */
    @discardableResult
    public func onFailorCancel(_ executor: Executor = .primary,
                               block:@escaping (Future<T>.Result) -> Void) -> Future<T> {
        return self.future.onComplete(executor) { (result) -> Future<T>.Result in
            
            switch result {
            case .fail, .cancelled:
                block(result)
            case .success:
                break
            }
            return result
        }
    }

    /*:
    takes a block and executes it iff the target is completed with a .Fail or .Cancel
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
    If the target is completed with a .Cancel, then the block will be executed using the supplied Executor.
    
    This method returns a new Future.  Which is identical to the depedent Future, with the added Fail/Cancel handler, that will execute after the dependent completes.
    Cancelations and Failures are still forwarded.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.  error will be nil when the Future was canceled
    */
    @discardableResult
    public func onFailorCancel<C: CompletionConvertable>(
        _ executor: Executor = .primary,
        block:@escaping (Future<T>.Result) -> C) -> Future<T> where C.T == T {
        
        return self.future.onComplete(executor) { (result) -> Completion<T> in
            switch result {
            case .fail, .cancelled:
                return block(result).completion
            case let .success(value):
                return .success(value)
            }
        }
    }

    /*:
    takes a block and executes it iff the target is completed with a .Fail or .Cancel
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
    If the target is completed with a .Cancel, then the block will be executed using the supplied Executor.
    
    This method returns a new Future.  Which is identical to the depedent Future, with the added Fail/Cancel handler, that will execute after the dependent completes.
    Cancelations and Failures are still forwarded.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.  error will be nil when the Future was canceled
    */
    public func onFailorCancel(_ executor: Executor = .primary,
                               block:@escaping (Future<T>.Result)-> Future<T>) -> Future<T> {
        return self.future.onComplete(executor) { (result) -> Completion<T> in
            switch result {
            case .fail, .cancelled:
                return .completeUsing(block(result))
            case let .success(value):
                return .success(value)
            }
        }
    }

    /*:
     
     this is basically a noOp method, but it removes the unused result compiler warning to add an error handler to your future.
     Typically this method will be totally removed by the optimizer, and is really there so that developers will clearly document that they are ignoring errors returned from a Future

     */
    @discardableResult
    public func ignoreFailures() -> Self {
        return self
    }

    /*:
     
     this is basically a noOp method, but it removes the unused result compiler warning to add an error handler to your future.
     Typically this method will be totally removed by the optimizer, and is really there so that developers will clearly document that they are ignoring errors returned from a Future
     
     */
    @discardableResult
    public func assertOnFail() -> Self {
        self.onFail { error in
            assertionFailure("Future failed unexpectantly withy error \(error)")
        }
        .ignoreFailures()
        return self
    }

    // rather use map?  Sure!
    public func map<S>(_ executor: Executor = .primary, block:@escaping (T) throws -> S) -> Future<S> {
        return self.onSuccess(executor, block: block)
    }

    public func mapError(_ executor: Executor = .primary, block:@escaping (Error) throws -> Error) -> Future<T> {
        return self.future.onComplete(executor) { (result) -> Future<T>.Result in
            if case let .fail(error) = result {
                return .fail(try block(error))
            } else {
                return result
            }
        }
    }

    public func waitUntilCompleted() -> Future<T>.Result {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: true)
    }

    public func waitForResult() -> T? {
        return self.waitUntilCompleted().value
    }

    public func _waitUntilCompletedOnMainQueue() -> Future<T>.Result {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: false)
    }
}

extension Future {
    public static func delay(_ delay: TimeInterval) -> Future<Void> {
        if delay == 0.0 {
            return Future<Void>(success: ())
        }
        return Future<Void>(afterDelay: delay, success: ())
    }

    public func automaticallyCancel(afterDelay delay: TimeInterval) -> Future<T> {
        let p = Promise<T>(automaticallyCancelAfter: delay)
        p.completeUsingFuture(self)
        return p.future
    }
    public func automaticallyFail(with error: Error, afterDelay delay: TimeInterval) -> Future<T> {
        let p = Promise<T>(automaticallyFailAfter: delay, error: error)
        p.completeUsingFuture(self)
        return p.future
    }

    // the returned future will be CANCELLED is the subject completes within delay
    // otherwise the block will be called, and the result of the block resolve the value of the returned Future.
    public func ifNotCompleted<U>(within delay: TimeInterval, block: @escaping () throws -> U) -> Future<U> {
        return self.ifNotCompleted(within: delay) { () -> Future<U>.Completion in
            return .success(try block())
        }
    }

    // the returned future will be CANCELLED is the subject completes within delay
    // otherwise the block will be called, and the result of the block resolve the value of the returned Future.
    public func ifNotCompleted<C: CompletionConvertable>(within delay: TimeInterval, block: @escaping () throws -> C) -> Future<C.T> {
        if self.isCompleted {
            return Future<C.T>(cancelled: ())
        }
        let p = Promise<C.T>()
        let token = Future
            .delay(delay)
            .onSuccess { _ in
                if !self.isCompleted {
                    p.completeWithBlock(block)
                }
            }
            .getCancelToken()
        p.onRequestCancel { options -> CancelRequestResponse<C.T> in
            token.cancel(options)
            return .complete(.cancelled)
        }
        self.onComplete { _ in
            p.completeWithCancel()
            token.cancel()
        }
        return p.future
    }

}

extension Future {

    public final func then<C: CompletionConvertable>(_ executor: Executor = .primary, block:@escaping (T) -> C) -> Future<C.T> {
        return self.onSuccess(executor, block: block)
    }
    public final func then<S>(_ executor: Executor = .primary, block:@escaping (T) -> S) -> Future<S> {
        return self.onSuccess(executor, block: block)
    }
}

extension Future: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        return self.debugDescription
    }
    public var debugDescription: String {
        let des = self.result?.description ?? "nil"
        return "Future<\(String(describing: T.self))>{\(des)}"
    }
    public func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription as AnyObject?
    }

}

public protocol OptionalProtocol {
    /// The type contained in the otpional.
    associatedtype Wrapped

    init(reconstructing value: Wrapped?)

    /// Extracts an optional from the receiver.
    var optional: Wrapped? { get }
}

extension Optional: OptionalProtocol {
    public var optional: Wrapped? {
        return self
    }

    public init(reconstructing value: Wrapped?) {
        self = value
    }
}

extension FutureConvertable where T: OptionalProtocol {

    func As<OptionalS: OptionalProtocol>(_ type: OptionalS.Type) -> Future<OptionalS.Wrapped?> {
        return self.map { (value) -> OptionalS.Wrapped? in
            return value.optional.flatMap { $0 as? OptionalS.Wrapped }
        }
    }

}

extension FutureConvertable {

    func AsOptional<OptionalS: OptionalProtocol>(_ type: OptionalS.Type) -> Future<OptionalS.Wrapped?> {
        return self.map { (value) -> OptionalS.Wrapped? in
            return value as? OptionalS.Wrapped
        }
    }

}

private var futureWithNoResult = Future<Any>()

private class ClassWithMethodsThatReturnFutures {

    func iReturnAnInt() -> Future<Int> {

        return Future (.immediate) { () -> Int in
            return 5
        }
    }

    func iReturnFive() -> Int {
        return 5
    }
    func iReturnFromBackgroundQueueUsingBlock() -> Future<Int> {
        //
        return Future(.default) {
            self.iReturnFive()
        }
    }

    func iWillUseAPromise() -> Future<Int> {
        let p: Promise<Int> = Promise()

        // let's do some async dispatching of things here:
        DispatchQueue.main.async {
            p.completeWithSuccess(5)
        }

        return p.future

    }

    func iMayFailRandomly() -> Future<[String: Int]> {
        let p = Promise<[String: Int]>()

        DispatchQueue.main.async {
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                p.completeWithFail(FutureKitError.genericError("failed randomly"))
            case 1:
                p.completeWithCancel()
            default:
                p.completeWithSuccess(["Hi": 5])
            }
        }
        return p.future
    }

    func iMayFailRandomlyAlso() -> Future<[String: Int]> {
        return Future(.main) { () -> Completion<[String: Int]> in
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                return .fail(FutureKitError.genericError("Failed Also"))
            case 1:
                return .cancelled
            default:
                return .success(["Hi": 5])
            }
        }
    }

    func iCopeWithWhatever() {

        // ALL 3 OF THESE FUNCTIONS BEHAVE THE SAME

        self.iMayFailRandomly().onComplete { (result) -> Completion<Void> in
            switch result {
            case let .success(value):
                NSLog("\(value)")
                return .success(())
            case let .fail(e):
                return .fail(e)
            case .cancelled:
                return .cancelled
            }
        }
        .ignoreFailures()

        self.iMayFailRandomly().onSuccess { _ -> Completion<Int> in
            return .success(5)
        }.ignoreFailures()

        self.iMayFailRandomly().onSuccess { _ -> Void in
            NSLog("")
        }.ignoreFailures()

    }

    func iDontReturnValues() -> Future<()> {
        let f = Future(.primary) { () -> Int in
            return 5
        }

        let p = Promise<()>()

        f.onSuccess { _ -> Void in
            DispatchQueue.main.async {
                p.completeWithSuccess(())
            }
        }.ignoreFailures()
        // let's do some async dispatching of things here:
        return p.future
    }

    func imGonnaMapAVoidToAnInt() -> Future<Int> {

        let x = self.iDontReturnValues()
        .onSuccess { _ -> Void in
            NSLog("do stuff")
        }.onSuccess { _ -> Int in
            return 5
        }.onSuccess(.primary) { fffive in
            Float(fffive + 10)
        }
        return x.onSuccess {
            Int($0) + 5
        }

    }

    func adding5To5Makes10() -> Future<Int> {
        return self.imGonnaMapAVoidToAnInt().onSuccess { (value) in
            return value + 5
        }
    }

    func convertNumbersToString() -> Future<String> {
        return self.imGonnaMapAVoidToAnInt().onSuccess {
            return "\($0)"
        }
    }

    func convertingAFuture() -> Future<NSString> {
        let f = convertNumbersToString()
        return f.mapAs()
    }

    func testing() {
        _ = Future<Int?>(success: 5)

//        let yx = convertOptionalFutures(x)

//        let y : Future<Int64?> = convertOptionalFutures(x)

    }

}
