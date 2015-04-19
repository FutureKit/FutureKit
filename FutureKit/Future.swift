//
//  Future.swift
//  Shimmer
//
//  Created by Michael Gray on 1/7/15.
//  Copyright (c) 2015 FlybyMedia. All rights reserved.
//

import Foundation

public struct FUTUREKIT_GLOBAL_PARMS {
    // WOULD LOVE TO TURN THESE INTO COMPILE TIME PROPERTIES
    // MAYBE VIA an Objective C Header file?
    static let ALWAYS_ASYNC_DISPATCH_DEFAULT_TASKS = false
    static let WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING = false
    
    static let STACK_CHECKING_PROPERTY = "FutureKit.immediate.TaskDepth"
    static let STACK_CHECKING_MAX_DEPTH = 20
    
    public static var LOCKING_STRATEGY : SynchronizationType = .NSLock
    public static var BATCH_FUTURES_WITH_CHAINING : Bool = false
    
}

public enum FErrors : Int {
    case GenericException = 1
    case ResultConversionError
    case CompletionConversionError
    case ContinueWithConversionError
    case ErrorForMultipleErrors
    
    static var errorDomain = "Futures"
}

public class FutureNSError : NSError {

    public init(genericError : String) {
        super.init(domain: FErrors.errorDomain, code: FErrors.GenericException.rawValue, userInfo: ["genericError" : genericError])
    }

    public init(error : FErrors, userInfo: [NSObject : AnyObject]?) {
        super.init(domain: FErrors.errorDomain, code: error.rawValue, userInfo: userInfo)
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
        super.init(domain: FErrors.errorDomain, code: FErrors.GenericException.rawValue, userInfo: userInfo)
    }

    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
}

class _FResult<T> {
    var result : T
    
    init(_ t: T) {
        self.result = t
    }
}


/**
    Defines a simple enumeration of the legal Completion states of a Future.

    - Success: The Future has completed Succesfully.
    - Fail: The Future has failed.
    - Cancelled:  The Future was cancelled. This is typically not seen as an error.

    The enumeration is Objective-C Friendly
*/
public enum CompletionState : Int {
    case Success
    case Fail
    case Cancelled
    // this doesn't include ContinueWith intentionally!
    // Tasks must complete in one these states

}

/**
Defines a an enumeration that stores both the state and the data associated with a Future completion.

- Success(Any): The Future completed Succesfully with a Result

- Fail(NSError): The Future has failed with an NSError.

- Cancelled(Any?):  The Future was cancelled. The cancellation can optionally include a token.

- ContinueWith(Future<T>):  This Future will be completed with the result of a "sub" Future. Only used by block handlers.
*/
public enum Completion<T> : Printable, DebugPrintable {
    /**
        An alias that defines the Type being used for .Success(SuccessType) enumeration.
        This is currently set to Any, but we may change to 'T' in a future version of swift
    */
    public typealias SuccessType = Any              // Works.  Makes me sad.
    // typealias SuccessPayloadType = T             // PERFECT! - But it CRASHES
    // typealias SuccessPayloadType = T!            // OK.  But it STILL Crashes
    // typealias SuccessPayloadType = _FResult<T>   // Confusing.  But is type safe.  Makes the Completion<T> switch
                                                    //       statements weirder.


    /**
        Future completed with a result of SuccessType
    */
    case Success(SuccessType)       //  why is this Success(Any) and not Success(T)
                                    //  or Success(T!)??
                                    //  Because of the evil IR Generation Swift crashiness.
                                    //  In a future version I expect to be able to change this to T or T!
                                    //  so we are using the SuccessPayloadType alias
                                            //  We are adding a assertion check inside of
    /**
        Future failed with error NSError
    */
    case Fail(NSError)
    
    /**
        Future was Cancelled.  A reason/token can optionally be sent by the canceler
    */
    case Cancelled(Any?)

    /**
        This Future's completion will be set by some other Future<T>.  This will only be used as a return value from the onComplete/onSuccess/onFail/onCancel handlers.  the var "completion" on Future should never be set to 'ContinueWith'.
    */
    case ContinueWith(Future<T>)
    
    
    
    /**
        returns a .Fail(FutureNSError) with a simple error string message.
    */
    public init(failWithErrorMessage : String) {
        self = .Fail(FutureNSError(genericError: failWithErrorMessage))
    }
    /**
        converts an NSException into an NSError.
        useful for generic Objective-C excecptions into a Future
    */
    public init(exception ex:NSException) {
        self = .Fail(FutureNSError(exception: ex))
    }
    
    public func isSuccess() -> Bool {
        switch self {
        case .Success:
            return true
        default:
            return false
        }
    }
    public func isFail() -> Bool {
        switch self {
        case .Fail:
            return true
        default:
            return false
        }
    }
    public func isCancelled() -> Bool {
        switch self {
        case .Cancelled:
            return true
        default:
            return false
        }
    }
    public var isComplete : Bool {
        get {
            switch self {
            case .ContinueWith:
                return false
            default:
                return true
            }
        }
    }

    /**
        get the Completion state for a completed state. It's easier to create a switch statement on a completion.state, rather than the completion itself (since a completion block will never be sent a .ContinueWith).
    */
    public var state : CompletionState {
        get {
            switch self {
            case .Success:
                return .Success
            case .Fail:
                return .Fail
            case .Cancelled:
                return .Cancelled
            case let .ContinueWith(f):
                assertionFailure("ContinueWith(f) don't have a completion state!")
                return .Fail
            }
        }
    }
    
