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

import Foundation

public struct GLOBAL_PARMS {
    // WOULD LOVE TO TURN THESE INTO COMPILE TIME PROPERTIES
    // MAYBE VIA an Objective C Header file?
    static let ALWAYS_ASYNC_DISPATCH_DEFAULT_TASKS = false
    static let WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING = false
    static let CANCELLATION_CHAINING = true
    
    static let STACK_CHECKING_PROPERTY = "FutureKit.immediate.TaskDepth"
    static let CURRENT_EXECUTOR_PROPERTY = "FutureKit.Executor.Current"
    static let STACK_CHECKING_MAX_DEPTH = 20
    
    public static var LOCKING_STRATEGY : SynchronizationType = .OSSpinLock
    
}

public enum FutureKitError : ErrorType, Equatable {
    case GenericError(String)
    case ResultConversionError(String)
    case CompletionConversionError(String)
    case ContinueWithConversionError(String)
    case ErrorForMultipleErrors(String,[ErrorType])
    case ExceptionCaught(NSException,[NSObject:AnyObject]?)

    public init(genericError : String) {
        self = .GenericError(genericError)
    }

    public init(exception: NSException) {
        var userInfo : [NSObject : AnyObject]
        if (exception.userInfo != nil) {
            userInfo = exception.userInfo!
        }
        else {
            userInfo = [NSObject : AnyObject]()
        }
        userInfo["exception"] = NSException(name: exception.name, reason: exception.reason, userInfo: nil)
        userInfo["callStackReturnAddresses"] = exception.callStackReturnAddresses
        userInfo["callStackSymbols"] = exception.callStackSymbols
        self = .ExceptionCaught(exception,userInfo)
    }
    
}

public func == (l: FutureKitError, r: FutureKitError) -> Bool {
    
    switch l {
    case let .GenericError(lhs):
        switch r {
        case let .GenericError(rhs):
            return (lhs == rhs)
        default:
            return false
        }
    case let .ResultConversionError(lhs):
        switch r {
        case let .ResultConversionError(rhs):
            return (lhs == rhs)
        default:
            return false
        }
    case let .CompletionConversionError(lhs):
        switch r {
        case let .CompletionConversionError(rhs):
            return (lhs == rhs)
        default:
            return false
        }
    case let .ContinueWithConversionError(lhs):
        switch r {
        case let .ContinueWithConversionError(rhs):
            return (lhs == rhs)
        default:
            return false
        }
    case let .ErrorForMultipleErrors(lhs,_):
        switch r {
        case let .ErrorForMultipleErrors(rhs,_):
            return (lhs == rhs)
        default:
            return false
        }
    case let .ExceptionCaught(lhs,_):
        switch r {
        case let .ExceptionCaught(rhs,_):
            return (lhs.isEqual(rhs))
        default:
            return false
        }
    }
}


       
        
internal class CancellationTokenSource {
    
    // we are going to keep a weak copy of each token we give out.
    // as long as there
    internal typealias CancellationTokenPtr = Weak<CancellationToken>
    
    private var tokens : [CancellationTokenPtr] = []
    
    // once we have triggered cancellation, we can't do it again
    private var canBeCancelled = true
    
    // this is to flag that someone has made a non-forced cancel request, but we are ignoring it due to other valid tokens
    // if those tokens disappear, we will honor the cancel request then.
    private var pendingCancelRequestActive = false
    
    
    private var handler : CancellationHandler?
    private var forcedCancellationHandler : CancellationHandler
    
    init(forcedCancellationHandler h: CancellationHandler) {
        self.forcedCancellationHandler = h
    }

    private var cancellationIsSupported : Bool {
        return (self.handler != nil)
    }
    
    // add blocks that will be called as soon as we initiate cancelation
    internal func addHandler(h : CancellationHandler) {
        if !self.canBeCancelled {
            return
        }
        if let oldhandler = self.handler
        {
            self.handler = { (options) in
                oldhandler(options: options)
                h(options: options)
            }
        }
        else {
            self.handler = h
        }
    }
    
    internal func clear() {
        self.handler = nil
        self.canBeCancelled = false
        self.tokens.removeAll()
    }

    internal func getNewToken(synchObject : SynchronizationProtocol, lockWhenAddingToken : Bool) -> CancellationToken {
        
        if !self.canBeCancelled {
            return self._createUntrackedToken()
        }
        let token = self._createTrackedToken(synchObject)
        
        
        if (lockWhenAddingToken) {
            synchObject.lockAndModify { () -> Void in
                if self.canBeCancelled {
                    self.tokens.append(CancellationTokenPtr(token))
                }
            }
        }
        else {
            self.tokens.append(CancellationTokenPtr(token))
        }
        return token
    }

    
    private func _createUntrackedToken() -> CancellationToken {
        
        return CancellationToken(
            
            onCancel: { [weak self] (options, token) -> Void in
                self?._performCancel(options)
            },
            
            onDeinit:nil)
       
    }
    private func _createTrackedToken(synchObject : SynchronizationProtocol) -> CancellationToken {
        
        return CancellationToken(
            
            onCancel: { [weak self] (options, token) -> Void in
                self?._cancelRequested(token, options, synchObject)
            },
            
            onDeinit:{ [weak self] (token) -> Void in
                self?._clearInitializedToken(token,synchObject)
            })
        
    }
    
    private func _removeToken(cancelingToken:CancellationToken) {
        // so remove tokens that no longer exist and the requested token
        self.tokens = self.tokens.filter { (tokenPtr) -> Bool in
            if let token = tokenPtr.value {
                return (token !== cancelingToken)
            }
            else {
                return false
            }
        }
    }
    

