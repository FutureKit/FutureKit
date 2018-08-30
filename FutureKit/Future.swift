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
    static let STACK_CHECKING_MAX_DEPTH:Int32 = 20

    static var CONVERT_COMMON_NSERROR_VALUES_TO_CANCELLATIONS = true

    
    public static let LOCKING_STRATEGY : SynchronizationType = .pThreadMutex
    
}

public enum FutureKitError : Error, Equatable {
    case genericError(String)
    case resultConversionError(String)
    case completionConversionError(String)
    case continueWithConversionError(String)
    case errorForMultipleErrors(String,[Error])
    case exceptionCaught(NSException,[AnyHashable: Any]?)
    case futureDeinitWithoutCompletion(FileLineInfo)
    case refreshFailed(key: Any)
    case timedOutWaitingForResponse

    public init(genericError : String) {
        self = .genericError(genericError)
    }

    public init(exception: NSException) {
        var userInfo : [AnyHashable: Any]
        if (exception.userInfo != nil) {
            userInfo = exception.userInfo!
        }
        else {
            userInfo = [AnyHashable: Any]()
        }
        userInfo["exception"] = NSException(name: exception.name, reason: exception.reason, userInfo: nil)
        userInfo["callStackReturnAddresses"] = exception.callStackReturnAddresses
        userInfo["callStackSymbols"] = exception.callStackSymbols
        self = .exceptionCaught(exception,userInfo)
    }
    
}

public func == (l: FutureKitError, r: FutureKitError) -> Bool {

    switch (l,r) {
    case let (.genericError(lhs), .genericError(rhs)):
        return (lhs == rhs)

    case let (.resultConversionError(lhs), .resultConversionError(rhs)):
        return (lhs == rhs)

    case let (.completionConversionError(lhs), .completionConversionError(rhs)):
        return (lhs == rhs)

    case let (.continueWithConversionError(lhs), .continueWithConversionError(rhs)):
        return (lhs == rhs)
    case let (.errorForMultipleErrors(lhs, _), .errorForMultipleErrors(rhs, _)):
        return (lhs == rhs)

    case let (.exceptionCaught(lhs, _), .exceptionCaught(rhs, _)):
        return (lhs == rhs)

    case let (.futureDeinitWithoutCompletion(lhs), .futureDeinitWithoutCompletion(rhs)):
        return (lhs.description == rhs.description)
    default:
        return false
    }
}


       
        
internal class CancellationTokenSource {
    
    // we are going to keep a weak copy of each token we give out.
    // as long as there
    internal typealias CancellationTokenPtr = Weak<CancellationToken>
    
    fileprivate var tokens : [CancellationTokenPtr] = []
    
    // once we have triggered cancellation, we can't do it again
    fileprivate var canBeCancelled = true
    
    // this is to flag that someone has made a non-forced cancel request, but we are ignoring it due to other valid tokens
    // if those tokens disappear, we will honor the cancel request then.
    fileprivate var pendingCancelRequestActive = false
    
    
    fileprivate var handlers: [CancellationHandler] = []
    fileprivate var forcedCancellationHandler: CancellationHandler
    
    init(forcedCancellationHandler h: @escaping CancellationHandler) {
        self.forcedCancellationHandler = h
    }

    fileprivate var cancellationIsSupported : Bool {
        return !self.handlers.isEmpty
    }
    
    // add blocks that will be called as soon as we initiate cancelation
    internal func addHandler(_ h : @escaping CancellationHandler) {
        if !self.canBeCancelled {
            return
        }
        self.handlers.append(h)
//        if let oldhandler = self.handler
//        {
//            self.handler = { (options) in
//                oldhandler(options)
//                h(options)
//            }
//        }
//        else {
//            self.handler = h
//        }
    }
    
    internal func clear() {
        self.handlers = []
        self.canBeCancelled = false
        self.tokens.removeAll()
    }