    /**
        make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var result : T! {
        get {
            switch self {
            case let .Success(t):
                // if you crash here, it's because the result passsed to the future wasn't of type T!
                return (t as! T)
            default:
//                assertionFailure("don't call result without checking that the enumeration is .Error first.")
                return nil
            }
        }
    }
    /**
        make sure this enum is a .Fail before calling `result`. Use a switch or check .isError() first.
    */
    public var error : NSError! {
        get {
            switch self {
            case let .Fail(e):
                return e
            default:
//                assertionFailure("don't call .error without checking that the enumeration is .Error first.")
                return nil
            }
        }
    }
    /**
        will return a cancelToken iff the enumeration is a .Cancel.  May return nil (if no token was sent).  Can't be used to determine if the enumeration was .Cancel, so use .IsCancel() or use a switch.
    */
    public var cancelToken:Any? {
        get {
            switch self {
            case let .Cancelled(token):
                return token
            default:
                return nil
            }
        }
    }
    /**
    will return a future iff the enumeration is a .ContinueWith. Can't be used to determine if the enumeration was .ContinueWith, so use a switch.
    */
    public var continueWithFuture:Future<T>! {
        get {
            switch self {
            case let .ContinueWith(f):
                return f
            default:
//                assertionFailure("don't call .continueWithFuture without checking that the enumeration is .ContinueWith first.")
                return nil
            }
        }
    }
    
    public func convert() -> Completion<T> {
        return self
    }
    /**
        convert this completion of type Completion<T> into another type Completion<S>.
        
        may fail to compile if T is not convertable into S using "`as!`"
        
        works iff the following code works:
    
        'let t : T`
    
        'let s = t as! S'
    
    
        - example:
    
        `let c : Complete<Int> = .Success(5)`
    
        `let c2 : Complete<Int32> =  c.convert()`
    
        `assert(c2.result == Int32(5))`
    
        you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func convert<S>() -> Completion<S> {
        switch self {
        case let .Success(t):
            let r = t as! S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case let .Cancelled(reason):
            return .Cancelled(reason)
        case let .ContinueWith(f):
            let s : Future<S> = f.convert()
            return .ContinueWith(s)
        }
    }
    
    /**
    convert this completion of type Completion<T> into another type Completion<S?>.
    
    :returns: a new completionValue of type Completion<S?>
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    - example:
    
    `let c : Complete<String> = .Success("5")`
    
    `let c2 : Complete<[Int]?> =  c.convertOptional()`
    
    `assert(c2.result == nil)`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func convertOptional<S>() -> Completion<S?> {
        switch self {
        case let .Success(t):
            let r = t as? S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case let .Cancelled(reason):
            return .Cancelled(reason)
        case let .ContinueWith(f):
            let s : Future<S?> = f.convertOptional()
            return .ContinueWith(s)
        }
    }
    
    public var description: String {
        switch self {
        case let .Success(t):
            return ".Success(\(t))"
        case let .Fail(f):
            return ".Fail(\(f.localizedDescription))"
        case let .Cancelled(reason):
            return ".Cancelled(\(reason))"
        case let .ContinueWith(f):
            return ".ContinueWith(\(f.description))"
        }
    }
    public var debugDescription: String {
        return self.description
    }
    
    /**
        This doesn't seem to work yet in the XCode Debugger or Playgrounds.
        it seems that only NSObjectProtocol objects can use this method.
        Since this is a Swift Generic, it seems to be ignored.
        Sigh.
    */
    func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
}


/**
    All Futures use the protocol FutureProtocol
*/
public protocol FutureProtocol {
    /**
    convert this future of type Future<T> into another future type Future<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    example:
    
    `let f = Future<Int>(success:5)`
    
    `let f2 : Future<Int32> = f.convert()`
    
    `assert(f2.result! == Int32(5))`
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future `f`
    
    `let fofany : Future<Any> = f.convert()`
    
    `let fofvoid: Future<Void> = f.convert()`
    */
    func convert<S>() -> Future<S>

    /**
    convert Future<T> into another type Future<S?>.
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    
    example:
    
    `let f = Future<String>(success:"5")`
    
    `let f2 : Future<[Int]?> = f.convertOptional()`
    
    `assert(f2.result! == nil)`
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    */
func convertOptional<S>() -> Future<S?>
}


public class Future<T>  {
    
    
    internal typealias completionErrorHandler = Promise<T>.completionErrorHandler
    internal typealias completion_block_type = ((Completion<T>) -> Void)
    
    
    private final var __callbacks : [completion_block_type]?

    /**
        this is used as the internal storage for `var completion`
        it is not thread-safe to read this directly. use `var synchObject`
    */
    private final var __completion : Completion<T>?
    
//    private final let lock = NSObject()
    
    // Warning - reusing this lock for other purposes is dangerous when using LOCKING_STRATEGY.NSLock
    // don't read or write values Future
    /**
        used to synchronize access to both __completion and __callbacks
        
        type of synchronization can be configured via FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY
    
        Warning:  If you are thinking of using this object outside of 'completeWith', don't use .NSLock as a strategy AND call 'completeWith' inside of a read or modify block!  you will deadlock.
    */
    internal final let synchObject : SynchronizationProtocol = FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()
    
    
    /**
        returns: the current completion value of the Future
    
        accessing this variable directly requires thread synchronization.
    
        It is more efficient to examine completion values that are sent to an onComplete/onSuccess handler of a future than to examine it directly here.
    
        type of synchronization used can be configured via FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    public final var completion : Completion<T>? {
        get {
            return self.synchObject.readSync { () -> Completion<T>? in
                return self.__completion
            }
        }
    }
    
    /**
    returns: the result of the Future iff the future has completed successfully.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    public var result : T? {
        get {
            return self.completion?.result
        }
    }
    /**
    returns: the error of the Future iff the future has completed with an Error.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    public var error : NSError? {
        get {
            return self.completion?.error
        }
    }
    /**
    returns: the cancelToken of the Future iff the future has completed with an Cancel and Cancelation has a token.  returns nil otherwise.
    
    accessing this variable directly requires thread synchronization.
    */
    public var cancelToken:Any? {
        get {
            return self.completion?.cancelToken
        }
    }
    /**
    returns: the CompletionState of the Future
    
    accessing this variable directly requires thread synchronization.
    */
    public var completionState : CompletionState? {
        get {
            return self.completion?.state
        }
    }
    