    private func _performCancel(options : CancellationOptions) {
        
        if self.canBeCancelled {
            if (options.contains(.ForwardCancelRequestEvenIfThereAreOtherFuturesWaiting)) {
                self.tokens.removeAll()
            }
            // there are no active tokens remaining, so allow the cancellation
            if (self.tokens.count == 0) {
                self.handler?(options: options)
                self.canBeCancelled = false
                self.handler = nil
            }
            else {
                self.pendingCancelRequestActive = true
            }
        }
        if options.contains(.ForceThisFutureToBeCancelledImmediately) {
            self.forcedCancellationHandler(options: options)
        }
        
    }
    
    private func _cancelRequested(cancelingToken:CancellationToken, _ options : CancellationOptions,_ synchObject : SynchronizationProtocol) {
        
        synchObject.lockAndModify { () -> Void in

            self._removeToken(cancelingToken)
            self._performCancel(options)

        }
        
    }
    
    private func _clearInitializedToken(token:CancellationToken,_ synchObject : SynchronizationProtocol) {
        
        synchObject.lockAndModifySync { () -> Void in
            self._removeToken(token)
            
            if (self.pendingCancelRequestActive && self.tokens.count == 0) {
                self.canBeCancelled = false
                self.handler?(options: [])
            }
        }
    }


    
    
}



public struct CancellationOptions : OptionSetType{
    public let rawValue : Int
    public init(rawValue:Int){ self.rawValue = rawValue}

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
        firstChildCancelToken.cancel([.ForwardCancelRequestEvenIfThereAreOtherFuturesWaiting])
        
    should result in `future` and `secondChildofFuture` being cancelled.
    otherwise future may ignore the firstChildCancelToken request to cancel, because it is still trying to satisify secondChildofFuture

    */
    static let ForwardCancelRequestEvenIfThereAreOtherFuturesWaiting        = CancellationOptions(rawValue:1)
  
    /**
    If this future is dependent on the result of another future (via onComplete or .CompleteUsing(f))
    than this cancellation request should NOT be forwarded to that future.
    depending on the future's implementation, you may need include .ForceThisFutureToBeCancelledImmediately for cancellation to be successful
    
    */
    static let DoNotForwardRequest    = CancellationOptions(rawValue:2)

    /**
    this is allows you to 'short circuit' a Future's internal cancellation request logic.
    The Cancellation request is still forwarded (unless .DoNotForwardRequest is also sent), but an unfinished Future will be forced into the .Cancelled state early.
    
    */
    static let ForceThisFutureToBeCancelledImmediately    = CancellationOptions(rawValue:4)

    
}

internal typealias CancellationHandler = ((options:CancellationOptions) -> Void)

public class CancellationToken {

    final public func cancel(options : CancellationOptions = []) {
        self.onCancel?(options:options,token:self)
        self.onCancel = nil
    }

    public var cancelCanBeRequested : Bool {
        return (self.onCancel != nil)
    }

    
// private implementation details
    deinit {
        self.onDeinit?(token: self)
        self.onDeinit = nil
    }
    

    internal typealias OnCancelHandler = ((options : CancellationOptions,token:CancellationToken) -> Void)
    internal typealias OnDenitHandler = ((token:CancellationToken) -> Void)

    private var onCancel : OnCancelHandler?
    private var onDeinit : OnDenitHandler?
    
    internal init(onCancel c:OnCancelHandler?, onDeinit d: OnDenitHandler?) {
        self.onCancel = c
        self.onDeinit = d
    }
}



/**
    All Futures use the protocol FutureProtocol
*/
public protocol FutureProtocol {
    /**
    convert this future of type `Future<T>` into another future type `Future<S>`
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
        
        let t : T
        let s = t as! S
    
    
    example:
    
        let f = Future<Int>(success:5)
        let f2 : Future<Int32> = f.As()
        assert(f2.result! == Int32(5))
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future
    
        let fofany : Future<Any> = f.As()
        let fofvoid: Future<Void> = f.As()
    
    */
    func mapAs<S>() -> Future<S>

    /**
    convert Future<T> into another type Future<S?>.
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    
    example:
        let f = Future<String>(success:"5")
        let f2 : Future<[Int]?> = f.convertOptional()
        assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    */
    func mapAsOptional<S>() -> Future<S?>
    
    
    var description: String { get }
    
}


/**

    `Future<T>`

    A Future is a swift generic class that let's you represent an object that will be returned at somepoint in the future.  Usually from some asynchronous operation that may be running in a different thread/dispatch_queue or represent data that must be retrieved from a remote server somewhere.


*/
public class Future<T> : FutureProtocol{
    
    public typealias ReturnType = T
    
    internal typealias CompletionErrorHandler = Promise<T>.CompletionErrorHandler
    internal typealias completion_block_type = ((FutureResult<T>) -> Void)
    internal typealias cancellation_handler_type = (()-> Void)
    
    
    private final var __callbacks : [completion_block_type]?

    /**
        this is used as the internal storage for `var completion`
        it is not thread-safe to read this directly. use `var synchObject`
    */
    private final var __result : FutureResult<T>?
    
//    private final let lock = NSObject()
    