    internal func getNewToken(_ synchObject : SynchronizationProtocol,
                              lockWhenAddingToken : Bool,
                              _ fileLineInfo: FileLineInfo) -> CancellationToken {
        
        if !self.canBeCancelled {
            return self._createUntrackedToken()
        }
        let token = self._createTrackedToken(synchObject, fileLineInfo)
        
        
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

    
    fileprivate func _createUntrackedToken() -> CancellationToken {
        
        return CancellationToken(
            
            onCancel: { [weak self] (options, token) -> Void in
                self?._performCancel(options)
            },
            
            onDeinit:nil)
       
    }
    fileprivate func _createTrackedToken(_ synchObject : SynchronizationProtocol,
                                         _ fileLineInfo: FileLineInfo) -> CancellationToken {
        
        return CancellationToken(
            
            onCancel: { [weak self] (arguments, token) -> Void in
                self?._cancelRequested(token, arguments, synchObject)
            },
            
            onDeinit:{ [weak self] (token) -> Void in
                self?._clearInitializedToken(token,synchObject, fileLineInfo)
            })
        
    }
    
    fileprivate func _removeToken(_ cancelingToken:CancellationToken) {
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
    

    fileprivate func _performCancel(_ arguments : CancellationArguments) {
        
        if self.canBeCancelled {
            if (!arguments.options.contains(.DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting)) {
                self.tokens.removeAll()
            }
            // there are no active tokens remaining, so allow the cancellation
            if (self.tokens.count == 0) {
                for handler in self.handlers {
                    handler(arguments)
                }
                self.canBeCancelled = false
                self.handlers = []
            }
            else {
                self.pendingCancelRequestActive = true
            }
        }
        if arguments.options.contains(.ForceThisFutureToBeCancelledImmediately) {
            self.forcedCancellationHandler(arguments)
        }
        
    }
    
    fileprivate func _cancelRequested(_ cancelingToken:CancellationToken,
                                      _ arguments : CancellationArguments,
                                      _ synchObject : SynchronizationProtocol) {
        
        synchObject.lockAndModify { () -> Void in
            self._removeToken(cancelingToken)
        }
        self._performCancel(arguments)
       
    }
    
    fileprivate func _clearInitializedToken(_ token:CancellationToken,
                                            _ synchObject : SynchronizationProtocol,
                                            _ fileLineInfo: FileLineInfo) {
        
        synchObject.lockAndModifySync { () -> Void in
            self._removeToken(token)
            
            if (self.pendingCancelRequestActive && self.tokens.count == 0) {
                self.canBeCancelled = false
                let arguments = CancellationArguments(options: [],
                                                      fileLineInfo: fileLineInfo)
                for handler in self.handlers {
                    handler(arguments)
                }
            }
        }
    }
    
}



public struct CancellationOptions : OptionSet{
    public let rawValue : Int
    public init(rawValue:Int){ self.rawValue = rawValue}

    
    @available(*, deprecated: 1.1, message: "depricated, cancellation forwards to all dependent futures by default use onSuccess",renamed: "DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting")
    public static let ForwardCancelRequestEvenIfThereAreOtherFuturesWaiting        = CancellationOptions(rawValue:0)

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
    public static let DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting        = CancellationOptions(rawValue:1)
  
    /**
    If this future is dependent on the result of another future (via onComplete or .CompleteUsing(f))
    than this cancellation request should NOT be forwarded to that future.
    depending on the future's implementation, you may need include .ForceThisFutureToBeCancelledImmediately for cancellation to be successful
    
    */
    public static let DoNotForwardRequest    = CancellationOptions(rawValue:2)

    /**
    this is allows you to 'short circuit' a Future's internal cancellation request logic.
    The Cancellation request is still forwarded (unless .DoNotForwardRequest is also sent), but an unfinished Future will be forced into the .Cancelled state early.
    
    */
    public static let ForceThisFutureToBeCancelledImmediately    = CancellationOptions(rawValue:4)
    

    
}

internal struct CancellationArguments {
    let options:CancellationOptions
    let fileLineInfo: FileLineInfo
}

internal typealias CancellationHandler = ((CancellationArguments) -> Void)

open class CancellationToken {

    // TODO: add defaults back
    final public func cancel(_ options : CancellationOptions = [],
                             _ file: StaticString = #file,
                             _ line: UInt = #line) {
        return self.cancel(options, FileLineInfo(file,line))
    }

    final public func cancel(_ options : CancellationOptions = [],
                             _ fileLineInfo: FileLineInfo) {

        let arguments = CancellationArguments(options: options, fileLineInfo: fileLineInfo)
        self.onCancel?(arguments,self)
        self.onCancel = nil
    }

    open var cancelCanBeRequested : Bool {
        return (self.onCancel != nil)
    }

    
// private implementation details
    deinit {
        self.onDeinit?(self)
        self.onDeinit = nil
    }
    

    internal typealias OnCancelHandler = ((_ arguments : CancellationArguments,_ token:CancellationToken) -> Void)
    internal typealias OnDenitHandler = ((_ token:CancellationToken) -> Void)

    fileprivate var onCancel : OnCancelHandler?
    fileprivate var onDeinit : OnDenitHandler?
    
    internal init(onCancel c:OnCancelHandler?, onDeinit d: OnDenitHandler?) {
        self.onCancel = c
        self.onDeinit = d
    }
}


// Type Erased Future
public protocol AnyFuture {
    
    var futureAny : Future<Any> { get }

    func mapAs<S>(_ type: S.Type, _ file: StaticString, _ line: UInt) -> Future<S>

    func mapAs(_ type: Void.Type, _ file: StaticString, _ line: UInt) -> Future<Void>

}

extension AnyFuture {

    @available(*, deprecated, renamed: "mapAs(_:_:_:)")
    public func mapAs<S>(_ file: StaticString = #file, _ line: UInt = #line) -> Future<S> {
        return self.mapAs(S.self, file, line)
    }

}

/**
    All Futures use the protocol FutureProtocol
*/
public protocol FutureProtocol : AnyFuture {
    
    associatedtype T
    
    var result : FutureResult<T>? { get }

    var value : T? { get }


    func onCompleteAdvanced<C: CompletionType>(_ executor : Executor,
                                               _ fileLineInfo: FileLineInfo,
                                               block: @escaping (AdvancedFutureResult<T>) throws -> C) -> Future<C.T>

    
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
    func mapAs<S>(_ type: S.Type, _ file: StaticString, _ line: UInt) -> Future<S>

    func mapAs(_ type: Void.Type, _ file: StaticString, _ line: UInt) -> Future<Void>

    /**
    convert Future<T> into another type Future<S?>.
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    
    example:
        let f = Future<String>(success:"5")
        let f2 : Future<[Int]?> = f.convertOptional()
        assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    */
    func mapAsOptional<S>(_ type: S.Type, _ file: StaticString, _ line: UInt) -> Future<S?>
 
    
//    func mapAs() -> Future<Void>

    
    var description: String { get }
    
    func getCancelToken(_ file: StaticString,
                        _ line: UInt) -> CancellationToken
    
}

public extension FutureProtocol  {

    public func onComplete<C: CompletionType>(_ executor : Executor,
                                       _ file: StaticString,
                                       _ line: UInt,
                                       block: @escaping (_ result:FutureResult<T>) throws -> C) -> Future<C.T> {
        let fileLineInfo = FileLineInfo(file, line)
        return self.onCompleteAdvanced(executor, fileLineInfo) { advResult throws -> C in
            return try block(advResult.result)
        }
    }


    public func mapAs<S>(_ type: S.Type, file: StaticString = #file, line: UInt = #line) -> Future<S> {
        return self.mapAs(type, file, line)
    }
    
    var futureAny : Future<Any> {
        return self.mapAs(Any.self)
    }

}


/**

    `Future<T>`

    A Future is a swift generic class that let's you represent an object that will be returned at somepoint in the future.  Usually from some asynchronous operation that may be running in a different thread/dispatch_queue or represent data that must be retrieved from a remote server somewhere.


*/
open class Future<T> : FutureProtocol {
    
    public typealias ReturnType = T
    
    internal typealias CompletionErrorHandler = Promise<T>.CompletionErrorHandler
    internal typealias CompletionBlockType = ((AdvancedFutureResult<T>) -> Void)
    internal typealias CancellationHandlerType = (()-> Void)
    
    
    fileprivate final var __callbacks : [CompletionBlockType]?

    /**
        this is used as the internal storage for `var completion`
        it is not thread-safe to read this directly. use `var synchObject`
    */
    fileprivate final var __result : FutureResult<T>?

//    private final let lock = NSObject()
    
    // Warning - reusing this lock for other purposes is dangerous when using LOCKING_STRATEGY.NSLock
    // don't read or write values Future
    /**
        used to synchronize access to both __completion and __callbacks
        
        type of synchronization can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    internal let synchObject = PThreadMutexSynchronization()
    
    /**
    is executed used `cancel()` has been requested.
    
    */

    let creationLocation: FileLineInfo
    var completionLocation: FileLineInfo?

    
    internal func addRequestHandler(_ h : @escaping CancellationHandler) {
        
        self.synchObject.lockAndModify { () -> Void in
            self.cancellationSource.addHandler(h)
        }
    }

    lazy var cancellationSource: CancellationTokenSource = {
        return CancellationTokenSource(forcedCancellationHandler: { [weak self] (arguments) -> Void in
            
            assert(arguments.options.contains(.ForceThisFutureToBeCancelledImmediately), "the forced cancellation handler is only supposed to run when the .ForceThisFutureToBeCancelledImmediately option is on")
            self?.completeWith(.cancelled, arguments.fileLineInfo)
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
    open var value : T? {
        get {
            return self.result?.value
        }
    }
    /**
    returns: the error of the Future iff the future has completed with an Error.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    open var error : Error? {
        get {
            return self.result?.error
        }
    }

    /**
    is true if the Future supports cancellation requests using `cancel()`
    
    May return true, even if the Future has already been completed, and cancellation is no longer possible.
    
    It only informs the user that this type of future can be cancelled.
    */
    open var cancellationIsSupported : Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return (self.cancellationSource.cancellationIsSupported)
        }
    }
    
    /**
    returns: true if the Future has completed with any completion value.
    
    is NOT threadsafe
    */
    fileprivate final var __isCompleted : Bool {
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
    internal init(_ file: StaticString, _ line: UInt) {
        self.creationLocation = FileLineInfo(file, line)
    }

    internal init(_ fileLineInfo: FileLineInfo) {
        self.creationLocation = fileLineInfo
    }

    deinit {
        if __result == nil {
            NSLog("warning - future is freed without completion \(self.creationLocation.description)")
            let error: FutureKitError = .futureDeinitWithoutCompletion(self.creationLocation)
            self.completeWith(.fail(error), self.creationLocation)
        }
    }
    
    
//    internal init(cancellationSource s: CancellationTokenSource) {
//        self.cancellationSource = s
//    }

    /**
    creates a completed Future.
    */
//    public init(result:FutureResult<T>) {  // returns an completed Task
//        self.__result = result
//    }
    /**
        creates a completed Future with a completion == .Success(success)
    */
    public init(success:T, _ file: StaticString = #file, _ line: UInt = #line) {  // returns an completed Task  with result T
        self.creationLocation = FileLineInfo(file, line)
        self.__result = .success(success)
    }
    /**
    creates a completed Future with a completion == .Error(failed)
    */
    public init(fail:Error, _ file: StaticString = #file, _ line: UInt = #line) {  // returns an completed Task that has Failed with this error
        self.creationLocation = FileLineInfo(file, line)
        self.__result = .fail(fail)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(failWithErrorMessage))
    */
    public init(failWithErrorMessage errorMessage: String, _ file: StaticString = #file, _ line: UInt = #line) {
        self.creationLocation = FileLineInfo(file, line)
        self.__result = FutureResult<T>(failWithErrorMessage:errorMessage)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(exception))
    */
    public init(exception:NSException, _ file: StaticString = #file, _ line: UInt = #line) {  // returns an completed Task that has Failed with this error
        self.creationLocation = FileLineInfo(file, line)
        self.__result = FutureResult<T>(exception:exception)
    }
    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(cancelled:(), _ file: StaticString = #file, _ line: UInt = #line) {  // returns an completed Task that has Failed with this error
        self.creationLocation = FileLineInfo(file, line)
        self.__result = .cancelled
    }

    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(completeUsing f:Future<T>, _ file: StaticString = #file, _ line: UInt = #line) {  // returns an completed Task that has Failed with this error
        self.creationLocation = FileLineInfo(file, line)
        self.completeWith(.completeUsing(f), self.creationLocation)
    }

    public convenience init<C:CompletionType>(delay:TimeInterval, completeWith: C, _ file: StaticString = #file, _ line: UInt = #line) where C.T == T {
        let executor: Executor = .primary
        
        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.execute(afterDelay:delay) { () -> Void in
            p.complete(completeWith)
        }
        self.init(completeUsing:p.future, file, line)
    }
    
    public convenience init(afterDelay delay:TimeInterval, success:T, _ file: StaticString = #file, _ line: UInt = #line) {    // emits a .Success after delay
        let executor: Executor = .primary

        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        executor.execute(afterDelay:delay) {
            p.completeWithSuccess(success)
        }
        self.init(completeUsing:p.future, file, line)
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = .Success(block())
    
    can only be used to a create a Future that should always succeed.
    */
    public init(_ executor : Executor = .immediate , _ file: StaticString = #file, _ line: UInt = #line, block: @escaping () throws -> T) {
        self.creationLocation = FileLineInfo(file, line)
        let wrappedBlock = executor.callbackBlockFor { () -> Void in
            do {
                let r = try block()
                self.completeWith(.success(r), self.creationLocation)
            }
            catch {
                self.completeWith(.fail(error), self.creationLocation)

            }
        }
        wrappedBlock()
    }
/*    public init(_ executor : Executor = .immediate, block: @autoclosure @escaping () -> T) {
        let wrappedBlock = executor.callbackBlockFor { () -> Void in
            self.completeWith(.success(block()))
        }
        wrappedBlock()
    } */
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = block()
    
    can be used to create a Future that may succeed or fail.  
    
    the block can return a value of .CompleteUsing(Future<T>) if it wants this Future to complete with the results of another future.
    */
    public init<C:CompletionType>(_ executor : Executor  = .immediate,
                                  _ file: StaticString = #file,
                                  _ line: UInt = #line,
                                  block: @escaping () throws -> C) where C.T == T {
        let fileLineInfo = FileLineInfo(file, line)
        self.creationLocation = fileLineInfo
       executor.execute { () -> Void in
            self.completeWithBlocks(fileLineInfo, completionBlock: {
                return try block()
            })
        }
    }
/*    public init<C:CompletionType>(_ executor : Executor  = .immediate, block: @autoclosure @escaping () -> C) where C.T == T {
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
    internal final func completeAndNotify<C:CompletionType>(_ completion : C,
                                                            _ fileLineInfo: FileLineInfo) where C.T == T {
        
        return self.completeWithBlocks(fileLineInfo, waitUntilDone: false,
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

    internal final func completeAndNotify<C:CompletionType>(_ completion : C,
                                                            _ fileLineInfo: FileLineInfo,
                                                            onCompletionError : @escaping CompletionErrorHandler) where C.T == T {
        
        
        self.completeWithBlocks(fileLineInfo, waitUntilDone: false, completionBlock: { () -> C in
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
    internal final func completeAndNotifySync<C:CompletionType>(_ completion : C,
                                                                _ fileLineInfo: FileLineInfo) -> Bool where C.T == T {
        
        var ret = true
        self.completeWithBlocks(fileLineInfo, waitUntilDone: true, completionBlock: { () -> C in
            return completion
        }) { () -> Void in
            ret = false
        }
        
        return ret
   }
    
    internal final func completeWithBlocks<C:CompletionType>(
            _ fileLineInfo: FileLineInfo,
            waitUntilDone wait:Bool = false,
            completionBlock : @escaping () throws -> C,
            onCompletionError : @escaping () -> Void = {} ) where C.T == T {
    
        typealias ModifyBlockReturnType = (callbacks:[CompletionBlockType]?,
                                            result:FutureResult<T>?,
                                            continueUsing:Future?)


        let c : Completion<T>
        do {
            c = try completionBlock().completion
        }
        catch {
            c = .fail(error)
        }
        self.synchObject.lockAndModify(waitUntilDone: wait, modifyBlock: { () -> ModifyBlockReturnType in
            if let _ = self.__result {
                // future was already complete!
                return ModifyBlockReturnType(nil,nil,nil)
            }
            if (c.isCompleteUsing) {
                return ModifyBlockReturnType(callbacks:nil,result:nil,continueUsing:c.completeUsingFuture)
            }
            else {
                let callbacks = self.__callbacks
                self.__callbacks = nil
                self.cancellationSource.clear()
                self.__result = c.result
                self.completionLocation = fileLineInfo
                return ModifyBlockReturnType(callbacks,self.__result,nil)
            }
        }, then:{ (modifyBlockReturned:ModifyBlockReturnType) -> Void in
            if let callbacks = modifyBlockReturned.callbacks {
                for callback in callbacks {
                    let newResult = AdvancedFutureResult<T>(result: modifyBlockReturned.result!, fileLineInfo: fileLineInfo)
                    callback(newResult)
                }
            }
            if let f = modifyBlockReturned.continueUsing {
                f.onCompleteAdvanced(.immediate, fileLineInfo.file, fileLineInfo.line)  { (nextComp) -> Void in
                    let nextFileLineInfo = FileLineInfo(fileLineInfo.file, fileLineInfo.line, previous: nextComp.fileLineInfo)
                    self.completeWith(nextComp.completion, nextFileLineInfo)
                }
                .ignoreFailures()
                let token = f.getCancelToken()
                if token.cancelCanBeRequested {
                    self.addRequestHandler { (arguments : CancellationArguments) in
                        if !arguments.options.contains(.DoNotForwardRequest) {
                            token.cancel(arguments.options, arguments.fileLineInfo)
                        }
                    }
                }
            }
            else if (modifyBlockReturned.result == nil) {
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
    internal func completeWith(_ completion : Completion<T>,
                               _ fileLineInfo: FileLineInfo) {
        return self.completeAndNotify(completion, fileLineInfo)
    }
    
    internal func completeWith<C:CompletionType>(_ completion : C,
                                                 _ fileLineInfo: FileLineInfo) where C.T == T {
        return self.completeAndNotify(completion, fileLineInfo)
    }


    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.

    may block the current thread

    - parameter completion: the value to complete the Future with
    
    - returns: true if Future was successfully completed.  Returns false if the Future has already been completed.
    */
    internal func completeWithSync<C:CompletionType>(_ completion : C,
                                                     _ fileLineInfo: FileLineInfo) -> Bool where C.T == T {
        
        return self.completeAndNotifySync(completion, fileLineInfo)
    }

    internal func completeWithSync(_ completion : Completion<T>,
                                   _ fileLineInfo: FileLineInfo) -> Bool {
        
        return self.completeAndNotifySync(completion, fileLineInfo)
    }

    
    /**
    if completion is of type .CompleteUsing(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.
    
    will execute the block onCompletionError if the Future has already been completed. The onCompletionError block  may execute inside any thread/queue, so care should be taken.

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.

    - parameter completion: the value to complete the Future with
    
    - parameter onCompletionError: a block to execute if the Future has already been completed.
    */
    
    internal func completeWith<C:CompletionType>
        (_ completion : C,
         _ fileLineInfo: FileLineInfo,
         onCompletionError errorBlock: @escaping CompletionErrorHandler) where C.T == T {
        return self.completeAndNotify(completion, fileLineInfo, onCompletionError: errorBlock)
    }
    
    /**
    
    takes a user supplied block (usually from func onComplete()) and creates a Promise and a callback block that will complete the promise.
    
    can add Objective-C Exception handling if GLOBAL_PARMS.WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING is enabled.
    
    - parameter forBlock: a user supplied block (via onComplete)
    
    - returns: a tuple (promise,callbackblock) a new promise and a completion block that can be added to __callbacks
    
    */
    internal struct PromiseCallback<T, C:CompletionType> {
        let promise: Promise<C.T>
        let completionCallback: ((AdvancedFutureResult<T>) -> Void)
        let executor: Executor

        var future: Future<C.T> {
            return promise.future
        }

        init(_ fileLineInfo: FileLineInfo,
             _ executor: Executor,
             _ forBlock: @escaping ((AdvancedFutureResult<T>) throws -> C)) {

            self.executor = executor
            let promise = Promise<C.T>(fileLineInfo)
            self.promise = promise

            self.completionCallback = {(comp) -> Void in
                do {
                    let c = try forBlock(comp)
                    promise.complete(c.completion, comp.fileLineInfo)
                }
                catch {
                    promise.completeWithFail(error, comp.fileLineInfo)
                }
                return
            }
         }

        var callbackBlock: ((AdvancedFutureResult<T>) -> Void) {
            let block = executor.callbackBlockFor(completionCallback)
            return block
        }
    }

    
    /**
    takes a callback block and determines what to do with it based on the Future's current completion state.

    If the Future has already been completed, than the callback block is executed.

    If the Future is incomplete, it adds the callback block to the futures private var __callbacks

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
   
    - parameter callback: a callback block to be run if and when the future is complete
   */
    fileprivate final func runThisCompletionBlockNowOrLater<S>(_ callback : @escaping CompletionBlockType,
                                                               promise: Promise<S>,
                                                               _ fileLineInfo: FileLineInfo) {
        
        // lock my object, and either return the current completion value (if it's set)
        // or add the block to the __callbacks if not.
        self.synchObject.lockAndModifyAsync(modifyBlock: { () -> AdvancedFutureResult<T>? in
            
            // we are done!  return the current completion value.
            if let c = self.__result {
                let cfileLineInfo = self.completionLocation ?? fileLineInfo
                return AdvancedFutureResult<T>(result: c, fileLineInfo: cfileLineInfo)
            }
            else
            {
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
                let t = self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken: false, fileLineInfo)
                promise.onRequestCancelAdvanced(.immediate) { (arguments) -> CancelRequestResponse<S> in
                    if !arguments.options.contains(.DoNotForwardRequest) {
                        t.cancel(arguments.options, arguments.fileLineInfo)
                    }
                    return .continue
                }
                return nil
            }
        }, then: { result -> Void in
            // if we got a completion value, than we can execute the callback now.
            if let result = result {
                callback(result)
            }
        })
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
    @available(*, deprecated, renamed: "mapAs(type:_:_:)")
    public final func As<S>() -> Future<S> {
        return self.mapAs(S.self)
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
    public final func mapAs<S>(_ mappedType: S.Type, _ file: StaticString = #file, _ line: UInt = #line) -> Future<S> {
        return self.map(.immediate) { (result) -> S in
            assert(result is S, "result \(result) is not convertable to \(S.self) \(file):\(line)")
            return result as! S
        }
    }

    public final func mapAs(_ type: Void.Type, _ file: StaticString = #file, _ line: UInt = #line) -> Future<Void> {
        return self.map(.immediate) { (result) -> Void in
            return ()
        }
    }


    

    @available(*, deprecated, renamed: "mapAs(_:_:_:)")
    public final func mapAs() -> Future<Void> {
        return self.map(.immediate) { (result) -> Void in
            return ()
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
    public final func mapAsOptional<S>(_ type: S.Type, _ file: StaticString = #file, _ line: UInt = #line) -> Future<S?> {
        return self.map(.immediate) { (result) -> S? in
            return result as? S
        }
    }


    public func finally(_ executor: Executor = .primary,
                        _ file: StaticString = #file,
                        _ line: UInt = #line,
                        block:@escaping () throws -> Void) -> Future<T> {
        return self.onComplete(executor, file, line) { result -> FutureResult<T> in
            try block()
            return result
        }
    }

    public func finally<C: CompletionType>(_ executor: Executor = .primary,
                                           _ file: StaticString = #file,
                                           _ line: UInt = #line,
                                           block:@escaping () throws -> C) -> Future<T> {
        return self
            .onComplete(executor, file, line) { result -> Completion<T> in
                let completion =  try block().completion
                switch completion {
                case let .completeUsing(f):
                    let newf = f.onComplete { _ in result }
                    return .completeUsing(newf)
                default:
                    return result.completion
                }
        }
    }


    
    /**
     executes a block only if the Future has not completed.  Will prevent the Future from completing until AFTER the block finishes.
     
     Warning : do not cause the target to complete or call getCancelationToken() or call cancel() on an existing cancel token for this target inside this block.  On some FutureKit implementations, this will cause a deadlock.
     
     It may be better to safer and easier to just guarantee your onSuccess/onComplete logic run inside the same serial dispatch queue or Executor (eg .Main) and examine the var 'result' or 'isCompleted' inside the same context.
     
     - returns: the value returned from the block if the block executed, or nil if the block didn't execute
     */
    public final func IfNotCompleted<__Type>(_ block:@escaping () -> __Type) -> __Type? {
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
    public final func checkResult<__Type>(_ block:@escaping (FutureResult<T>?) -> __Type) -> __Type {
        return self.synchObject.lockAndReadSync { () -> __Type in
            return block(self.__result)
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

    public final func onCompleteAdvanced<C: CompletionType>(_ executor : Executor,
                                                    _ fileLineInfo: FileLineInfo,
                                                    block: @escaping (AdvancedFutureResult<T>) throws -> C) -> Future<C.T> {

        let promiseCallBack = PromiseCallback<T,C>(fileLineInfo, executor, block)
        let block = executor.callbackBlockFor(promiseCallBack.completionCallback)
        self.runThisCompletionBlockNowOrLater(block, promise: promiseCallBack.promise, fileLineInfo)

        return promiseCallBack.promise.future
    }

    public final func onCompleteAdvanced<C: CompletionType>(_ executor : Executor,
                                                            _ file: StaticString = #file,
                                                            _ line: UInt = #line,
                                                            block: @escaping (AdvancedFutureResult<T>) throws -> C) -> Future<C.T> {
        let fileLineInfo = FileLineInfo(file, line)
        return self.onCompleteAdvanced(executor, fileLineInfo, block: block)
    }

    @discardableResult
    public final func onComplete<C: CompletionType>(_ executor : Executor,
                                                    _ file: StaticString = #file,
                                                    _ line: UInt = #line,
                                                    block: @escaping (FutureResult<T>) throws -> C) -> Future<C.T> {

        return self.onCompleteAdvanced(executor, file, line) { advResult -> C in
            return try block(advResult.result)
        }
    }



    /**
     */
    public final func getCancelToken(_ file: StaticString = #file, _ line: UInt = #line) -> CancellationToken {
        let fileLineInfo = FileLineInfo(file, line)
        return self.cancellationSource.getNewToken(self.synchObject, lockWhenAddingToken:true, fileLineInfo)
    }
    
    
    
    
    public final func delay(_ delay: TimeInterval) -> Future<T> {
        let completion: Completion<T> = .completeUsing(self)
        return Future(delay:delay, completeWith: completion)
    }
    
    
}

extension FutureProtocol {
    
    
    /**
     if we try to convert a future from type T to type T, just ignore the request.
     
     the compile should automatically figure out which version of As() execute
     */
//    public func As() -> Self {
//        return self
//    }
//
    /**
     if we try to convert a future from type T to type T, just ignore the request.
     
     the swift compiler can automatically figure out which version of mapAs() execute
     */
//    public func mapAs() -> Self {
//        return self
//    }

    

    public func withCancelToken(_ file: StaticString = #file,
                                _ line: UInt = #line) -> (Self,CancellationToken) {
        return (self,self.getCancelToken(file, line))
    }
    
    public func onComplete<C: CompletionType>(
        _ file: StaticString = #file,
        _ line: UInt = #line,
        _ block: @escaping (FutureResult<T>) throws -> C) -> Future<C.T> {
        return self.onComplete(.primary,file, line, block:block)
    }

    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type __Type
    */
    @discardableResult
    public func onComplete<S>(
        _ executor: Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        _ block:@escaping (_ result:FutureResult<T>) throws -> S) -> Future<S> {
        return self.onComplete(executor, file, line) { (result) -> Completion<S> in
            return .success(try block(result))
        }
    }

    @discardableResult
    public func onCompleteAdvanced<S>(
        _ executor: Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        _ block:@escaping (_ result:AdvancedFutureResult<T>) throws -> S) -> Future<S> {

        let fileLineInfo = FileLineInfo(file, line)
        return self.onCompleteAdvanced(executor, fileLineInfo) { (result) -> Completion<S> in
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
    public func waitForComplete<C:CompletionType>(
        _ timeout: TimeInterval,
        executor : Executor,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        didComplete:@escaping (FutureResult<T>) throws -> C,
        timedOut:@escaping () throws -> C
        ) -> Future<C.T> {

        let p = Promise<C.T>(file, line)
        p.automaticallyCancelOnRequestCancel()
        self.onComplete(executor, file, line) { (c) -> Void in
            p.completeWithBlock(file, line) { () -> C in
                return try didComplete(c)
            }
        }.ignoreFailures()

        executor.execute(afterDelay:timeout)  {
            p.completeWithBlock(file, line)  { () -> C in
                return try timedOut()
            }
        }
        return p.future
    }
    
    public func waitForComplete<__Type>(_ timeout: TimeInterval,
        executor : Executor,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        didComplete:@escaping (FutureResult<T>) throws -> __Type,
        timedOut:@escaping () throws -> __Type
        ) -> Future<__Type> {
            
            return self.waitForComplete(timeout,
                executor: executor,
                file,
                line,
                didComplete: {
                    return Completion<__Type>.success(try didComplete($0))
                },
                timedOut: {
                    .success(try timedOut())
            })
    }

    public func waitForSuccess<C:CompletionType>(_ timeout: TimeInterval,
        executor : Executor,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        didSucceed:@escaping (T) throws -> C.T,
        timedOut:@escaping () throws -> C
        ) -> Future<C.T> {
            
            let p = Promise<C.T>(file, line)
            p.automaticallyCancelOnRequestCancel()
            self.onSuccess { (result) -> Void in
                p.completeWithSuccess(try didSucceed(result))
            }.ignoreFailures()
            
            executor.execute(afterDelay:timeout)  {
                p.completeWithBlock { () -> C in
                    return try timedOut()
                }
            }
            
            return p.future
    }
    public func waitForSuccess<__Type>(_ timeout: TimeInterval,
        executor : Executor,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        didSucceed:(T) throws -> __Type,
        timedOut:() throws -> __Type
        ) -> Future<__Type> {
            
            return self.waitForSuccess(timeout,
                executor: executor,
                file,
                line,
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
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a new Future of type Future<__Type>
    */
    
    public func onSuccess<C: CompletionType>(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (T) throws -> C) -> Future<C.T> {
        return self.onComplete(executor, file, line)  { (result) -> Completion<C.T> in
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
     
     - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
     - parameter executor: an Executor to use to execute the block when it is ready to run.
     - parameter block: a block takes the .Success result of the target Future and returns a new result.
     
     - returns: a new Future of type Future<__Type>
     */
    
    public func onSuccess<__Type>(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (T) throws -> __Type) -> Future<__Type> {
            return self.onSuccess(executor, file, line) { (value : T) -> Completion<__Type> in
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
    @discardableResult public func onFail(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (_ error:Error)-> Void) -> Future<T>
    {
        return self.onComplete(executor, file, line) { (result) -> Completion<T> in
            if (result.isFail) {
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
    @discardableResult public func onFail<C:CompletionType>(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (_ error:Error)-> C) -> Future<T> where C.T == T
    {
        return self.onComplete(executor, file, line) { (result) -> Completion<T> in
            if (result.isFail) {
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
    @discardableResult public func onCancel(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping ()-> Void) -> Future<T>
    {
        return self.onComplete(executor, file, line) { (result) -> FutureResult<T> in
            if (result.isCancelled) {
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
    @discardableResult public func onCancel<C:CompletionType>(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping ()-> C) -> Future<T> where C.T == T
    {
        return self.onComplete(executor, file, line) { (result) -> Completion<T> in
            if (result.isCancelled) {
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
    @discardableResult public func onFailorCancel(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (FutureResult<T>)-> Void) -> Future<T>
    {
        return self.onComplete(executor, file, line) { (result) -> FutureResult<T> in
        
            switch result {
            case .fail, .cancelled:
                block(result)
            case .success(_):
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
    @discardableResult public func onFailorCancel<C:CompletionType>(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (FutureResult<T>)-> C) -> Future<T> where C.T == T
    {
        return self.onComplete(executor, file, line) { (result) -> Completion<T> in
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
    public func onFailorCancel(
        _ executor : Executor = .primary,
        _ file: StaticString = #file,
        _ line: UInt = #line,
        block:@escaping (FutureResult<T>)-> Future<T>) -> Future<T>
    {
        return self.onComplete(executor, file, line) { (result) -> Completion<T> in
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
    @discardableResult public func ignoreFailures() -> Self
    {
        return self
    }

    /*:
     
     this is basically a noOp method, but it removes the unused result compiler warning to add an error handler to your future.
     Typically this method will be totally removed by the optimizer, and is really there so that developers will clearly document that they are ignoring errors returned from a Future
     
     */
    @discardableResult public func assertOnFail() -> Self
    {
        self.onFail { error in
            assertionFailure("Future failed unexpectantly")
        }
        .ignoreFailures()
        return self
    }

    
    
    // rather use map?  Sure!
    public func map<__Type>(_ executor : Executor = .primary,
                            _ file: StaticString = #file,
                            _ line: UInt = #line,
                            block:@escaping (T) throws -> __Type) -> Future<__Type> {
        return self.onSuccess(executor, file, line, block:block)
    }

    
    public func mapError(_ executor : Executor = .primary,
                         _ file: StaticString = #file,
                         _ line: UInt = #line,
                         block:@escaping (Error) throws -> Error) -> Future<T> {
        return self.onComplete(executor, file, line)  { (result) -> FutureResult<T> in
            if case let .fail(error) = result {
                return .fail(try block(error))
            }
            else {
                return result
            }
        }
    }

    
    public func waitUntilCompleted() -> FutureResult<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: true)
    }
    
    public func waitForResult() -> T? {
        return self.waitUntilCompleted().value
    }

    public func _waitUntilCompletedOnMainQueue() -> FutureResult<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: false)
    }
}


extension Future where T == Void {
    public static var success: Future<Void> {
        return Future(success: ())
    }
}

extension Future {

    public static func success(_ value: T) -> Future<T> {
        return Future(success: value)
    }
    public static var cancelled: Future<T> {
        return Future(cancelled: ())
    }

    public static func fail(_ error: Error,
                            _ file: StaticString = #file,
                            _ line: UInt = #line) -> Future<T> {
        return Future(fail: error, file, line)
    }

    public static func failWithErrorMessage(_ errorMessage: String,
                                            _ file: StaticString = #file,
                                            _ line: UInt = #line) -> Future<T> {
        return Future(failWithErrorMessage: errorMessage, file, line)
    }

    public static func delay(_ delay: TimeInterval) -> Future<Void> {
        if delay == 0.0 {
            return Future<Void>(success: ())
        }
        return Future<Void>(afterDelay: delay, success: ())
    }

    public final func automaticallyCancel(afterDelay delay: TimeInterval) -> Future<T> {
        let p = Promise<T>(automaticallyCancelAfter: delay)
        p.completeUsingFuture(self)
        return p.future
    }
    public final func automaticallyFail(with error: Error, afterDelay delay: TimeInterval) -> Future<T> {
        let p = Promise<T>(automaticallyFailAfter: delay, error: error)
        p.completeUsingFuture(self)
        return p.future
    }


}


extension Future {
  
    public final func then<C:CompletionType>(_ executor : Executor = .primary,
                                      _ file: StaticString = #file,
                                      _ line: UInt = #line,
                                      block:@escaping (T) -> C) -> Future<C.T> {
        return self.onSuccess(executor, file, line, block: block)
    }
    public final func then<S>(_ executor : Executor = .primary,
                              _ file: StaticString = #file,
                              _ line: UInt = #line,
                              block:@escaping (T) -> S) -> Future<S> {
        return self.onSuccess(executor,block: block)
    }
}

extension Future : CustomStringConvertible, CustomDebugStringConvertible {
    
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
    associatedtype Wrapped
    
    func isNil() -> Bool
    func unwrap() -> Wrapped
    
    func map<U>(_ f: (Wrapped) throws -> U) rethrows -> U?
    
    func flatMap<U>(_ f: (Wrapped) throws -> U?) rethrows -> U?


    init(_ some: Wrapped)
}


extension Optional : OptionalProtocol {
    
    public func isNil() -> Bool {
        switch self {
        case .none:
            return true
        case .some:
            return false
        }
    }
    public func unwrap() -> Wrapped {
        return self!
    }

}

extension FutureProtocol where T : OptionalProtocol {

    func As<OptionalS: OptionalProtocol>(_ type: OptionalS.Type) -> Future<OptionalS.Wrapped?> {
        return self.map { (value) -> OptionalS.Wrapped? in
            
            if (value.isNil()) {
                return nil
            }
            return value.unwrap() as? OptionalS.Wrapped
        }
    }

}

extension FutureProtocol  {
    
    func AsOptional<OptionalS: OptionalProtocol>(_ type: OptionalS.Type) -> Future<OptionalS.Wrapped?> {
        return self.map { (value) -> OptionalS.Wrapped? in
            return value as? OptionalS.Wrapped
        }
    }
    
}


private var futureWithNoResult = Future<Any>(#file, #line)

class classWithMethodsThatReturnFutures {
    
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
        let p : Promise<Int> = Promise()
        
        // let's do some async dispatching of things here:
        DispatchQueue.main.async {
            p.completeWithSuccess(5)
        }
        
        return p.future
        
    }
    
    func iMayFailRandomly() -> Future<[String:Int]>  {
        let p = Promise<[String:Int]>()
        
        DispatchQueue.main.async {
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                p.completeWithFail(FutureKitError.genericError("failed randomly"))
            case 1:
                p.completeWithCancel()
            default:
                p.completeWithSuccess(["Hi" : 5])
            }
        }
        return p.future
    }

    func iMayFailRandomlyAlso() -> Future<[String:Int]>  {
        return Future(.main) { () -> Completion<[String:Int]> in
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                return .fail(FutureKitError.genericError("Failed Also"))
            case 1:
                return .cancelled
            default:
                return .success(["Hi" : 5])
            }
        }
    }

    func iCopeWithWhatever()  {
        
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
        
        self.iMayFailRandomly().onSuccess { (value) -> Completion<Int> in
            return .success(5)
        }.ignoreFailures()
            
        
        self.iMayFailRandomly().onSuccess { (value) -> Void in
            NSLog("")
        }.ignoreFailures()
    
        
    }
    
    func iDontReturnValues() -> Future<()> {
        let f = Future(.primary) { () -> Int in
            return 5
        }
        
        let p = Promise<()>()
        
        f.onSuccess { (value) -> Void in
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
        return f.mapAs(NSString.self)
    }
    
    
    func testing() {
        _ = Future<Optional<Int>>(success: 5)
        
//        let yx = convertOptionalFutures(x)
        
//        let y : Future<Int64?> = convertOptionalFutures(x)
        
        
    }

    
}