    /**
    returns: true if the Future has completed with any completion value.
    
    accessing this variable directly requires thread synchronization.
    */
    public final var isCompleted : Bool {
        get {
            return self.synchObject.readSync { () -> Bool in
                return (self.__completion != nil)
            }
        }
    
    }
    
    /**
    You can't instanciate an incomplete Future directly.  You must use a Promsie, or use an Executor with a block.
    */
    internal init() {
    }
    
    /**
    creates a completed Future.
    */
    public init(completed:Completion<T>) {  // returns an completed Task
        self.__completion = completed
    }
    /**
        creates a completed Future with a completion == .Success(success)
    */
    public init(success:T) {  // returns an completed Task  with result T
        self.__completion = .Success(success)
    }
    /**
    creates a completed Future with a completion == .Error(failed)
    */
    public init(failed:NSError) {  // returns an completed Task that has Failed with this error
        self.__completion = .Fail(failed)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(failWithErrorMessage))
    */
    public init(failWithErrorMessage errorMessage: String) {
        self.__completion = Completion<T>(failWithErrorMessage:errorMessage)
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(exception))
    */
    public init(exception:NSException) {  // returns an completed Task that has Failed with this error
        self.__completion = Completion<T>(exception:exception)
    }
    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(cancelled:Any?) {  // returns an completed Task that has Failed with this error
        self.__completion = .Cancelled(cancelled)
    }

    
    public init(afterDelay:NSTimeInterval, completeWith: Completion<T>) {    // emits a .Success after delay
        Executor.Default.executeAfterDelay(afterDelay) { () -> Void in
            self.completeWith(completeWith)
        }
    }
    
    public init(afterDelay:NSTimeInterval, success:T) {    // emits a .Success after delay
        Executor.Default.executeAfterDelay(afterDelay) { () -> Void in
            self.completeWith(.Success(success))
        }
    }
    
    /**
    creates a completed Future with a completion == completion
    */
    public init(@autoclosure completion c:() -> Completion<T>) {
        self.__completion = c()
    }

