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

// kill this line in Swift 2.0!
public typealias ErrorType = NSError

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
    public static let REMOVE_THREAD_SYNCHRONIZATION_WHEN_FUTURE_IS_COMPLETE = true
    
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
    
    public override var localizedDescription: String {
        if let g = self.genericError {
            return "\(g) \(super.localizedDescription)"
        }
        else {
            return super.localizedDescription
        }
    }

    public var genericError : String? {
        get {
            return self.userInfo?["genericError"] as? String
        }
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
    // this doesn't include CompleteUsing intentionally!
    // Tasks must complete in one these states
}


/**
    Result<T> is a swift-generic "hack" to get around the "error: unimplemented IR generation feature non-fixed multi-payload enum layout" limitation
        that still exists (as of Swift 1.2).  Re:(http://stackoverflow.com/questions/27257522/whats-the-exact-limitation-on-generic-associated-values-in-swift-enums)

    This makes instanciating the `Completion<T>.Success()` a pain.  Cause now you have to do this:

        Completion<T>.Success(Result(t))

    or

        Completion<T>(success:t)

    The easiest thing is to use the Global generic function `SUCCESS<T>(t)`

        SUCCESS(t)

    They are all equivilant to the right value.
    We expect to be able to kill Request<T> in a future version of swift.  So the best case is to use just `SUCCESS<T>` (which will always work)

*/
final public class Result<T> {
    public let result: T
    public init(_ r: T) { self.result = r }
}

/**
Defines a an enumeration that stores both the state and the data associated with a Future completion.

- Success(Any): The Future completed Succesfully with a Result

- Fail(ErrorType): The Future has failed with an ErrorType.

- Cancelled(Any?):  The Future was cancelled. The cancellation can optionally include a token.

- CompleteUsing(Future<T>):  This Future will be completed with the result of a "sub" Future. Only used by block handlers.
*/
public enum Completion<T> : Printable, DebugPrintable {
    /**
        An alias that defines the Type being used for .Success(SuccessType) enumeration.
        This is currently set to Any, but we may change to 'T' in a future version of swift
    */
    // public typealias SuccessType = Any         // Works.  Makes me sad.
    // typealias SuccessPayloadType = T             // PERFECT! - But it CRASHES
    // typealias SuccessPayloadType = T!            // OK.  But it STILL Crashes
    public typealias SuccessType = Result<T>        // Works.  And seems to be the most typesafe, and let's use get away with 
                                                    // Optional Futures better (like `Future<AnyObject?>` ) 
    



    /**
        Future completed with a result of SuccessType
    */
    case Success(SuccessType)       //  why is this Success(Result<T>) and not Success(T)
                                    //  or Success(T!)??
                                    //  Because of the evil IR Generation Swift crashiness.
                                    //  In a future version I expect to be able to change this to T or T!
                                    //  so we are using the SuccessType alias
                                            //  We are adding a assertion check inside of
    /**
        Future failed with error ErrorType
    */
    case Fail(ErrorType)
    
    /**
        Future was Cancelled.
    */
    case Cancelled

    /**
        This Future's completion will be set by some other Future<T>.  This will only be used as a return value from the onComplete/onSuccess/onFail/onCancel handlers.  the var "completion" on Future should never be set to 'CompleteUsing'.
    */
    case CompleteUsing(Future<T>)
    
    
    
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
    
    public init(success s:T) {
        self = .Success(SuccessType(s))
    }
    
    public var isSuccess : Bool {
        get {
            switch self {
            case .Success:
                return true
            default:
                return false
            }
        }
    }
    public var isFail : Bool {
        get {
            switch self {
            case .Fail:
                return true
            default:
                return false
            }
        }
    }
    public var isCancelled : Bool {
        get {
            switch self {
            case .Cancelled:
                return true
            default:
                return false
            }
        }
    }
    public var isCompleteUsing : Bool {
        get {
            switch self {
            case .CompleteUsing:
                return true
            default:
                return false
            }
        }
    }