    // Warning - reusing this lock for other purposes is dangerous when using LOCKING_STRATEGY.NSLock
    // don't read or write values Future
    /**
        used to synchronize access to both __completion and __callbacks
        
        type of synchronization can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    internal final var synchObject : SynchronizationProtocol = GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()
    
    /**
    is executed used `cancel()` has been requested.
    
    */

    
    internal func addRequestHandler(h : CancellationHandler) {
        
        self.synchObject.lockAndModify { () -> Void in
            self.cancellationSource.addHandler(h)
        }
    }

    lazy var cancellationSource: CancellationTokenSource = {
        return CancellationTokenSource(forcedCancellationHandler: { [weak self] (options) -> Void in
            
            assert(options.contains(.ForceThisFutureToBeCancelledImmediately), "the forced cancellation handler is only supposed to run when the .ForceThisFutureToBeCancelledImmediately option is on")
            self?.completeWith(.Cancelled)
        })
    }()

    
    /**
        returns: the current completion value of the Future
    
        accessing this variable directly requires thread synchronization.
    
        It is more efficient to examine completion values that are sent to an onComplete/onSuccess handler of a future than to examine it directly here.
    
        type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    public final var result : FutureResult<T>? {
        get {
            return self.synchObject.lockAndReadSync { () -> FutureResult<T>? in
                return self.__result
            }
        }
    }
    
    /**
    returns: the result of the Future iff the future has completed successfully.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    public var value : T? {
        get {
            return self.result?.value
        }
    }
    /**
    returns: the error of the Future iff the future has completed with an Error.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    public var error : ErrorType? {
        get {
            return self.result?.error
        }
    }

    /**
    is true if the Future supports cancellation requests using `cancel()`
    
    May return true, even if the Future has already been completed, and cancellation is no longer possible.
    
    It only informs the user that this type of future can be cancelled.
    */
    public var cancellationIsSupported : Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return (self.cancellationSource.cancellationIsSupported)
        }
    }
    
    /**
    returns: true if the Future has completed with any completion value.
    
    is NOT threadsafe
    */
    private final var __isCompleted : Bool {
        return (self.__result != nil)
    }

    /**
    returns: true if the Future has completed with any completion value.
    
    accessing this variable directly requires thread synchronization.
    */
    public final var isCompleted : Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return self.__isCompleted
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

    /**
    creates a completed Future.
    */
    public init(completed:FutureResult<T>) {  // returns an completed Task
        self.__result = completed
    }
    /**
        creates a completed Future with a completion == .Success(success)
    */
    public init(success:T) {  // returns an completed Task  with result T
        self.__result = .Success(success)
    }
    /**
    creates a completed Future with a completion == .Error(failed)
    */
    public init(failed:ErrorType) {  // returns an completed Task that has Failed with this error
        self.__result = .Fail(failed)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(failWithErrorMessage))
    */
    public init(failWithErrorMessage errorMessage: String) {
        self.__result = FutureResult<T>(failWithErrorMessage:errorMessage)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(exception))
    */
    public init(exception:NSException) {  // returns an completed Task that has Failed with this error
        self.__result = FutureResult<T>(exception:exception)
    }
    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(cancelled:()) {  // returns an completed Task that has Failed with this error
        self.__result = .Cancelled
    }

    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(future f:Future<T>) {  // returns an completed Task that has Failed with this error
        self.completeWith(.CompleteUsing(f))
    }

    public convenience init(delay:NSTimeInterval, completeWith: Completion<T>) {
        let executor: Executor = .Primary
        
        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.executeAfterDelay(delay) { () -> Void in
            p.complete(completeWith)
        }
        self.init(future:p.future)
    }
    
    public convenience init(afterDelay:NSTimeInterval, completeWith: Completion<T>) {    // emits a .Success after delay
        let executor: Executor = .Primary

        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.executeAfterDelay(afterDelay) {
            p.complete(completeWith)
        }
        self.init(future:p.future)
    }
    
    public convenience init(afterDelay:NSTimeInterval, success:T) {    // emits a .Success after delay
        let executor: Executor = .Primary

        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.executeAfterDelay(afterDelay) {
            p.completeWithSuccess(success)
        }
        self.init(future:p.future)
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = .Success(block())
    
    can only be used to a create a Future that should always succeed.
    */
    public init(_ executor : Executor = .Immediate, block: () throws -> T) {
        let block = executor.callbackBlockFor { () -> Void in
            do {
                let r = try block()
                self.completeWith(.Success(r))
            }
            catch {
                self.completeWith(.Fail(error))

            }
        }
        block()
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = block()
    
    can be used to create a Future that may succeed or fail.  
    
    the block can return a value of .CompleteUsing(Future<T>) if it wants this Future to complete with the results of another future.
    */
    public init(_ executor : Executor = .Immediate, block: () throws -> Completion<T>) {
        executor.execute { () -> Void in
            do {
                self.completeWith(try block())
            }
            catch {
                self.completeWith(.Fail(error))
                
            }
        }
    }

    /**
        will complete the future and cause any registered callback blocks to be executed.
    
        may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
 
        type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
        - parameter completion: the value to complete the Future with
    
    */
    internal final func completeAndNotify(completion : Completion<T>) {
        
        return self.completeWithBlocks(waitUntilDone: false,
            completionBlock: { () -> Completion<T> in
                completion
            }, onCompletionError: nil)
    }

    /**
    will complete the future and cause any registered callback blocks to be executed.
    
    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
    
    if the Future has already been completed, the onCompletionError block will be executed.  This block may be running in any queue (depending on the configure synchronization type).
    
    type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY

    - parameter completion: the value to complete the Future with
    
    - parameter onCompletionError: a block to execute if the Future has already been completed.

    */
    internal final func completeAndNotify(completion : Completion<T>, onCompletionError : CompletionErrorHandler) {
        
        
        self.completeWithBlocks(waitUntilDone: false, completionBlock: { () -> Completion<T> in
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
    internal final func completeAndNotifySync(completion : Completion<T>) -> Bool {
        
        var ret = true
        self.completeWithBlocks(waitUntilDone: true, completionBlock: { () -> Completion<T> in
            return completion
        }) { () -> Void in
            ret = false
        }
        
        return ret
   }
    
    internal final func completeWithBlocks(
            waitUntilDone wait:Bool = false,
            completionBlock : () throws -> Completion<T>,
            onCompletionError : (() -> Void)? = nil) {
        
        typealias ModifyBlockReturnType = (callbacks:[completion_block_type]?,
                                            result:FutureResult<T>?,
                                            continueUsing:Future?)
        
        
        self.synchObject.lockAndModify(waitUntilDone: wait, modifyBlock: { () -> ModifyBlockReturnType in
            if let _ = self.__result {
                // future was already complete!
                return ModifyBlockReturnType(nil,nil,nil)
            }
            let c : Completion<T>
            do {
                c = try completionBlock()
            }
            catch {
                c = .Fail(error)
            }
            if (c.isCompleteUsing) {
                return ModifyBlockReturnType(callbacks:nil,result:nil,continueUsing:c.completeUsingFuture)
            }
            else {
                let callbacks = self.__callbacks
                self.__callbacks = nil
                self.cancellationSource.clear()
                self.__result = c.asResult()
                return ModifyBlockReturnType(callbacks,self.__result,nil)
            }
        }, then:{ (modifyBlockReturned:ModifyBlockReturnType) -> Void in
            if let callbacks = modifyBlockReturned.callbacks {
                for callback in callbacks {
                    callback(modifyBlockReturned.result!)
                }
            }
            if let f = modifyBlockReturned.continueUsing {
                f.onComplete(.Immediate)  { (nextComp) -> Void in
                    self.completeWith(nextComp.asCompletion())
                }
                let token = f.getCancelToken()
                if token.cancelCanBeRequested {
                    self.addRequestHandler { (options : CancellationOptions) in
                        if !options.contains(.DoNotForwardRequest) {
                            token.cancel(options)
                        }
                    }
                }
            }
            else if (modifyBlockReturned.result == nil) {
                onCompletionError?()
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
    internal func completeWith(completion : Completion<T>) {
        return self.completeAndNotify(completion)
    }

    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.

    may block the current thread

    - parameter completion: the value to complete the Future with
    
    - returns: true if Future was successfully completed.  Returns false if the Future has already been completed.
    */
    internal func completeWithSync(completion : Completion<T>) -> Bool {
        
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
    internal func completeWith(completion : Completion<T>, onCompletionError errorBlock: CompletionErrorHandler) {
        return self.completeAndNotify(completion,onCompletionError: errorBlock)
    }
    
    /**
    
    takes a user supplied block (usually from func onComplete()) and creates a Promise and a callback block that will complete the promise.
    
    can add Objective-C Exception handling if GLOBAL_PARMS.WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING is enabled.
    
    - parameter forBlock: a user supplied block (via onComplete)
    
    - returns: a tuple (promise,callbackblock) a new promise and a completion block that can be added to __callbacks
    
    */
    internal final func createPromiseAndCallback<S>(forBlock: ((FutureResult<T>) throws -> Completion<S>)) -> (promise : Promise<S> , completionCallback :completion_block_type) {
        
        let promise = Promise<S>()

        let completionCallback : completion_block_type = {(comp) -> Void in
            do {
                let c = try forBlock(comp)
                promise.complete(c)
            }
            catch {
                promise.completeWithFail(error)
            }
            return
        }
        return (promise,completionCallback)
        
    }

    
    /**
    takes a callback block and determines what to do with it based on the Future's current completion state.

    If the Future has already been completed, than the callback block is executed.

    If the Future is incomplete, it adds the callback block to the futures private var __callbacks

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
   
    - parameter callback: a callback block to be run if and when the future is complete
   */
    private final func runThisCompletionBlockNowOrLater<S>(callback : completion_block_type,promise: Promise<S>) {
        
        // lock my object, and either return the current completion value (if it's set)
        // or add the block to the __callbacks if not.
        self.synchObject.lockAndModifyAsync({ () -> FutureResult<T>? in
            
            // we are done!  return the current completion value.
            if let c = self.__result {
                return c
            }
            else
            {
                // we only allocate an array after getting the first __callbacks.
                // cause we are hyper sensitive about not allocating extra stuff for temporary transient Futures.
                switch self.__callbacks {
                case let .Some(cb):
                    var newcb = cb
                    newcb.append(callback)
                    self.__callbacks = newcb
                case .None:
                    self.__callbacks = [callback]
                }
                let t = self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken: false)
                promise.onRequestCancel(.Immediate) { (options) -> CancelRequestResponse<S> in
                    if !options.contains(.DoNotForwardRequest) {
                        t.cancel(options)
                    }
                    return .Continue
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
        if we try to convert a future from type T to type T, just ignore the request.
    
        the compile should automatically figure out which version of As() execute
    */
    public final func As() -> Future<T> {
        return self
    }

    /**
    if we try to convert a future from type T to type T, just ignore the request.
    
    the swift compiler can automatically figure out which version of mapAs() execute
    */
    public final func mapAs() -> Future<T> {
        return self
    }

    /**
    convert this future of type `Future<T>` into another future type `Future<__Type>`
    
    WARNING: if `T as! __Type` isn't legal, than your code may generate an exception.
    
    works iff the following code works:
    
        let t : T
        let s = t as! __Type
    
    example:
    
        let f = Future<Int>(success:5)
        let f2 : Future<Int32> = f.As()
        assert(f2.result! == Int32(5))
    
    you will need to formally declare the type of the new variable in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future
    
        let fofany : Future<Any> = f.As()
        let fofvoid: Future<Void> = f.As()
    
    - returns: a new Future of with the result type of __Type
    */
    @available(*, deprecated=1.1, message="renamed to mapAs()")
    public final func As<__Type>() -> Future<__Type> {
        return self.mapAs()
    }
    /**
    convert this future of type `Future<T>` into another future type `Future<__Type>`
    
    WARNING: if `T as! __Type` isn't legal, than your code may generate an exception.
    
    works iff the following code works:
    
    let t : T
    let s = t as! __Type
    
    example:
    
    let f = Future<Int>(success:5)
    let f2 : Future<Int32> = f.As()
    assert(f2.result! == Int32(5))
    
    you will need to formally declare the type of the new variable in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future
    
    let fofany : Future<Any> = f.As()
    let fofvoid: Future<Void> = f.As()
    
    - returns: a new Future of with the result type of __Type
    */
    public final func mapAs<__Type>() -> Future<__Type> {
        return self.map(.Immediate) { (result) -> __Type in
            return result as! __Type
        }
    }
    
    /**
    convert `Future<T>` into another type `Future<__Type?>`.
    
    WARNING: if `T as! __Type` isn't legal, than all Success values may be converted to nil
    
    example:
    
        let f = Future<String>(success:"5")
        let f2 : Future<[Int]?> = f.convertOptional()
        assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    - returns: a new Future of with the result type of __Type?

    */
    @available(*, deprecated=1.1, message="renamed to mapAsOptional()")
    public final func convertOptional<__Type>() -> Future<__Type?> {
        return mapAsOptional()
    }

    /**
    convert `Future<T>` into another type `Future<__Type?>`.
    
    WARNING: if `T as! __Type` isn't legal, than all Success values may be converted to nil
    
    example:
    
    let f = Future<String>(success:"5")
    let f2 : Future<[Int]?> = f.convertOptional()
    assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    - returns: a new Future of with the result type of __Type?
    
    */
    public final func mapAsOptional<__Type>() -> Future<__Type?> {
        return self.map(.Immediate) { (result) -> __Type? in
            return result as? __Type
        }
    }

// ---------------------------------------------------------------------------------------------------
// Block Handlers
// ---------------------------------------------------------------------------------------------------
    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future in any completion state, with the user defined type __Type.
    
    The `completion` argument will be set to the Completion<T> value that completed the target.  It will be one of 3 values (.Success, .Fail, or .Cancelled).
    
    The block must return one of four enumeration values (.Success/.Fail/.Cancelled/.CompleteUsing).   
    
    Returning a future `f` using .CompleteUsing(f) causes the future returned from this method to be completed when `f` completes, using the completion value of `f`. (Leaving the Future in an incomplete state, until 'f' completes).
    
    The new future returned from this function will be completed using the completion value returned from this block.

    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, and returns a new completion value for the new completion type.   The block must return a Completion value (Completion<__Type>).
    - returns: a new Future that returns results of type __Type  (Future<__Type>)
    
    */
    public final func onComplete<__Type>(executor : Executor = .Primary,block:(result:FutureResult<T>) throws -> Completion<__Type>) -> Future<__Type> {
        
        let (promise, completionCallback) = self.createPromiseAndCallback(block)
        let block = executor.callbackBlockFor(completionCallback)
        
        self.runThisCompletionBlockNowOrLater(block,promise: promise)
        
        return promise.future
    }
    
    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type __Type
    */
    public final func onComplete<__Type>(executor: Executor = .Primary, block:(result:FutureResult<T>) throws -> FutureResult<__Type>) -> Future<__Type> {
        return self.onComplete(executor) { (result) -> Completion<__Type> in
            return try block(result:result).asCompletion()
        }
    }

    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type __Type
    */
    public final func onComplete<__Type>(executor: Executor = .Primary, block:(result:FutureResult<T>) throws -> __Type) -> Future<__Type> {
        return self.onComplete(executor) { (result) -> Completion<__Type> in
            return .Success(try block(result:result))
        }
    }
    
   /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed with `.Success'.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter block: a block that will execute when this future completes.
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
    public final func onComplete(executor: Executor = .Primary, block:(result:FutureResult<T>) throws -> Void) -> Future<Void> {
        return self.onComplete(executor) { (result) -> Completion<Void> in
            return .Success(try block(result:result))
        }
    }
    
    
    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed when the future returned from the block is completed.  
    
    This is the same as returning Completion<T>.CompleteUsing(f)
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter block: a block that will execute when this future completes, and return a new Future.
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
    public final func onComplete<__Type>
            (executor: Executor = .Primary,
            block:(result:FutureResult<T>) throws -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(executor, block: { (result) -> Completion<__Type> in
            do {
                let f = try block(result:result)
                return .CompleteUsing(f)
            }
            catch {
                return .Fail(error)
            }
        })
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
    public func waitForComplete<__Type>(timeout: NSTimeInterval,
        executor : Executor,
        didComplete:(FutureResult<T>)-> Completion<__Type>,
        timedOut:()-> Completion<__Type>
        ) -> Future<__Type> {
            
            let p = Promise<__Type>()
            p.automaticallyCancelOnRequestCancel()
            self.onComplete(executor) { (c) -> Void in
                p.completeWithBlock({ () -> Completion<__Type> in
                    return didComplete(c)
                })
            }
            
            executor.executeAfterDelay(timeout)  {
                p.completeWithBlock { () -> Completion<__Type> in
                    return timedOut()
                }
            }
            
            return p.future
    }

    public func waitForSuccess<__Type>(timeout: NSTimeInterval,
        executor : Executor,
        didSucceed:(T)-> __Type,
        timedOut:()-> Completion<__Type>
        ) -> Future<__Type> {
            
            let p = Promise<__Type>()
            p.automaticallyCancelOnRequestCancel()
            self.onSuccess { (result) -> Void in
                p.completeWithSuccess(didSucceed(result))
            }
            
            executor.executeAfterDelay(timeout)  {
                p.completeWithBlock { () -> Completion<__Type> in
                    return timedOut()
                }
            }
            
            return p.future
    }

    
    /**
    executes a block only if the Future has not completed.  Will prevent the Future from completing until AFTER the block finishes.
    
    Warning : do not cause the target to complete or call getCancelationToken() or call cancel() on an existing cancel token for this target inside this block.  On some FutureKit implementations, this will cause a deadlock.
    
    It may be better to safer and easier to just guarantee your onSuccess/onComplete logic run inside the same serial dispatch queue or Executor (eg .Main) and examine the var 'result' or 'isCompleted' inside the same context.

    - returns: the value returned from the block if the block executed, or nil if the block didn't execute
    */
    public final func IfNotCompleted<__Type>(block:() -> __Type) -> __Type? {
        return self.synchObject.lockAndReadSync { () -> __Type? in
            if !self.__isCompleted {
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
    public final func checkResult<__Type>(block:(FutureResult<T>?) -> __Type) -> __Type {
        return self.synchObject.lockAndReadSync { () -> __Type in
            return block(self.__result)
        }
    }
    


    
    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The new future returned from this function will be completed using the completion value returned from this block.

    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a new Future of type Future<__Type>
    */
    public final func onSuccess<__Type>(executor : Executor = .Primary,
        block:(T) throws -> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(executor)  { (result) -> Completion<__Type> in
            switch result {
            case let .Success(value):
                return try block(value)
            case let .Fail(error):
                return .Fail(error)
            case .Cancelled:
                return .Cancelled
            }
        }
    }
    
    /**
    takes a block and executes it if the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a `Future<Void>` that completes after this block has executed.
    */
    public final func onSuccess(executor : Executor = .Primary,
        block:(T) throws -> Void) -> Future<Void> {
        
        return self.onSuccess(executor) { (value) -> Completion<Void> in
            return .Success(try block(value))
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Success.  
    
    Currently, in swift 2.0, this is the only way to add a Success handler to a future of type `Future<Void>` or `Future<()>`.  But can be used with Future's of all types.  All results are converted to Any in your code.  This can be used as the 'type-unsafe' version of `OnSuccess`
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that returns the completion value of the returned Future.
    - returns: a new future of type `Future<__Type>`
    */
    @available(*, deprecated=1.1, message="depricated in latest swift 2, use onSuccess",renamed="onSuccess")
    public final func onAnySuccess<__Type>(executor : Executor = .Primary,
        block:(Any) throws -> Completion<__Type>) -> Future<__Type> {
            
            return self.onSuccess(executor) { (t:T) -> Completion<__Type> in
                return try block(t)
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
    public final func onFail(executor : Executor = .Primary,
        block:(error:ErrorType)-> Void) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isFail) {
                block(error: result.error)
            }
            return result.asCompletion()
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Fail
     
     If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Failures can be be remapped to different Completions.  (Such as consumed or ignored or retried via returning .CompleteUsing()
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block can process the error of a future.
     */
    public final func onFail(executor : Executor = .Primary,
        block:(error:ErrorType)-> Completion<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isFail) {
                return block(error: result.error)
            }
            return result.asCompletion()
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Fail
     
     If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Failures can be be remapped to different Completions.  (Such as consumed or ignored or retried via returning .CompleteUsing()
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block can process the error of a future.
     */
    public final func onFail(executor : Executor = .Primary,
        block:(error:ErrorType)-> Future<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isFail) {
                return .CompleteUsing(block(error: result.error))
            }
            return result.asCompletion()
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.  
    
     This method returns a new Future.  Cancellations
     
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    */
    public final func onCancel(executor : Executor = .Primary, block:()-> Void) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isCancelled) {
                block()
            }
            return result.asCompletion()
        }
    }

    /**
     takes a block and executes it iff the target is completed with a .Cancelled
     
     If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Cancellations
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
     */
    public final func onCancel(executor : Executor = .Primary, block:()-> Completion<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isCancelled) {
                return block()
            }
            return result.asCompletion()
        }
    }
    /**
     takes a block and executes it iff the target is completed with a .Cancelled
     
     If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.
     
     This method returns a new Future.  Cancellations
     
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
     */
    public final func onCancel(executor : Executor = .Primary, block:()-> Future<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            if (result.isCancelled) {
                return .CompleteUsing(block())
            }
            return result.asCompletion()
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
    public final func onFailorCancel(executor : Executor = .Primary,
        block:(FutureResult<T>)-> Void) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            switch result {
            case .Fail, .Cancelled:
                block(result)
            case .Success(_):
                break
            }
            return result.asCompletion()
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
    public final func onFailorCancel(executor : Executor = .Primary,
        block:(FutureResult<T>)-> Completion<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            switch result {
                case .Fail, .Cancelled:
                    return block(result)
                case let .Success(value):
                    return .Success(value)
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
    public final func onFailorCancel(executor : Executor = .Primary,
        block:(FutureResult<T>)-> Future<T>) -> Future<T>
    {
        return self.onComplete(executor) { (result) -> Completion<T> in
            switch result {
            case .Fail, .Cancelled:
                return .CompleteUsing(block(result))
            case let .Success(value):
                return .Success(value)
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
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns a new result.

    - returns: a new Future of type Future<__Type>
    */
    public final func onSuccess<__Type>(executor : Executor = .Primary,
        block:(T) throws -> __Type) -> Future<__Type> {
        return self.onSuccess(executor) { (value : T) -> Completion<__Type> in
            return .Success(try block(value))
        }
    }
    
  
    @available(*, deprecated=1.1, message="depricated in latest swift 2, use onSuccess",renamed="onSuccess")
    public final func onAnySuccess<__Type>(executor : Executor = .Primary,
        block:(Any) throws -> __Type) -> Future<__Type> {
        return self.onAnySuccess(executor) { (value) -> Completion<__Type> in
            return .Success(try block(value))
        }
    }

    public final func onSuccess<__Type>(executor : Executor = .Primary,
        block:(T) throws -> FutureResult<__Type>) -> Future<__Type> {
            return self.onSuccess(executor) { (value : T) -> Completion<__Type> in
                return try block(value).asCompletion()
            }
    }
    
    @available(*, deprecated=1.1, message="depricated in latest swift 2, use onSuccess",renamed="onSuccess")
    public final func onAnySuccess<__Type>(executor : Executor = .Primary,
        block:(Any) throws -> FutureResult<__Type>) -> Future<__Type> {
            return self.onAnySuccess(executor) { (value) -> Completion<__Type> in
                return try block(value).asCompletion()
            }
    }

//    public final func onAnySuccess<__Type>(block:(result:Any) throws -> __Type) -> Future<__Type> {
//        return self.onAnySuccess(.Primary,block: block)
//    }
//    public final func onSuccess<__Type>(@autoclosure(escaping) block:()-> __Type) -> Future<__Type> {
//        return self.onAnySuccess(.Primary,block)
//    }

    // rather use map?  Sure!
    public final func map<__Type>(executor : Executor = .Primary, block:(T) throws -> __Type) -> Future<__Type> {
        return self.onSuccess(executor,block:block)
    }

    
    public final func mapError(executor : Executor = .Primary, block:(ErrorType) throws -> ErrorType) -> Future<T> {
        return self.onComplete(executor)  { (result) -> Completion<T> in
            if case let .Fail(error) = result {
                return .Fail(try block(error))
            }
            else {
                return result.asCompletion()
            }
        }
    }

    
    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a .CompleteUsing((Future<__Type>) ------
    // ---------------------------------------------------------------------------------------------------

    public final func onSuccess<__Type>(executor : Executor = .Primary,
        block:(T) throws -> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(executor) { (t:T) -> Completion<__Type> in
            return .CompleteUsing(try block(t))
        }
    }
    
    @available(*, deprecated=1.1, message="depricated in latest swift 2, use onSuccess",renamed="onSuccess")
    public final func onAnySuccess<__Type>(executor : Executor = .Primary,
        block:(Any) throws -> Future<__Type>) -> Future<__Type> {
        return self.onAnySuccess(executor) { (value) -> Completion<__Type> in
            return .CompleteUsing(try block(value))
        }
    }
    
    
    /**
    */
    public final func getCancelToken() -> CancellationToken {
        return self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken:true)
    }

    
    public final func withCancelToken() -> (Future<T>,CancellationToken) {
        return (self,self.getCancelToken())
    }

    public final func waitUntilCompleted() -> FutureResult<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: true)
    }
    
    public final func waitForResult() -> T? {
        return self.waitUntilCompleted().value
    }

    public final func _waitUntilCompletedOnMainQueue() -> FutureResult<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: false)
    }
}



extension Future {
    /**
    **NOTE** identical to `onAnySuccess()`
    
    takes a block and executes it iff the target is completed with a .Success.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onSuccess()
    
    Unlike, onSuccess(), this function ignores the .Success result value. and it isn't sent it to the block.  onAnySuccess implies you don't about the result of the target, just that it completed with a .Success
    
    Currently, in swift 1.2, this is the only way to add a Success handler to a future of type Future<Void>.  But can be used with Future's of all types.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a new future of type `Future<__Type>`
    */
    
    final func then(block:() -> Void) -> Future<Void> {
        return self.then(.Primary,block: block)
    }
    final func then<__Type>(block:() -> Completion<__Type>) -> Future<__Type> {
        return self.then(.Primary,block: block)
    }
    final func then<__Type>(block:() -> __Type) -> Future<__Type> {
        return self.then(.Primary,block: block)
    }
    final func then<__Type>(block:() -> Future<__Type>) -> Future<__Type> {
        return self.then(.Primary,block: block)
    }
    final func then(executor : Executor, block:() -> Void) -> Future<Void> {
        return self.onSuccess(executor) { (_) -> Void in
            return block()
        }
    }

    final func then<__Type>(executor : Executor, block:() -> Completion<__Type>) -> Future<__Type> {
        return self.onSuccess(executor) { (_) -> Completion<__Type> in
            return block()
        }
    }
    final func then<__Type>(executor : Executor, block:() -> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(executor) { (_) -> Future<__Type> in
            return block()
        }
    }
    final func then<__Type>(executor : Executor, block:() -> __Type) -> Future<__Type> {
        return self.onSuccess(executor) { (_) -> __Type in
            return block()
        }
    }


}

extension Future : CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return self.debugDescription
    }
    public var debugDescription: String {
        let des = self.result?.description ?? "nil"
        return "Future<\(String(T.self))>{\(des)}"
    }
    public func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
    
}

internal protocol GenericOptional {
    typealias unwrappedType
    
    func isNil() -> Bool
    func unwrap() -> unwrappedType
    
    func map<U>(@noescape f: (unwrappedType) throws -> U) rethrows -> U?
    
    func flatMap<U>(@noescape f: (unwrappedType) throws -> U?) rethrows -> U?


    init()
    init(_ some: unwrappedType)
}


extension Optional : GenericOptional {
    typealias unwrappedType = Wrapped
    
    
    func isNil() -> Bool {
        switch self {
        case .None:
            return true
        case .Some:
            return false
        }
    }
    func unwrap() -> unwrappedType {
        return self!
    }

}

extension Future where T : GenericOptional {

    func As<OptionalS: GenericOptional>() -> Future<OptionalS.unwrappedType?> {
        return self.map { (value) -> OptionalS.unwrappedType? in
            
            if (value.isNil()) {
                return nil
            }
            return value.unwrap() as? OptionalS.unwrappedType
        }
    }

}

extension Future  {
    
    func AsOptional<OptionalS: GenericOptional>() -> Future<OptionalS.unwrappedType?> {
        return self.map { (value) -> OptionalS.unwrappedType? in
            return value as? OptionalS.unwrappedType
        }
    }
    
}


private var futureWithNoResult = Future<Any>()

class classWithMethodsThatReturnFutures {
    
    func iReturnAnInt() -> Future<Int> {
        return Future (.Immediate) { () -> Int in
            return 5
        }
    }
    
    func iReturnFive() -> Int {
        return 5
    }
    func iReturnFromBackgroundQueueUsingBlock() -> Future<Int> {
        //
        return Future(.Default) {
            self.iReturnFive()
        }
    }
    
    func iWillUseAPromise() -> Future<Int> {
        let p : Promise<Int> = Promise()
        
        // let's do some async dispatching of things here:
        dispatch_async(dispatch_get_main_queue()) {
            p.completeWithSuccess(5)
        }
        
        return p.future
        
    }
    
    func iMayFailRandomly() -> Future<[String:Int]>  {
        let p = Promise<[String:Int]>()
        
        dispatch_async(dispatch_get_main_queue()) {
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                p.completeWithFail(FutureKitError.GenericError("failed randomly"))
            case 1:
                p.completeWithCancel()
            default:
                p.completeWithSuccess(["Hi" : 5])
            }
        }
        return p.future
    }

    func iMayFailRandomlyAlso() -> Future<[String:Int]>  {
        return Future(.Main) { () -> Completion<[String:Int]> in
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                return .Fail(FutureKitError.GenericError("Failed Also"))
            case 1:
                return .Cancelled
            default:
                return .Success(["Hi" : 5])
            }
        }
    }

    func iCopeWithWhatever()  {
        
        // ALL 3 OF THESE FUNCTIONS BEHAVE THE SAME
        
        self.iMayFailRandomly().onComplete { (result) -> Completion<Void> in
            switch result {
            case let .Success(value):
                NSLog("\(value)")
                return .Success(())
            case let .Fail(e):
                return .Fail(e)
            case .Cancelled:
                return .Cancelled
            }
        }
        
        self.iMayFailRandomly().onSuccess { (value) -> Completion<Int> in
            return .Success(5)
        }
            
        
        self.iMayFailRandomly().onSuccess { (value) -> Void in
            NSLog("")
        }
    
        
    }
    
    func iDontReturnValues() -> Future<()> {
        let f = Future(.Primary) { () -> Int in
            return 5
        }
        
        let p = Promise<()>()
        
        f.onSuccess { (value) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                p.completeWithSuccess(())
            }
        }
        // let's do some async dispatching of things here:
        return p.future
    }
    
    func imGonnaMapAVoidToAnInt() -> Future<Int> {
        
        let f = self.iDontReturnValues().onSuccess { (_) -> Void in
            NSLog("do stuff")
        }.onSuccess { (value) -> Int in
            return 5
        }.onSuccess(.Primary) {(fffive) -> Float in
            Float(fffive + 10)
        }.onSuccess { (floatFifteen) -> Int in
            Int(floatFifteen) + 5
        }
        
        return f
    }
    
    func adding5To5Makes10() -> Future<Int> {
        return self.imGonnaMapAVoidToAnInt().onSuccess { (value) -> Int in
            return value + 5
        }
    }

    func convertNumbersToString() -> Future<String> {
        return self.imGonnaMapAVoidToAnInt().onSuccess { (value) -> String in
            return "\(value)"
        }
    }
    
    func convertingAFuture() -> Future<NSString> {
        let f = convertNumbersToString()
        return f.mapAs()
    }
    
    
    func testing() {
        _ = Future<Optional<Int>>(success: 5)
        
//        let yx = convertOptionalFutures(x)
        
//        let y : Future<Int64?> = convertOptionalFutures(x)
        
        
    }

    
}