    /**
    creates a completed Future with a completion == Success(block)
    */
    public init(@autoclosure success s:() -> T) {
        self.__completion = .Success(s())
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = .Success(block())
    
    can only be used to a create a Future that should always succeed.
    */
    public init(_ executor : Executor, block: () -> T) {
        let block = executor.callbackBlockFor { () -> Void in
            self.completeWith(.Success(block()))
        }
        block()
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = block()
    
    can be used to create a Future that may succeed or fail.  
    
    the block can return a value of .ContinueWith(Future<T>) if it wants this Future to complete with the results of another future.
    */
    public init(_ executor : Executor, block: () -> Completion<T>) {
        let block = executor.callbackBlockFor { () -> Void in
            self.completeWith(block())
        }
        block()
    }
}

extension Future {

    /**
        will complete the future and cause any registered callback blocks to be executed.
    
        may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
 
        type of synchronization used can be configured via FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY
    
        :param: completion the value to complete the Future with
    
    */
    internal func completeAndNotify(completion : Completion<T>) {
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        self.synchObject.modifyAsync({ () -> [completion_block_type]? in
            if (self.__completion != nil) {
                return nil
            }
            self.__completion = completion
            let cbs = self.__callbacks
            self.__callbacks = nil
            return cbs
            
            }, done: { (cbs) -> Void in
                if let callbacks = cbs {
                    for callback in callbacks {
                        callback(completion)
                    }
                }
        })
        
    }

    /**
    will complete the future and cause any registered callback blocks to be executed.
    
    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
    
    if the Future has already been completed, the onCompletionError block will be executed.  This block may be running in any queue (depending on the configure synchronization type).
    
    type of synchronization used can be configured via FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY

    :param: completion the value to complete the Future with
    
    :param: onCompletionError a block to execute if the Future has already been completed.

    */
    internal func completeAndNotify(completion : Completion<T>, onCompletionError : completionErrorHandler) {
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        self.synchObject.modifyAsync({ () -> (cbs:[completion_block_type]?,success:Bool) in
            if let c = self.__completion {
                return (nil,false)
            }
            self.__completion = completion
            let cbs = self.__callbacks
            self.__callbacks = nil
            return (cbs,true)
            
            }, done: { (tuple) -> Void in
                if let callbacks = tuple.cbs {
                    for callback in callbacks {
                        callback(completion)
                    }
                }
                else if !tuple.success {
                    onCompletionError()
                }
            })
    }
    
    
    /**
    will complete the future and cause any registered callback blocks to be executed.
    
    may block the current thread (depending on configured LOCKING_STRATEGY)
    
    type of synchronization used can be configured via FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY

    :param: completion the value to complete the Future with
    
    :returns: true if Future was successfully completed.  Returns false if the Future has already been completed.

    */
    internal func completeAndNotifySync(completion : Completion<T>) -> Bool {
        
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        let tuple = self.synchObject.modifySync { () -> (cbs:[completion_block_type]?,success:Bool) in
            if (self.__completion != nil) {
                return (nil,false)
            }
            self.__completion = completion
            let cbs = self.__callbacks
            self.__callbacks = nil
            return (cbs,true)
            
            }
        
        if let callbacks = tuple.cbs {
            for callback in callbacks {
                callback(completion)
            }
        }
        return tuple.success
    }

    internal func completeWithBlock(completionBlock : () -> Completion<T>) {
        
        self.synchObject.modifyAsync({ () -> (cbs:[completion_block_type]?,completion:Completion<T>?) in
            if let c = self.__completion {
                return (nil,nil)
            }
            self.__completion = completionBlock()
            let cbs = self.__callbacks
            self.__callbacks = nil
            return (cbs,self.__completion)
            
            }, done: { (tuple) -> Void in
                if let callbacks = tuple.cbs {
                    for callback in callbacks {
                        callback(tuple.completion!)
                    }
                }
        })
    }

    
    internal func completeWithBlock(completionBlock : () -> Completion<T>, onCompletionError : completionErrorHandler) {
        
        self.synchObject.modifyAsync({ () -> (cbs:[completion_block_type]?,completion:Completion<T>?) in
            if let c = self.__completion {
                return (nil,nil)
            }
            self.__completion = completionBlock()
            let cbs = self.__callbacks
            self.__callbacks = nil
            return (cbs,self.__completion)
            
            }, done: { (tuple) -> Void in
                if let callbacks = tuple.cbs {
                    for callback in callbacks {
                        callback(tuple.completion!)
                    }
                }
                else if (tuple.completion == nil) {
                    onCompletionError()
                }
        })
    }
    


    /**
    if completion is of type .ContinueWith(f), than this will register an appropriate callback on f to complete this future iff f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.
    
    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
    
    if the Future has already been completed, this function will do nothing.  No error is generated.

    :param: completion the value to complete the Future with

    */
    internal func completeWith(completion : Completion<T>) {
        switch (completion) {
        case let .ContinueWith(f):
            f.onComplete(.Immediate)  { (nextComp) -> Void in
                self.completeWith(nextComp)
                return
            }
        default:
            return self.completeAndNotify(completion)
        }
    }

    /**
    if completion is of type .ContinueWith(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.

    may block the current thread

    :param: completion the value to complete the Future with
    
    :returns: true if Future was successfully completed.  Returns false if the Future has already been completed.
    */
    internal func completeWithSync(completion : Completion<T>) -> Bool {
        switch (completion) {
        case let .ContinueWith(f):
            if (self.isCompleted) {
                return false
            }
            f.onComplete(.Immediate)  { (nextComp) -> Void in
                self.completeWith(nextComp)
            }
            return true
        default:
            return self.completeAndNotifySync(completion)
        }
    }

    /**
    if completion is of type .ContinueWith(f), than this will register an appropriate callback on f to complete this future when f completes.
    
    otherwise it will complete the future and cause any registered callback blocks to be executed.
    
    will execute the block onCompletionError if the Future has already been completed. The onCompletionError block  may execute inside any thread/queue, so care should be taken.

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.

    :param: completion the value to complete the Future with
    
    :param: onCompletionError a block to execute if the Future has already been completed.
    */
    internal func completeWith(completion : Completion<T>, onCompletionError errorBlock: completionErrorHandler) {
        switch (completion) {
        case let .ContinueWith(f):
            self.synchObject.readAsync({ () -> Bool in
                return (self.__completion != nil)
            }, done: { (isCompleted) -> Void in
                if (isCompleted) {
                    errorBlock()
                }
                else {
                    f.onComplete(.Immediate)  { (nextComp) -> Void in
                        self.completeWith(nextComp,onCompletionError: errorBlock)
                        return
                    }
                }
            })
        default:
            return self.completeAndNotify(completion,onCompletionError: errorBlock)
        }
    }
    
    /**
    
    takes a user supplied block (usually from func onComplete()) and creates a Promise and a callback block that will complete the promise.
    
    can add Objective-C Exception handling if FUTUREKIT_GLOBAL_PARMS.WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING is enabled.
    
    :param: forBlock a user supplied block (via onComplete)
    
    :returns: a tuple (promise,callbackblock) a new promise and a completion block that can be added to __callbacks
    
    */
    internal func createPromiseAndCallback<S>(forBlock: ((Completion<T>)-> Completion<S>)) -> (promise : Promise<S> , completionCallback :completion_block_type) {
        
        var promise = Promise<S>()
        
        if (FUTUREKIT_GLOBAL_PARMS.WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING) {
            let completionCallback :completion_block_type  = {(comp) -> Void in
                var blockCompletion : Completion<S>?
                ObjectiveCExceptionHandler.Try({ () -> Void in
                    blockCompletion = forBlock(comp)
                    }, catch: { (exception : NSException!) -> Void in
                        blockCompletion = Completion(exception: exception)
                        return
                })
                promise.complete(blockCompletion!)
            }
            return (promise,completionCallback)
        }
        else {
            let completionCallback : completion_block_type = {(comp) -> Void in
                promise.complete(forBlock(comp))  // we call tryComplete, because it's legal to 'cancel' a Future by calling cancel().
                return
            }
            return (promise,completionCallback)
        }
        
    }

    
    /**
    takes a callback block and determines what to do with it based on the Future's current completion state.

    If the Future has already been completed, than the callback block is executed.

    If the Future is incomplete, it adds the callback block to the futures private var __callbacks

    may execute asynchronously (depending on configured LOCKING_STRATEGY) and may return to the caller before it is finished executing.
   
    :param: callback a callback block to be run if and when the future is complete
   */
    private func runThisCompletionBlockNowOrLater(callback : completion_block_type) {
        
        // lock my object, and either return the current completion value (if it's set)
        // or add the block to the __callbacks if not.
        self.synchObject.modifyAsync({ () -> Completion<T>? in
            
            // we are done!  return the current completion value.
            if let c = self.__completion {
                return c
            }
            else
            {
                // we only allocate an array after getting the first __callbacks.
                // cause we are hyper sensitive about not allocating extra stuff for temporary transient Futures.
                switch self.__callbacks {
                case var .Some(cb):
                    cb.append(callback)
                case .None:
                    self.__callbacks = [callback]
                }
                return nil
            }
        }, done: { (currentCompletionValue) -> Void in
            // if we got a completion value, than we can execute the callback now.
            if let c = currentCompletionValue {
                callback(c)
            }
        })
    }
    
    /**
        EXPERIMENTAL.
        attempts to reset a Future so it can be completed again.
        probably... not a good idea.
    */
    func __reset() {
        return self.synchObject.modify {
            self.__callbacks = nil
            self.__completion = nil
        }
    }
}

extension Future : FutureProtocol {

    /**
        if we try to convert a future from type T to type T, just ignore the request.
    
        the compile should automatically figure out if needs to call convert() or convert<S>()
    */
    public func convert() -> Future<T> {
        return self
    }

    /**
    convert this future of type Future<T> into another future type Future<S>.
    
    :returns: a new Future of type Future<S>
    
    may fail to execute if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
        let t : T
        let s = t as! S
    
    
    example:
    
        let f = Future<Int>(success:5)
        let f2 : Future<Int32> = f.convert()
        assert(f2.result! == Int32(5))
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    the following conversions should always work for any future `f`
    
        let fofany : Future<Any> = f.convert()
        let fofvoid: Future<Void> = f.convert()
    
    */
    public func convert<S>() -> Future<S> {
        return self.map { (result) -> S in
            return result as! S
        }
    }
    
    /**
    convert Future<T> into another type Future<S?>.
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    
    example:
    
    `let f = Future<String>(success:"5")`
    
    `let f2 : Future<[Int]?> = f.convertOptional()`
    
    `assert(f2.result! == nil)`
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    
    :returns: a new Future of type Future<S?>

    */
    public func convertOptional<S>() -> Future<S?> {
        return self.map { (result) -> S? in
            return result as? S
        }
    }
}

// ---------------------------------------------------------------------------------------------------
// Block Handlers
// ---------------------------------------------------------------------------------------------------
extension Future {
    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future in any completion state, with any new value type __Type.
    
    The new future returned from this function will be completed using the completion value returned from this block.

    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block that will execute when this future completes, and returns a new completion value for the new completion type.   The block must return a Completion value (Completion<__Type>).
    :returns: a new Future that returns results of type __Type  (Future<__Type>)
    
    */
    public func onComplete<__Type>(executor : Executor,block:(completion:Completion<T>)-> Completion<__Type>) -> Future<__Type> {
        
        let (promise, completionCallback) = self.createPromiseAndCallback(block)
        
        let block = executor.callbackBlockFor(completionCallback)
        self.runThisCompletionBlockNowOrLater(block)
        
        return promise.future
    }
    
    
    /**
    executes a block using the Executor.Primary if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future in any completion state, with any new value type __Type.
    
    The new future returned from this function will be completed using the completion value returned from this block.
    
    a link_
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    
    :param: block a block that will execute when this future completes, and returns a new completion value for the new completion type.   The block must return a Completion value (Completion<__Type>).
    
    :returns: a new Future that returns results of type __Type  (Future<__Type>)
    */
    public func onComplete<__Type>(block:(completion:Completion<T>)-> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(.Primary, block: block)
    }
    
    
    
    
    
    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a .Success(result).  The value returned from the block will be set as this Future's result.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    :returns: a new Future that returns results of type __Type  (Future<__Type>)
    */
    public func onComplete<__Type>(executor: Executor, _ block:(completion:Completion<T>)-> __Type) -> Future<__Type> {
        return self.onComplete(executor) { (c) -> Completion<__Type> in
            return .Success(block(completion:c))
        }
    }
    /**
    executes a block using the Executor.Primary if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a .Success(result).  The value returned from the block will be set as this Future's result.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    :returns: a new Future that returns results of type __Type  (Future<__Type>)
    */
    public func onComplete<__Type>(block:(completion:Completion<T>)-> __Type) -> Future<__Type> {
        return self.onComplete(.Primary,block)
    }
 
    
    
    
    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed with `.Success'.
    
    :param: executor an Executor to use to execute the block when it is ready to run.
    
    :param: block a block that will execute when this future completes.
    
    :returns: a Future<Void> that completes after this block has executed.
    
    */
    public func onComplete(executor: Executor, block:(completion:Completion<T>)-> Void) -> Future<Void> {
        return self.onComplete(executor) { (c) -> Completion<Void> in
            return .Success(block(completion:c))
        }
    }
    
    
    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed with `.Success'.
    
    :param: executor an Executor to use to execute the block when it is ready to run.
    
    :param: block a block that will execute when this future completes.
    
    :returns: a Future<Void> that completes after this block has executed.
    
    */
    public func onComplete(block:(completion:Completion<T>)-> Void) -> Future<Void> {
        return self.onComplete { (c) -> Completion<Void> in
            return .Success(block(completion:c))
        }
    }
    
    
    public func onComplete<__Type>(executor: Executor, _ block:(completion:Completion<T>)-> Future<__Type>) -> Future<__Type> {
        return self.onComplete(executor, block: { (c) -> Completion<__Type> in
            return .ContinueWith(block(completion:c))
        })
    }
    public func onComplete<__Type>(block:(conpletion:Completion<T>)-> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Primary,block)
    }
    
    
    
    public func waitForComplete<__Type>(timeout: NSTimeInterval,
        executor : Executor,
        didComplete:(Completion<T>)-> Completion<__Type>,
        timedOut:()-> Completion<__Type>
        ) -> Future<__Type> {
            
            let p = Promise<__Type>()
            
            let f = self.onComplete(executor) { (c) -> Void in
                
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


    
    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The new future returned from this function will be completed using the completion value returned from this block.

    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccessWith()`
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onSuccessWith<__Type>(executor : Executor, _ block:(result:T) -> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(executor)  { (completion) -> Completion<__Type> in
            switch completion.state {
            case .Success:
                return block(result: completion.result)
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled(completion.cancelToken)
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Success.  
    
    Unlike, onSuccessWith(), this function ignores the .Success result value. and it isn't sent it to the block.  onAnySuccess implies you don't about the result of the target, just that it completed with a .Success
    
    Currently, in swift 1.2, this is the only way to add a Success handler to a future of type Future<Void>.  But can be used with Future's of all types.
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block that returns the completion value of the returned Future.
    :returns: a new future of type `Future<__Type>`
    */
    public func onAnySuccessWith<__Type>(executor : Executor, _ block:() -> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(executor)  { (completion) -> Completion<__Type> in
            switch completion.state {
            case .Success:
                return block()
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled(completion.cancelToken)
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.  
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onSuccessWith()
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccessWith()`
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: block a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onSuccess<__Type>(block:(result:T)-> Completion<__Type>) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }

    /**
    takes a block and executes it iff the target is completed with a .Success.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.  
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onSuccessWith()

    Unlike, onSuccessWith(), this function ignores the .Success result value. and it isn't sent it to the block.  onAnySuccess implies you don't about the result of the target, just that it completed with a .Success
    
    Currently, in swift 1.2, this is the only way to add a Success handler to a future of type Future<Void>.  But can be used with Future's of all types.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: block a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    :returns: a new future of type `Future<__Type>`
    */
    public func onAnySuccess<__Type>(block:() -> Completion<__Type>) -> Future<__Type> {
        return self.onAnySuccessWith(.Primary,block)
    }
    
    
    /**
    takes a block and executes it iff the target is completed with a .Fail
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.  The new future returned from this function will be completed using the completion value returned from this block.
    
    If the target is completed with a .Success, then the returned future will complete with .Cancelled and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the error returned by the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onFailWith<__Type>(executor : Executor, _ block:(error:NSError)-> Completion<__Type>) -> Future<__Type>
    {
        return self.onComplete(executor) { (completion) -> Completion<__Type> in
            switch completion {
            case let .Fail(e):
                return block(error: e)
            default:
                return .Cancelled("dependent task didn't fail")
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Fail
    
    If the target is completed with a .Fail, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.  
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onFailWith()
    
    If the target is completed with a .Success, then the returned future will complete with .Cancelled and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the error returned by the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onFail<__Type>(block:(error:NSError)-> Completion<__Type>) -> Future<__Type> {
        return self.onFailWith(.Primary,block)
    }

    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.  The new future returned from this function will be completed using the completion value returned from this block.
    
    If the target is completed with a .Success or a .Fail, then the returned future will complete with .Cancelled and this block will not be executed.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onCancelWith<__Type>(executor : Executor, _ block:(Any?)-> Completion<__Type>) -> Future<__Type>
    {
        return self.onComplete(executor) { (completion) -> Completion<__Type> in
            switch completion {
            case let .Cancelled(cancelToken):
                return block(cancelToken)
            default:
                return .Cancelled("dependent task wasn't cancelled")
            }
        }
    }
    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.  
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onFailWith()
    
    If the target is completed with a .Success or a .Fail, then the returned future will complete with .Cancelled and this block will not be executed.
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: block a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    :returns: a new Future of type Future<__Type>
    */
    public func onCancel<__Type>(block:(Any?)-> Completion<__Type>) -> Future<__Type> {
        return self.onCancelWith(.Primary,block)
    }


    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a new Future<__Type> with a completion of .Success(S)
    // ---------------------------------------------------------------------------------------------------
 
    
   

    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  
    
    The new future returned from this function will be completed with `.Success(result)` using the value returned from this block as the result.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccessWith()`
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the .Success result of the target Future and returns a new result.

    :returns: a new Future of type Future<__Type>
    */
    public func onSuccessWith<__Type>(executor : Executor, _ block:(result:T)-> __Type) -> Future<__Type> {
        return self.onSuccessWith(executor) { (s : T) -> Completion<__Type> in
            return .Success(block(result: s))
        }
    }
    
    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.
   
    The block will be executed in using the Executor.Primary (usually configued as .Immediate).  The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onComplete()
   
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccessWith()`
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: executor an Executor to use to execute the block when it is ready to run.
    :param: block a block takes the .Success result of the target Future and returns a new result.
    
    :returns: a new Future of type Future<__Type>
    */
    public func onSuccess<__Type>(block:(result:T)-> __Type) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }
    
    public func onSuccess<__Type>(block:(result:T)-> Void) -> Future<Void> {
        return self.onSuccessWith(.Primary,block)
    }

    
    public func onAnySuccessWith<__Type>(executor : Executor, _ block:()-> __Type) -> Future<__Type> {
        return self.onAnySuccessWith(executor) { () -> Completion<__Type> in
            return .Success(block())
        }
    }
    
    public func onAnySuccess<__Type>(block:()-> __Type) -> Future<__Type> {
        return self.onAnySuccessWith(.Primary,block)
    }
    public func onSuccess<__Type>(@autoclosure(escaping) block:()-> __Type) -> Future<__Type> {
        return self.onAnySuccessWith(.Primary,block)
    }

    // rather use map?  Sure!
    public func mapWith<__Type>(executor : Executor, block:(result:T)-> __Type) -> Future<__Type> {
        return self.onSuccessWith(executor,block)
    }
    public func map<__Type>(block:(result:T) -> __Type) -> Future<__Type> {
        return self.onSuccess(block)
    }

    
    public func onFailWith<__Type>(executor : Executor, _ block:(error:NSError)-> __Type) -> Future<__Type> {
        return self.onFailWith(executor) { (e) -> Completion<__Type> in
            return .Success(block(error:e))
        }
    }
    public func onFail<__Type>(block:(error:NSError)-> __Type) -> Future<__Type> {
        return self.onFailWith(.Primary,block)
    }
    

    
    public func onCancelWith<__Type>(executor : Executor, _ block:(Any?)-> __Type) -> Future<__Type> {
        return self.onCancelWith(executor) { (a) -> Completion<__Type> in
            return .Success(block(a))
        }
    }
    public func onCancel<__Type>(block:(Any?)-> __Type) -> Future<__Type> {
        return self.onCancelWith(.Primary,block)
    }
    
    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a .ContinueWith((Future<__Type>) ------
    // ---------------------------------------------------------------------------------------------------

    

    

    public func onSuccessWith<__Type>(executor : Executor, _ block:(result:T)-> Future<__Type>) -> Future<__Type> {
        return self.onSuccessWith(executor) { (s:T) -> Completion<__Type> in
            return .ContinueWith(block(result:s))
        }
    }
    
    public func onSuccess<__Type>(block:(result:T)-> Future<__Type>) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }

    public func onAnySuccessWith<__Type>(executor : Executor, _ block:()-> Future<__Type>) -> Future<__Type> {
        return self.onAnySuccessWith(executor) { () -> Completion<__Type> in
            return .ContinueWith(block())
        }
    }
    public func onAnySuccess<__Type>(block:()-> Future<__Type>) -> Future<__Type> {
        return self.onAnySuccessWith(.Primary,block)
    }
    
    
    public func onFailWith<__Type>(executor : Executor, _ block:(error:NSError)-> Future<__Type>) -> Future<__Type> {
        return self.onFailWith(executor) { (e) -> Completion<__Type> in
            return .ContinueWith(block(error:e))
        }
    }
    public func onFail<__Type>(block:(error:NSError)-> Future<__Type>) -> Future<__Type> {
        return self.onFailWith(.Primary,block)
    }
    
    
    public func onCancelWith<__Type>(executor : Executor, _ block:(Any?)-> Future<__Type>) -> Future<__Type> {
        return self.onCancelWith(executor) { (a) -> Completion<__Type> in
            return .ContinueWith(block(a))
        }
    }
    public func onCancel<__Type>(block:(Any?)-> Future<__Type>) -> Future<__Type> {
        return self.onCancelWith(.Primary,block)
    }
    
    
    public func waitUntilCompleted() -> Completion<T> {
        let s = FutureWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: true)
    }
    