    /**
        get the Completion state for a completed state. It's easier to create a switch statement on a completion.state, rather than the completion itself (since a completion block will never be sent a .CompleteUsing).
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
            case .CompleteUsing:
                assertionFailure("CompleteUsing(f) don't have a completion state!")
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
                return t.result
            default:
//                assertionFailure("don't call result without checking that the enumeration is .Error first.")
                return nil
            }
        }
    }
    
    /**
        make sure this enum is a .Fail before calling `result`. Use a switch or check .isError() first.
    */
    public var error : ErrorType! {
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

    internal var completeUsingFuture:Future<T>! {
        get {
            switch self {
            case let .CompleteUsing(f):
                return f
            default:
                return nil
            }
        }
    }

    public func As() -> Completion<T> {
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
    
        `let c2 : Complete<Int32> =  c.As()`
    
        `assert(c2.result == Int32(5))`
    
        you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func As<S>() -> Completion<S> {
        switch self {
        case let .Success(t):
            let r = t.result as! S
            return SUCCESS(r)
        case let .Fail(f):
            return FAIL(f)
        case let .Cancelled(reason):
            return CANCELLED(reason)
        case let .CompleteUsing(f):
            let s : Future<S> = f.As()
            return COMPLETE_USING(s)
        }
    }
    
    /**
    convert this completion of type `Completion<T>` into another type `Completion<S?>`.
    
    WARNING: if `T as! S` isn't legal, than all Success values may be converted to nil
    - example:
    
        let c : Complete<String> = .Success("5")
        let c2 : Complete<[Int]?> =  c.convertOptional()
        assert(c2.result == nil)
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    
    - returns: a new completionValue of type Completion<S?>

    */
    public func convertOptional<S>() -> Completion<S?> {
        switch self {
        case let .Success(t):
            let r = t.result as? S
            return SUCCESS(r)
        case let .Fail(f):
            return FAIL(f)
        case .Cancelled:
            return CANCELLED()
        case let .CompleteUsing(f):
            let s : Future<S?> = f.convertOptional()
            return COMPLETE_USING(s)
        }
    }
    
    public var description: String {
        switch self {
        case let .Success(t):
            return ".Success(\(t.result))"
        case let .Fail(f):
            return ".Fail(\(f))"
        case let .Cancelled(reason):
            return ".Cancelled(\(reason))"
        case let .CompleteUsing(f):
            return ".CompleteUsing(\(f.description))"
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
            self.handler = { (forcedRequest) in
                oldhandler(force: forcedRequest)
                h(force: forcedRequest)
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

    internal func getNewTokenNoSynchronization(synchObject : SynchronizationProtocol) -> CancellationToken? {
        
        if !self.canBeCancelled {
            return nil
        }
        let token = self._createNewToken(synchObject)
        self.tokens.append(CancellationTokenPtr(token))
        return token
    }

    internal func getNewToken(synchObject : SynchronizationProtocol) -> CancellationToken? {
        
        if !self.canBeCancelled {
            return nil
        }
        let token = self._createNewToken(synchObject)
        synchObject.lockAndModify { () -> Void in
            if self.canBeCancelled {
                self.tokens.append(CancellationTokenPtr(token))
            }
        }
        return token
    }

    
    private func _createNewToken(synchObject : SynchronizationProtocol) -> CancellationToken {
        
        return CancellationToken(
            
            onCancel: { [weak self] (forced, token) -> Void in
                    self?._cancelRequested(token, forced, synchObject)
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
    

    private func _performCancel(forced : Bool) {
        if !self.canBeCancelled {
            return
        }
        if (forced) {
            self.tokens.removeAll()
        }
        // there are no active tokens remaining, so allow the cancellation
        if (self.tokens.count == 0) {
            self.handler?(force: forced)
            self.canBeCancelled = false
            self.handler = nil
        }
        else {
            self.pendingCancelRequestActive = true
        }
        
    }
    
    private func _cancelRequested(cancelingToken:CancellationToken, _ forced : Bool,_ synchObject : SynchronizationProtocol) {
        
        synchObject.lockAndModify { () -> Void in

            assert({
                
                let cancelingTokenCount = self.tokens.filter { (tokenPtr) -> Bool in
                    if let token = tokenPtr.value {
                        return (token === cancelingToken)
                    }
                    return false
                    }.count
                
                return (cancelingTokenCount == 1)}()
                
                , "can't find the request token in our list of active tokens!")
            
            self._removeToken(cancelingToken)
            self._performCancel(forced)

        }
        
    }
    
    private func _clearInitializedToken(token:CancellationToken,_ synchObject : SynchronizationProtocol) {
        
        synchObject.lockAndModifySync { () -> Void in
            self._removeToken(token)
            
            if (self.pendingCancelRequestActive && self.tokens.count == 0) {
                self.canBeCancelled = false
                self.handler?(force: false)
            }
        }
    }


    
    
}

internal typealias CancellationHandler = ((force:Bool) -> Void)


public class CancellationToken {
    typealias OnCancelHandler = ((forced:Bool,token:CancellationToken) -> Void)
    typealias OnDenitHandler = ((token:CancellationToken) -> Void)
    
    
    private var onCancel : OnCancelHandler?
    private var onDeinit : OnDenitHandler
    
    internal init(onCancel c:OnCancelHandler, onDeinit d: OnDenitHandler) {
        self.onCancel = c
        self.onDeinit = d
    }
    
    final func cancel(forced : Bool = false) {
        self.onCancel?(forced:forced,token:self)
        self.onCancel = nil
    }
    
    deinit {
        self.onDeinit(token: self)
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
    func As<S>() -> Future<S>

    /**
    convert Future<T> into another type Future<S?>.
    
    WARNING: if 'T as! S' isn't legal, than all Success values may be converted to nil
    
    example:
        let f = Future<String>(success:"5")
        let f2 : Future<[Int]?> = f.convertOptional()
        assert(f2.result! == nil)
    
    you will need to formally declare the type of the new variable (ex: `f2`), in order for Swift to perform the correct conversion.
    */
    func convertOptional<S>() -> Future<S?>
    
    
    var description: String { get }
    
}



public func SUCCESS<T>(result : T) -> Completion<T> {
    return .Success(Result(result))
}
public func FAIL<T>(error : ErrorType) -> Completion<T> {
    return .Fail(error)
}
public func FAIL<T>(message : String) -> Completion<T> {
    return Completion<T>(failWithErrorMessage: message)
}
public func CANCELLED<T>() -> Completion<T> {
    return .Cancelled
}
public func COMPLETE_USING<T>(f : Future<T>) -> Completion<T> {
    return .CompleteUsing(f)
}


/**

    `Future<T>`

    A Future is a swift generic class that let's you represent an object that will be returned at somepoint in the future.  Usually from some asynchronous operation that may be running in a different thread/dispatch_queue or represent data that must be retrieved from a remote server somewhere.


*/
public class Future<T> : FutureProtocol{
    
    public typealias ReturnType = T
    
    internal typealias CompletionErrorHandler = Promise<T>.CompletionErrorHandler
    internal typealias completion_block_type = ((Completion<T>) -> Void)
    internal typealias cancellation_handler_type = (()-> Void)
    
    
    private final var __callbacks : [completion_block_type]?

    /**
        this is used as the internal storage for `var completion`
        it is not thread-safe to read this directly. use `var synchObject`
    */
    private final var __completion : Completion<T>? {
        didSet(c) {
            if (c != nil) {
            }
        }
    }
    
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
    private var cancellationSource = CancellationTokenSource()

    
    internal func addRequestHandler(h : CancellationHandler) {
        
        self.synchObject.lockAndModify { () -> Void in
            self.cancellationSource.addHandler(h)
        }
    }

    
    /**
        returns: the current completion value of the Future
    
        accessing this variable directly requires thread synchronization.
    
        It is more efficient to examine completion values that are sent to an onComplete/onSuccess handler of a future than to examine it directly here.
    
        type of synchronization used can be configured via GLOBAL_PARMS.LOCKING_STRATEGY
    
    */
    public final var completion : Completion<T>? {
        get {
            return self.synchObject.lockAndReadSync { () -> Completion<T>? in
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
    public var error : ErrorType? {
        get {
            return self.completion?.error
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
    
    accessing this variable directly requires thread synchronization.
    */
    public final var isCompleted : Bool {
        return self.synchObject.lockAndReadSync { () -> Bool in
            return (self.__completion != nil)
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
    public init(completed:Completion<T>) {  // returns an completed Task
        self.__completion = completed
        self.synchObject = UnsafeSynchronization()
    }
    /**
        creates a completed Future with a completion == .Success(success)
    */
    public init(success:T) {  // returns an completed Task  with result T
        self.__completion = SUCCESS(success)
        self.synchObject = UnsafeSynchronization()
    }
    /**
    creates a completed Future with a completion == .Error(failed)
    */
    public init(failed:ErrorType) {  // returns an completed Task that has Failed with this error
        self.__completion = .Fail(failed)
        self.synchObject = UnsafeSynchronization()
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(failWithErrorMessage))
    */
    public init(failWithErrorMessage errorMessage: String) {
        self.__completion = Completion<T>(failWithErrorMessage:errorMessage)
        self.synchObject = UnsafeSynchronization()
    }
    /**
    creates a completed Future with a completion == .Error(FutureNSError(exception))
    */
    public init(exception:NSException) {  // returns an completed Task that has Failed with this error
        self.__completion = Completion<T>(exception:exception)
        self.synchObject = UnsafeSynchronization()
    }
    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(cancelled:()) {  // returns an completed Task that has Failed with this error
        self.__completion = .Cancelled
        self.synchObject = UnsafeSynchronization()
    }

    /**
    creates a completed Future with a completion == .Cancelled(cancelled)
    */
    public init(future f:Future<T>) {  // returns an completed Task that has Failed with this error
        self.completeWith(.CompleteUsing(f))
    }

    public convenience init(delay:NSTimeInterval, completeWith: Completion<T>) {
        
        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        Executor.Default.executeAfterDelay(delay) { () -> Void in
            p.complete(completeWith)
        }
        self.init(future:p.future)
    }
    
    public convenience init(afterDelay:NSTimeInterval, completeWith: Completion<T>) {    // emits a .Success after delay
        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        Executor.Default.executeAfterDelay(afterDelay) {
            p.complete(completeWith)
        }
        self.init(future:p.future)
    }
    
    public convenience init(afterDelay:NSTimeInterval, success:T) {    // emits a .Success after delay
        let p = Promise<T>()
        p.automaticallyCancelOnRequestCancel()
        Executor.Default.executeAfterDelay(afterDelay) {
            p.completeWithSuccess(success)
        }
        self.init(future:p.future)
    }
    
    /**
    creates a completed Future with a completion == completion
    */
    public init(@autoclosure completion c:() -> Completion<T>) {
        self.__completion = c()
        self.synchObject = UnsafeSynchronization()
    }

    /**
    creates a completed Future with a completion == Success(block)
    */
    public init(@autoclosure success s:() -> T) {
        self.__completion = SUCCESS(s())
        self.synchObject = UnsafeSynchronization()
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = .Success(block())
    
    can only be used to a create a Future that should always succeed.
    */
    public init(_ executor : Executor, block: () -> T) {
        let block = executor.callbackBlockFor { () -> Void in
            self.completeWith(SUCCESS(block()))
        }
        block()
    }
    
    /**
    Creates a future by executes block inside of an Executor, and when it's complete, sets the completion = block()
    
    can be used to create a Future that may succeed or fail.  
    
    the block can return a value of .CompleteUsing(Future<T>) if it wants this Future to complete with the results of another future.
    */
    public init(_ executor : Executor, block: () -> Completion<T>) {
        let block = executor.callbackBlockFor { () -> Void in
            self.completeWith(block())
        }
        block()
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
            completionBlock : () -> Completion<T>,
            onCompletionError : (() -> Void)? = nil) {
        
        typealias ModifyBlockReturnType = (callbacks:[completion_block_type]?,
                                            completion:Completion<T>?,
                                            continueUsing:Future?)
        
        
        self.synchObject.lockAndModify(waitUntilDone: wait, modifyBlock: { () -> ModifyBlockReturnType in
            if let _ = self.__completion {
                // future was already complete!
                return ModifyBlockReturnType(nil,nil,nil)
            }
            let c = completionBlock()
            if (c.isCompleteUsing) {
                return ModifyBlockReturnType(callbacks:nil,completion:c,continueUsing:c.completeUsingFuture)
            }
            else {
                let callbacks = self.__callbacks
                self.__callbacks = nil
                self.cancellationSource.clear()
                self.__completion = c
                if (GLOBAL_PARMS.REMOVE_THREAD_SYNCHRONIZATION_WHEN_FUTURE_IS_COMPLETE) {
                    // let's execute OSMemoryBarrier() prior to changing the syncObject
                    // https://www.mikeash.com/pyblog/friday-qa-2009-07-10-type-specifiers-in-c-part-3.html
                    // This makes sure all the 'clear' values on the object are set correctly, before removing the
                    // synchronization object's protection
                    OSMemoryBarrier()
                    self.synchObject = UnsafeSynchronization()
                }
                return ModifyBlockReturnType(callbacks,self.__completion,nil)
            }
        }, then:{ (modifyBlockReturned:ModifyBlockReturnType) -> Void in
            if let callbacks = modifyBlockReturned.callbacks {
                for callback in callbacks {
                    callback(modifyBlockReturned.completion!)
                }
            }
            if let f = modifyBlockReturned.continueUsing {
                f.onComplete(.Immediate)  { (nextComp) -> Void in
                    self.completeWith(nextComp)
                }
                if let token = f.getCancelToken() {
                    self.addRequestHandler { (forced) in
                        token.cancel(forced:forced)
                    }
                }
            }
            else if (modifyBlockReturned.completion == nil) {
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
    internal final func createPromiseAndCallback<S>(forBlock: ((Completion<T>)-> Completion<S>)) -> (promise : Promise<S> , completionCallback :completion_block_type) {
        
        let promise = Promise<S>()

        let completionCallback : completion_block_type = {(comp) -> Void in
            promise.complete(forBlock(comp))  // we call tryComplete, because it's legal to 'cancel' a Future by calling cancel().
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
        self.synchObject.lockAndModifyAsync({ () -> Completion<T>? in
            
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
                    self.__callbacks = cb
                case .None:
                    self.__callbacks = [callback]
                }
                if let t = self.cancellationSource.getNewTokenNoSynchronization(self.synchObject) {
                    promise.onRequestCancel(.Immediate) { (force) -> CancelRequestResponse in
                        t.cancel(forced: force)
                        return .DoNothing
                    }
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
    public final func As<__Type>() -> Future<__Type> {
        return self.onSuccess(.Immediate) { (result) -> Completion<__Type> in
            let r = result as! __Type
            return SUCCESS(r)
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
    public final func convertOptional<__Type>() -> Future<__Type?> {
        return self.onSuccess(.Immediate) { (result) -> Completion<__Type?> in
            let r = result as? __Type
            return SUCCESS(r)
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
    public final func onComplete<__Type>(executor : Executor,block:(completion:Completion<T>)-> Completion<__Type>) -> Future<__Type> {
        
        let (promise, completionCallback) = self.createPromiseAndCallback(block)
        let block = executor.callbackBlockFor(completionCallback)
        
        self.runThisCompletionBlockNowOrLater(block,promise: promise)
        
        return promise.future
    }
    
    
    /**
    executes a block using the Executor.Primary if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future in any completion state, with the user defined type __Type.
    
    The `completion` argument will be set to the Completion<T> value that completed the target.  It will be one of 3 values (.Success, .Fail, or .Cancelled).
    
    The block must return one of four enumeration values (.Success/.Fail/.Cancelled/.CompleteUsing).
    
    Returning a future `f` using .CompleteUsing(f) causes the future returned from this method to be completed when `f` completes. (Leaving the Future in an incomplete state, until 'f' completes).
    
    The new future returned from this function will be completed using the completion value returned from this block.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, and returns a new completion value for the new completion type.   The block must return a Completion value (Completion<__Type>).
    - returns: a new Future that returns results of type __Type  (Future<__Type>)
    
    */
    public final func onComplete<__Type>(block:(completion:Completion<T>)-> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(.Primary, block: block)
    }
    
    
    /**
    executes a block using the supplied Executor if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type __Type
    */
    public final func onComplete<__Type>(executor: Executor, block:(completion:Completion<T>)-> __Type) -> Future<__Type> {
        return self.onComplete(executor) { (c) -> Completion<__Type> in
            return SUCCESS(block(completion:c))
        }
    }
    /**
    executes a block using the Executor.Primary if and when the target future is completed.  Will execute immediately if the target is already completed.
    
    This method will let you examine the completion state of target, and return a new future that completes with a `.Success(result)`.  The value returned from the block will be set as this Future's result.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that will execute when this future completes, a `.Success(result)` using the return value of the block.
    - returns: a new Future that returns results of type __Type
    */
    public final func onComplete<__Type>(block:(completion:Completion<T>)-> __Type) -> Future<__Type> {
        return self.onComplete(.Primary,block: block)
    }
 
    
    
    
/*    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed with `.Success'.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter block: a block that will execute when this future completes.
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
    public final func onComplete(executor: Executor, block:(completion:Completion<T>)-> Void) -> Future<Void> {
        return self.onComplete(executor) { (c) -> Completion<Void> in
            return SUCCESS(block(completion:c))
        }
    } */
    
    
    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed with `.Success'.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter block: a block that will execute when this future completes.
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
/*    public final func onComplete(block:(completion:Completion<T>)-> Void) -> Future<Void> {
        return self.onComplete { (c) -> Completion<Void> in
            return SUCCESS(block(completion:c))
        }
    } */
    
    
    /**
    takes a block and executes it if and when this future is completed.  The block will be executed using supplied Executor.
    
    The new future returned from this function will be completed when the future returned from the block is completed.  
    
    This is the same as returning Completion<T>.CompleteUsing(f)
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    
    - parameter block: a block that will execute when this future completes, and return a new Future.
    
    - returns: a `Future<Void>` that completes after this block has executed.
    
    */
    public final func onComplete<__Type>(executor: Executor, block:(completion:Completion<T>)-> Future<__Type>) -> Future<__Type> {
        return self.onComplete(executor, block: { (c) -> Completion<__Type> in
            return .CompleteUsing(block(completion:c))
        })
    }
    public final func onComplete<__Type>(block:(conpletion:Completion<T>)-> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Primary,block: block)
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
        didComplete:(Completion<T>)-> Completion<__Type>,
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
    public final func onSuccess<__Type>(executor : Executor, block:(result:T) -> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(executor)  { (completion) -> Completion<__Type> in
            switch completion.state {
            case .Success:
                return block(result: completion.result)
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Success.  
    
    Currently, in swift 1.2, this is the only way to add a Success handler to a future of type Future<Void>.  But can be used with Future's of all types.  All results are converted to Any in your code.

    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  The future returned from this function will be completed using the value returned from this block.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block that returns the completion value of the returned Future.
    - returns: a new future of type `Future<__Type>`
    */
    public final func onAnySuccess<__Type>(executor : Executor, block:(result:Any) -> Completion<__Type>) -> Future<__Type> {
        return self.onComplete(executor)  { (completion) -> Completion<__Type> in
            switch completion.state {
            case .Success:
                return block(result: completion.result)
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.  
    
    The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onSuccess()
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter block: a block takes the .Success result of the target Future and returns the completion value of the returned Future.
    - returns: a new Future of type Future<__Type>
    */
    public final func onSuccess<__Type>(block:(result:T)-> Completion<__Type>) -> Future<__Type> {
        return self.onSuccess(.Primary,block: block)
    }

    /**
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
    public final func onAnySuccess<__Type>(block:(result:Any) -> Completion<__Type>) -> Future<__Type> {
        return self.onAnySuccess(.Primary,block: block)
    }
    
    
    /**
    takes a block and executes it iff the target is completed with a .Fail
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.  
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.
    */
    public final func onFail(executor : Executor, block:(error:ErrorType)-> Void)
    {
        self.onComplete(executor) { (completion) -> Void in
            if (completion.isFail) {
                block(error: completion.error)
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Fail
    
    If the target is completed with a .Fail, then the block will be executed using Executor.Primary.
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.
    */
    public func onFail(block:(error:ErrorType)-> Void)
    {
        self.onComplete(.Primary) { (completion) -> Void in
            if (completion.isFail) {
                block(error: completion.error)
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using the supplied Executor.  
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    */
    public final func onCancel(executor : Executor, block:()-> Void)
    {
        self.onComplete(executor) { (completion) -> Void in
            if (completion.isCancelled) {
                block()
            }
        }
    }

    /**
    takes a block and executes it iff the target is completed with a .Cancelled
    
    If the target is completed with a .Cancelled, then the block will be executed using Executor.Primary
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the canceltoken returned by the target Future and returns the completion value of the returned Future.
    */
    public final func onCancel(block:()-> Void)
    {
        self.onComplete(.Primary) { (completion) -> Void in
            if (completion.isCancelled) {
                block()
            }
        }
    }
   
    /*:
    takes a block and executes it iff the target is completed with a .Fail or .Cancel
    
    If the target is completed with a .Fail, then the block will be executed using the supplied Executor.
    If the target is completed with a .Cancel, then the block will be executed using the supplied Executor.
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.  error will be nil when the Future was canceled
    */
    public final func onFailorCancel(executor : Executor, block:(error:ErrorType?)-> Void)
    {
        self.onComplete(executor) { (completion) -> Void in
            if (completion.isFail) {
                block(error: completion.error)
            }
            else if (completion.isCancelled) {
                block(error:nil)
            }
        }
    }
    
    /*:
    takes a block and executes it iff the target is completed with a .Fail or .Cancel
    
    If the target is completed with a .Fail, then the block will be executed using Executor.Primary.
    If the target is completed with a .Cancel, then the block will be executed using Executor.Primary.
    
    This method does **not** return a new Future.  If you need a new future, than use `onComplete()` instead.
    
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block can process the error of a future.  error will be nil when the Future was canceled
    */
    public final func onFailorCancel(block:(error:ErrorType?)-> Void)
    {
        self.onFailorCancel(.Primary, block: block)
    }

    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the supplied Executor.  
    
    The new future returned from this function will be completed with `.Success(result)` using the value returned from this block as the result.
    
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns a new result.

    - returns: a new Future of type Future<__Type>
    */
    public final func onSuccess<__Type>(executor : Executor, block:(result:T)-> __Type) -> Future<__Type> {
        return self.onSuccess(executor) { (s : T) -> Completion<__Type> in
            return SUCCESS(block(result: s))
        }
    }
    
    /**
    takes a block and executes it iff the target is completed with a .Success
    
    If the target is completed with a .Success, then the block will be executed using the Executor.Primary.  The new future returned from this function will be completed using the completion value returned from this block.
   
    The block will be executed in using the Executor.Primary (usually configued as .Immediate).  The block may end up running inside ANY other thread or queue.  If the block must run in a specific context, use onComplete()
   
    If the target is completed with a .Fail, then the returned future will also complete with .Fail and this block will not be executed.
    
    If the target is completed with a .Cancelled, then the returned future will also complete with .Cancelled and this block will not be executed.
    
    *Warning* - as of swift 1.2, you can't use this method with a Future<Void> (it will give a compiler error).  Instead use `onAnySuccess()`
    
    - parameter __Type: the type of the new Future that will be returned.  When using XCode auto-complete, you will need to modify this into the swift Type you wish to return.
    - parameter executor: an Executor to use to execute the block when it is ready to run.
    - parameter block: a block takes the .Success result of the target Future and returns a new result.
    
    - returns: a new Future of type Future<__Type>
    */
    public final func onSuccess<__Type>(block:(result:T)-> __Type) -> Future<__Type> {
        return self.onSuccess(.Primary,block:block)
    }
    
//    public final func onSuccess(block:(result:T)-> Void) -> Future<Void> {
//        return self.onSuccess(.Primary,block:block)
//    }

    
    public final func onAnySuccess<__Type>(executor : Executor, block:(result:Any)-> __Type) -> Future<__Type> {
        return self.onAnySuccess(executor) { (result) -> Completion<__Type> in
            return SUCCESS(block(result: result))
        }
    }
    
    public final func onAnySuccess<__Type>(block:(result:Any)-> __Type) -> Future<__Type> {
        return self.onAnySuccess(.Primary,block: block)
    }
//    public final func onSuccess<__Type>(@autoclosure(escaping) block:()-> __Type) -> Future<__Type> {
//        return self.onAnySuccess(.Primary,block)
//    }

    // rather use map?  Sure!
    public final func map<__Type>(executor : Executor, block:(T)-> __Type) -> Future<__Type> {
        return self.onSuccess(executor,block:block)
    }
    
    // rather use map?  Sure!
    // This version of map ALWAYS uses .Immediate, instead of Executor.Primary.
    public final func map<__Type>(block:(T) -> __Type) -> Future<__Type> {
        return self.onSuccess(.Immediate,block:block)
    }

    
    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a .CompleteUsing((Future<__Type>) ------
    // ---------------------------------------------------------------------------------------------------

    public final func onSuccess<__Type>(executor : Executor, block:(result:T)-> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(executor) { (s:T) -> Completion<__Type> in
            return .CompleteUsing(block(result: s))
        }
    }
    
    public final func onSuccess<__Type>(block:(result:T)-> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(.Primary,block: block)
    }

    public final func onAnySuccess<__Type>(executor : Executor, block:(result:Any)-> Future<__Type>) -> Future<__Type> {
        return self.onAnySuccess(executor) { (result) -> Completion<__Type> in
            return .CompleteUsing(block(result: result))
        }
    }
    public final func onAnySuccess<__Type>(block:(result:Any)-> Future<__Type>) -> Future<__Type> {
        return self.onAnySuccess(.Primary,block: block)
    }
    
    
    
    /**
    */
    public final func getCancelToken() -> CancellationToken? {
        return self.cancellationSource.getNewToken(self.synchObject)
    }
    
    
    public final func waitUntilCompleted() -> Completion<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: true)
    }
    
    public final func waitForResult() -> T? {
        return self.waitUntilCompleted().result
    }

    public final func _waitUntilCompletedOnMainQueue() -> Completion<T> {
        let s = SyncWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted(doMainQWarning: false)
    }
}

extension Future {
    // ---------------------------------------------------------------------------------------------------
    // Just do this next thing, when this one is done.  NOT READY FOR PRIME TIME.
    // 
    // ---------------------------------------------------------------------------------------------------
    
    func _continueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            return .CompleteUsing(autoclosingFuture())
        }
    }
    
    func _OnSuccessContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case .Success:
                return .CompleteUsing(autoclosingFuture())
            default:
                return completion.As()
            }
        }
    }
    func _OnFailContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case .Fail:
                return .CompleteUsing(autoclosingFuture())
            default:
                return .Cancelled
            }
        }
    }
    func _OnCancelContinueWith<__Type>(@autoclosure(escaping) autoclosingFuture:() -> Future<__Type>) -> Future<__Type> {
        return self.onComplete(.Immediate)  { (completion) -> Completion<__Type> in
            switch completion {
            case .Cancelled:
                return .CompleteUsing(autoclosingFuture())
            default:
                return .Cancelled
            }
        }
    }
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
    
    func then<__Type>(block:(T) -> Completion<__Type>) -> Future<__Type> {
        return self.onSuccess(.Primary,block: block)
    }
    func then<__Type>(block:(T) -> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(.Primary,block: block)
    }
    func then<__Type>(block:(T) -> __Type) -> Future<__Type> {
        return self.onSuccess(.Primary,block: block)
    }
    func then<__Type>(executor : Executor, block:(T) -> Completion<__Type>) -> Future<__Type> {
        return self.onSuccess(executor,block: block)
    }
    func then<__Type>(executor : Executor, block:(T) -> Future<__Type>) -> Future<__Type> {
        return self.onSuccess(executor,block: block)
    }
     func then<__Type>(executor : Executor, block:(T) -> __Type) -> Future<__Type> {
        return self.onSuccess(executor,block: block)
    }


}

extension Future : Printable, DebugPrintable {
    
    public var description: String {
        return self.debugDescription
    }
    public var debugDescription: String {
        let des = self.__completion?.description ?? "unfinished"
        return "Future_\(toString(T.self))_\(des)"
    }

    public func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
    
}

internal enum GenericOptionalEnum {
    case None
    case Some
}

internal protocol GenericOptional {
    typealias unwrappedType
    
    var genericOptionalEnumValue : GenericOptionalEnum { get }
    
    func isNil() -> Bool
    func unwrap() -> unwrappedType

    func genericFlatMap<U>(f: (unwrappedType) -> U?) -> U?
    func genericMap<U>(f: (unwrappedType) -> U) -> U?

    init()
    init(_ some: unwrappedType)
}


extension Optional : GenericOptional {
    typealias unwrappedType = T
    
    
    var genericOptionalEnumValue : GenericOptionalEnum {
        get {
            switch self {
            case .None:
                return .None
            case .Some:
                return .Some
            }
        }
    }

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

    func genericMap<U>(f: (unwrappedType) -> U) -> U? {
        return self.map(f)
    }

    func genericFlatMap<U>(f: (unwrappedType) -> U?) -> U? {
        return flatMap(f)
    }
    
}

func convertOptionalFutures<OptionalT : GenericOptional, OptionalS: GenericOptional>(f : Future<OptionalT>) -> Future<OptionalS.unwrappedType?> {
    return f.map { (result) -> OptionalS.unwrappedType? in
        
        if (result.isNil()) {
            return nil
        }
        return result.unwrap() as? OptionalS.unwrappedType
    }
}

func convertFutures<OptionalT : GenericOptional, OptionalS: GenericOptional>(f : Future<OptionalT>) -> Future<OptionalS.unwrappedType?> {
    return f.map { (result) -> OptionalS.unwrappedType? in
        return result.genericFlatMap({ (t) -> OptionalS.unwrappedType? in
            return t as? OptionalS.unwrappedType
        })
    }
}


func toFutureAnyObject<T : AnyObject>(f : Future<T>) -> Future<AnyObject> {
    return f.As()
}

func toFutureAnyObjectOpt<T : AnyObject>(f : Future<T?>) -> Future<AnyObject?> {
    return f.convertOptional()
}


public extension Future {
    
    // will only work if Future<T : AnyObject>
    
    func asFTask() -> FTask {
        let f : FTask.futureType = self.As()
        return FTask(f)
    }
    
    // if this Future's result type doesnt convert to AnyObject
    // you can use this! (FTask result will be nil)
    
    func asFTaskOptional() -> FTask {
        let f : FTask.futureType = self.convertOptional()
        return FTask(f)
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
                return .Cancelled
            default:
                return SUCCESS(["Hi" : 5])
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
                return SUCCESS()
            case let .Fail(e):
                return .Fail(e)
            case  .Cancelled:
                return .Cancelled
            default:
                assertionFailure("This shouldn't happen!")
                return Completion<Void>(failWithErrorMessage: "something bad happened")
            }
        }
        
        self.iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
            switch completion.state {
            case .Success:
                return SUCCESS()
            case .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled
            }
        }
        
        
        self.iMayFailRandomly().onAnySuccess { (result) -> Completion<Int> in
            return SUCCESS(5)
        }
            
        
        self.iMayFailRandomly().onAnySuccess { (result) -> Void in
            NSLog("")
        }
        
    }
    
    func iDontReturnValues() -> Future<Any> {
        let f = Future(.Primary) { () -> Int in
            return 5
        }
        
        let p = Promise<Any>()
        
        f.onSuccess { (result) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                p.completeWithSuccess(())
            }
        }
        // let's do some async dispatching of things here:
        return p.future
    }
    
    func imGonnaMapAVoidToAnInt() -> Future<Int> {
        
        let f = self.iDontReturnValues().onAnySuccess { (result)  in
            NSLog("do stuff")
        }.onAnySuccess { (result) in
            return 5
        }.onSuccess(.Primary) {(fffive) in
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
        return f.As()
    }
    
    
    func testing() {
        _ = Future<Optional<Int>>(success: 5)
        
//        let yx = convertOptionalFutures(x)
        
//        let y : Future<Int64?> = convertOptionalFutures(x)
        
        
    }

    
}