    public func waitForResult() -> T? {
        return self.waitUntilCompleted().result
    }

    public func _waitUntilCompletedOnMainQueue() -> Completion<T> {
        let s = FutureWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: false)
    }
}

extension Future {
    // ---------------------------------------------------------------------------------------------------
    // Just do this next thing, when this one is done.  NOT READY FOR PRIME TIME.
    // ---------------------------------------------------------------------------------------------------
    
    func continueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            return .ContinueWith(autoclosingFuture())
        }
    }
    
    func OnSuccessContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case let .Success(t):
                return .ContinueWith(autoclosingFuture())
            default:
                return completion.convert()
            }
        }
    }
    func OnFailContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case let .Fail(e):
                return .ContinueWith(autoclosingFuture())
            default:
                return .Cancelled("dependent task didn't fail")
            }
        }
    }
    func OnCancelContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case let .Cancelled:
                return .ContinueWith(autoclosingFuture())
            default:
                return .Cancelled("dependent task wasn't cancelled")
            }
        }
    }
    /**
    **NOTE** identical to `onAnySuccess()`
    
    takes a block and executes it iff the target is completed with a .Success.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onSuccessWith()
    
    Unlike, onSuccessWith(), this function ignores the .Success result value. and it isn't sent it to the block.  onAnySuccess implies you don't about the result of the target, just that it completed with a .Success
    
    Currently, in swift 1.2, this is the only way to add a Success handler to a future of type Future<Void>.  But can be used with Future's of all types.
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    
    :param: __Type the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    :param: block a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    :returns: a new future of type `Future<__Type>`
    */
    
    func then<__Type>(block:(result:T) -> Completion<__Type>) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }
    func then<__Type>(block:(result:T) -> Future<__Type>) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }
    func then<__Type>(block:(result:T) -> __Type) -> Future<__Type> {
        return self.onSuccessWith(.Primary,block)
    }
    func then<__Type>(executor : Executor,_ block:(result:T) -> Completion<__Type>) -> Future<__Type> {
        return self.onSuccessWith(executor,block)
    }
    func then<__Type>(executor : Executor,_ block:(result:T) -> Future<__Type>) -> Future<__Type> {
        return self.onSuccessWith(executor,block)
    }
     func then<__Type>(executor : Executor,_ block:(result:T) -> __Type) -> Future<__Type> {
        return self.onSuccessWith(executor,block)
    }


}

extension Future : Printable, DebugPrintable {
    
    public var description: String {
        return "Future"
    }
    public var debugDescription: String {
        return "Future<\(toString(T.self))> - \(self.__completion)"
    }

    public func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
    
}



protocol GenericOptional {
    typealias unwrappedType
    
    func convert<OptionalS : GenericOptional>() -> OptionalS
    func convertIfPossible<OptionalS : GenericOptional>() -> OptionalS
    
    init()
    init(_ some: unwrappedType)
}


extension Optional : GenericOptional {
    typealias unwrappedType = T
    
    
    func convert<OptionalS : GenericOptional>() -> OptionalS {
        switch self {
        case let .Some(t):
            return OptionalS(t as! OptionalS.unwrappedType)
        case None:
            return OptionalS()
        }
    }
    func convertIfPossible<OptionalS : GenericOptional>() -> OptionalS {
        switch self {
        case let .Some(t):
            if let s = t as? OptionalS.unwrappedType {
                return OptionalS(s)
            }
            else {
                return OptionalS()
            }
        case None:
            return OptionalS()
        }
    }
    
    
}

func convertOptionalFutures<OptionalT : GenericOptional, OptionalS: GenericOptional>(f : Future<OptionalT>) -> Future<OptionalS> {
    return f.map { (result) -> OptionalS in
        let r : OptionalS = result.convertIfPossible()
        return r
    }
}

func convertFutures<OptionalT : GenericOptional, OptionalS: GenericOptional>(f : Future<OptionalT>) -> Future<OptionalS> {
    return f.map { (result) -> OptionalS in
        let r : OptionalS = result.convert()
        return r
    }
}


public func toFutureAnyObject<T : AnyObject>(f : Future<T>) -> Future<AnyObject> {
    return f.convert()
}

public func toFutureAnyObjectOpt<T : AnyObject>(f : Future<T?>) -> Future<AnyObject?> {
    return f.convertOptional()
}


public extension Future {
    
    // will only work if Future<T : AnyObject>
    
    func asFTask() -> FTask {
        let f : FTask.futureType = self.convert()
        return FTask(f)
    }
    
    // if this Future's result type doesnt convert to AnyObject
    // you can use this! (FTask result will be nil)
    
    func asFTaskOptional() -> FTask {
        let f : FTask.futureType = self.convertOptional()
        return FTask(f)
    }
}

private var futureWithNoResult = Future<Void>()

class classWithMethodsThatReturnFutures {
    
    func iReturnAnInt() -> Future<Int> {
        return Future  { () -> Int in
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
        dispatch_main_async {
            p.completeWithSuccess(5)
        }
        
        return p.future
        
    }
    
    func iMayFailRandomly() -> Future<[String:Int]>  {
        let p = Promise<[String:Int]>()
        
        dispatch_main_async {
            let s = arc4random_uniform(3)
            switch s {
            case 0:
                p.completeWithFail(FutureNSError(error: .GenericException, userInfo: nil))
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
                return .Fail(FutureNSError(error: .GenericException, userInfo: nil))
            case 1:
                return .Cancelled(())
            default:
                return .Success(["Hi" : 5])
            }
        }
    }

    func iCopeWithWhatever()  {
        
        
        // ALL 3 OF THESE FUNCTIONS BEHAVE THE SAME
        
        self.iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
            switch completion {
            case let .Success(r):
                let x = r
                NSLog("\(x)")
                return .Success(Void())
            case let .Fail(e):
                return .Fail(e)
            case let .Cancelled(token):
                return .Cancelled(token)
            default:
                assertionFailure("This shouldn't happen!")
                return Completion<Void>(failWithErrorMessage: "something bad happened")
            }
        }
        
        self.iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
            switch completion.state {
            case .Success:
                return .Success(Void())
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled(completion.cancelToken)
            }
        }
        
        
        self.iMayFailRandomly().onAnySuccess { () -> Completion<Int> in
            return .Success(5)
        }
            
        
        self.iMayFailRandomly().onAnySuccess { () -> Void in
            NSLog("")
        }
        
    }
    
    func iDontReturnValues() -> Future<Void> {
        let f = Future(.Primary) { () -> Int in
            return 5
        }
        
        let p = Promise<Void>()
        
        f.onSuccess { (result) -> Void in
            dispatch_main_async {
                p.completeWithSuccess()
            }
        }
        // let's do some async dispatching of things here:
        return p.future
    }
    
    func imGonnaMapAVoidToAnInt() -> Future<Int> {
        

        let f = self.iDontReturnValues().onAnySuccess { () -> Int in
            return 5
        }
            
        
        let g : Future<Int> = f.onSuccess({(fffive : Int) -> Float in
            Float(fffive + 10)
        }).onSuccess { (floatFifteen) ->  Int in
            Int(floatFifteen) + 5
        }
        return g
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
        return f.convert()
    }
    
    
    func testing() {
        let x = Future<Optional<Int>>(success: 5)
        
        let y : Future<Int64?> = convertOptionalFutures(x)
        
        
    }

    
}







