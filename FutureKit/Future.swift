//
//  Future.swift
//  Shimmer
//
//  Created by Michael Gray on 1/7/15.
//  Copyright (c) 2015 FlybyMedia. All rights reserved.
//

import UIKit

public struct FUTUREKIT_GLOBAL_PARMS {
    // WOULD LOVE TO TURN THESE INTO COMPILE TIME PROPERTIES
    // MAYBE VIA an Objective C Header file?
    static let ALWAYS_ASYNC_DISPATCH_DEFAULT_TASKS = false
    static let WRAP_DEPENDENT_BLOCKS_WITH_OBJC_EXCEPTION_HANDLING = false
    
    static let STACK_CHECKING_PROPERTY = "FutureKit.immediate.TaskDepth"
    static let STACK_CHECKING_MAX_DEPTH = 20
    
    public static var LOCKING_STRATEGY : SynchronizationType = .NSLock
    
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

    init(genericError : String) {
        super.init(domain: FErrors.errorDomain, code: FErrors.GenericException.rawValue, userInfo: ["genericError" : genericError])
    }

    init(error : FErrors, userInfo: [NSObject : AnyObject]?) {
        super.init(domain: FErrors.errorDomain, code: error.rawValue, userInfo: userInfo)
    }
    init(exception: NSException) {
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

// this doesn't include ContinueWith intentionally!
// Tasks must complete in one these states
public enum CompletionState : Int {
    case Success
    case Fail
    case Cancelled
}

public enum Completion<T> {
    // typealias SuccessPayloadType = T           // PERFECT! - But it CRASHES
    // typealias SuccessPayloadType = T!          // OK.  But it STILL Crashes
    // typealias SuccessPayloadType = _FResult<T>     // Confusing.  But is type safe.
    
    typealias SuccessPayloadType = Any            // Works.  Makes me sad.


    case Success(Any)        //  why is this Success(Any) and not Success(T) or Success(T!)??
                                            //  Because of the evil IR Generation Swift crashiness.
                                            //  In a future version this will probably work, so we are using the SuccessPayloadType alias
                                            //  We are adding a assertion check inside of
    case Fail(NSError)
    case Cancelled
    case ContinueWith(Future<T>)
    
/*    public init?(completion : BlockResult<T>)
    {
        switch completion {
        case let .Success(t):
            self = .Success(t)
        case let .Fail(f):
            self = .Fail(f)
        case .Cancelled:
            self = .Cancelled
        case let .ContinueWith(f):
            assertionFailure("can't convert ContinueWith to FCompletion")
            return nil
        }
    } */
    
    public init(exception ex:NSException) {
        self = .Fail(FutureNSError(exception: ex))
    }
    public init(success : T) {
        self = .Success(success)
    }
    public init(failWithGenericError : String) {
        self = .Fail(FutureNSError(genericError: failWithGenericError))
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
    
    // make sure this enum is a Success before calling result
    public var result : T! {
        get {
            switch self {
            case let .Success(t):
                // if you crash here, it's because the result passsed to the future wasn't of type T!
                return (t as! T)
            default:
                return nil
            }
        }
    }
    // make sure this enum is a Fail before calling result
    public var error : NSError! {
        get {
            switch self {
            case let .Fail(e):
                // if you crash here, it's because the result passsed to the future wasn't of type T!
                return e
            default:
                return nil
            }
        }
    }
    
    public func asVoid() -> Completion<Void> {
        return self.convert()
    }
    public func asAny() -> Completion<Any> {
        return self.convert()
    }
    
    public func convert<S>() -> Completion<S> {
        switch self {
        case let .Success(t):
            let r = t as! S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .ContinueWith(f):
            let s : Future<S> = f.convert()
            return .ContinueWith(s)
        }
    }
    
    // warning S should NOT BE OPTIONAL!  Or you are doing it wrong.
    public func convertOptional<S>() -> Completion<S?> {
        switch self {
        case let .Success(t):
            let r = t as? S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .ContinueWith(f):
            let s : Future<S?> = f.convertOptional()
            return .ContinueWith(s)
        }
    }

}


/* public enum BlockResult<T> {
    
    case Success(Any)  // must be the same as FCompletion<T>.
    case Fail(NSError)
    case Cancelled
    case ContinueWith(Future<T>)
    
    init(_ completion : Completion<T>) {
        switch completion {
        case let .Success(t):
            self = .Success(t)
        case let .Fail(f):
            self = .Fail(f)
        case .Cancelled:
            self = .Cancelled
        }
    }
    init(exception ex:NSException) {
        self = .Fail(FutureNSError(exception: ex))
    }
} */

func make_dispatch_block<T>(q: dispatch_queue_t, block: (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        dispatch_async(q) {
            block(t)
        }
    }
    return newblock
}

func make_dispatch_block<T>(q: NSOperationQueue, block: (T) -> Void) -> ((T) -> Void) {
    
    let newblock = { (t:T) -> Void in
        q.addOperationWithBlock({ () -> Void in
            block(t)
        })
    }
    return newblock
}




public protocol FutureProtocol {
    func asFutureAny() -> Future<Any>
    func asFutureVoid() -> Future<Void>
}


public class Future<T> : FutureProtocol {
    public typealias resultType = T
    typealias resultVoidType = Void
    
    public typealias completionErrorHandler = Promise<T>.completionErrorHandler
    
    public typealias completion_block_type = ((Completion<T>) -> Void)
    private final var __callbacks : [completion_block_type]?

    // we want to "lock" access to _completionValue,
    // use THREAD_SAFE_SYNC to read or modify. (outside of init()
    private final var __completion : Completion<T>?
    
//    private final let lock = NSObject()
    private final let synchObject : SynchronizationProtocol = FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()
    
    
    // This is a thread-safe property to query the completion of a Future.
    // In general it's a tiny bit better (performance wise) to set this property via a Promise, or
    // use a OnComplete/OnSucess handler to get the result than querying this property directly!
    
    public final var completion : Completion<T>? {
        // using a onComplete/onSuccess/onFail handler is more efficient than reading this property directly!
        get {
            return self.synchObject.readSync { () -> Completion<T>? in
                return self.__completion
            }
        }
        // calling Promise<T>.setComplete() is more opimal than setting this property
        set(newCompletion) {
            if let c = newCompletion {
                self.completeWith(c, onCompletionError: { () -> Void in
                    assertionFailure("Cannot set \(newCompletion) on a completed task with existing completion of \(self.completion).")
                })
            }
        }
    }
    
    public final var hasCompleted : Bool {
        get {
            return self.synchObject.readSync { () -> Bool in
                return (self.__completion != nil)
            }
        }
    
    }
    
    public init() {
    }

    
    public init(completed:Completion<T>) {  // returns an completed Task
        self.__completion = completed
    }
    public init(success:T) {  // returns an completed Task  with result T
        self.__completion = .Success(success)
    }
    public init(failed:NSError) {  // returns an completed Task that has Failed with this error
        self.__completion = .Fail(failed)
    }
    public init(exception:NSException) {  // returns an completed Task that has Failed with this error
        self.__completion = Completion<T>(exception:exception)
    }
    
    public init(@noescape block :() -> Completion<T>) {
        self.__completion = block()
    }

    public init(@noescape block :() -> T) {
        self.__completion = .Success(block())
    }

    public convenience init(_ executor : Executor, _ b:() ->  T) {
        self.init()
        let block = executor.callbackBlockFor { () -> Void in
            self.completion = .Success(b())
            return
        }
        block()
    }

    public convenience init(_ executor : Executor, _ b:() -> Completion<T>) {
        self.init()
        let block = executor.callbackBlockFor { () -> Void in
            self.completion = b()
        }
        block()
    }

    
    // is this a good idea?
    // it's equivilant to the above, but may be more confusing when you look at it
    public convenience init(_ executor : Executor, @autoclosure(escaping) autoclosure: () -> T) {
        self.init()
        let block = executor.callbackBlockFor { () -> Void in
            self.completion = .Success(autoclosure())
        }
        block()
    }
    public convenience init(_ executor : Executor, @autoclosure(escaping) completionAutoclosure: () -> Completion<T>) {
        self.init()
        let block = executor.callbackBlockFor { () -> Void in
            self.completion = completionAutoclosure()
        }
        block()
    }
}

extension Future {

    // these are marked internal and should really only be called by a Promise<T> object!
    internal final func completeAndNotify(completion : Completion<T>) {
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        self.synchObject.writeAsync({ () -> [completion_block_type]? in
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

    internal final func completeAndNotify(completion : Completion<T>, onCompletionError : completionErrorHandler) {
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        self.synchObject.writeAsync({ () -> (cbs:[completion_block_type]?,success:Bool) in
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
    
    
    // if you want to verify that competion works synchronously (equivilant to Bolts "trySet" logic)
    
    internal final func completeAndNotifySync(completion : Completion<T>) -> Bool {
        
        assert(completion.isComplete, "You can't complete a Future with ContinueWith!")
        
        let tuple = self.synchObject.writeSync { () -> (cbs:[completion_block_type]?,success:Bool) in
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

    internal final func completeWith(completion : Completion<T>) {
        switch (completion) {
        case let .ContinueWith(f):
            f.onCompleteWith(.Immediate)  { (nextComp) -> Void in
                self.completeWith(nextComp)
                return
            }
        default:
            return self.completeAndNotify(completion)
        }
    }

    internal final func completeWithSync(completion : Completion<T>) -> Bool {
        switch (completion) {
        case let .ContinueWith(f):
            f.onCompleteWith(.Immediate)  { (nextComp) -> Void in
                self.completeWith(nextComp)
            }
            return true
        default:
            return self.completeAndNotifySync(completion)
        }
    }

    internal final func completeWith(completion : Completion<T>, onCompletionError errorBlock: completionErrorHandler) {
        switch (completion) {
        case let .ContinueWith(f):
            f.onCompleteWith(.Immediate)  { (nextComp) -> Void in
                self.completeWith(nextComp,onCompletionError: errorBlock)
                return
            }
        default:
            return self.completeAndNotify(completion,onCompletionError: errorBlock)
        }
    }
    
    
    internal final func createPromiseAndCallback<S>(forBlock: ((Completion<T>)-> Completion<S>)) -> (promise : Promise<S> , completionCallback :completion_block_type) {
        
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
    internal final func runThisCompletionBlockNowOrLater(callback : completion_block_type) {
        
        self.synchObject.writeAsync({ () -> Completion<T>? in
            if let c = self.__completion {
                return c
            }
            else
            {
                switch self.__callbacks {
                case var .Some(cb):
                    cb.append(callback)
                case .None:
                    self.__callbacks = [callback]
                }
                return nil
            }
        }, done: { (comp) -> Void in
            if let c = comp {
                // Future is already completed.
                // Run it now!
                callback(c)
            }
        })
    }
    
    //experiemental.  Probably not a good idea
    func __reset() {
        return self.synchObject.write {
            self.__callbacks = nil
            self.__completion = nil
        }
    }
}

extension Future {

    public func convert<S>() -> Future<S> {
        return self.map { (result) -> S in
            return result as! S
        }
    }
    
    public func convertOptional<S>() -> Future<S?> {
        return self.map { (result) -> S? in
            return result as? S
        }
    }
    
    public func asFutureAny() -> Future<Any> {
        return self.convert()
    }
    public func asFutureVoid() -> Future<Void> {
        return self.convert()
    }
}


extension Future {
    // ---------------------------------------------------------------------------------------------------
    // Block Handlers
    // ---------------------------------------------------------------------------------------------------

    // return a Future that can return all Completion Values (Result,Failed,Cancelled,ContiueWith)
    public final func onCompleteWith<S>(executor : Executor,block:( (completion:Completion<T>)-> Completion<S>)) -> Future<S> {
        
        let (promise, completionCallback) = self.createPromiseAndCallback(block)
        
        let block = executor.callbackBlockFor(completionCallback)
        self.runThisCompletionBlockNowOrLater(block)
        
        return promise.future
    }

    public final func onComplete<S>(block:( (completion:Completion<T>)-> Completion<S>)) -> Future<S> {
        return self.onCompleteWith(.Primary, block: block)
    }
 
    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS can always return any Completion Value you want  ------
    // ---------------------------------------------------------------------------------------------------
    // block only executes if this Future<T> returns .Success(T)
    // return a Future that can return all Completion Values (.Success,.Fail,.Cancelled,.ContiueWith)

    // so this function doesn't work when T == Void. (and itsn't very useful, since result = Void())
    // you must use onSuccessWith() if you are returning Future<Void>
    
    public final func onSuccessResultWith<S>(executor : Executor, _ block:((result:T) -> Completion<S>)) -> Future<S> {
        return self.onCompleteWith(executor)  { (completion) -> Completion<S> in
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

    public final func onSuccessWith<S>(executor : Executor, block:(() -> Completion<S>)) -> Future<S> {
        return self.onCompleteWith(executor)  { (completion) -> Completion<S> in
            switch completion.state {
            case let .Success:
                return block()
            case let .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled
            }
        }
    }

    public final func onSuccessResult<S>(block:((result:T)-> Completion<S>)) -> Future<S> {
        return self.onSuccessResultWith(.Primary,block)
    }

    public final func onSuccess<S>(block:(() -> Completion<S>)) -> Future<S> {
        return self.onSuccessWith(.Primary,block: block)
    }

    
    
    // block only executes if this Future<T> returns .Fail
    // return a Future that can return all Completion Values (Result,Failed,Cancelled,ContiueWith)
    public final func onFailWith<S>(executor : Executor, _ block:( (error:NSError)-> Completion<S>)) -> Future<S>
    {
        return self.onCompleteWith(executor) { (completion) -> Completion<S> in
            switch completion {
            case let .Fail(e):
                return block(error: e)
            default:
                return .Cancelled
            }
        }
    }
    public final func onFail<S>(block:( (error:NSError)-> Completion<S>)) -> Future<S> {
        return self.onFailWith(.Primary,block)
    }

    // block only executes if this Future<T> returns .Cancelled
    // return a Future that can return all Completion Values (Result,Failed,Cancelled,ContiueWith)
    public final func onCancelWith<S>(executor : Executor, _ block:( ()-> Completion<S>)) -> Future<S>
    {
        return self.onCompleteWith(executor) { (completion) -> Completion<S> in
            switch completion {
            case .Cancelled:
                return block()
            default:
                return .Cancelled
            }
        }
    }
    public final func onCancel<S>(block:( ()-> Completion<S>)) -> Future<S> {
        return self.onCancelWith(.Primary,block)
    }

    // ---------------------------------------------------------------------------------------------------
    // Just do this next thing, when this one is done.
    // ---------------------------------------------------------------------------------------------------
    public final func continueWith<S>(future:Future<S>) -> Future<S> {
        return self.onCompleteWith(.Immediate)  { (completion) -> Completion<S> in
            return .ContinueWith(future)
        }
    }
   public  final func OnSuccessContinueWith<S>(future:Future<S>) -> Future<S> {
        return self.onCompleteWith(.Immediate)  { (completion) -> Completion<S> in
            switch completion {
            case let .Success(t):
                return .ContinueWith(future)
            default:
                return .Cancelled
            }
        }
    }
    public final func OnFailContinueWith<S>(future:Future<S>) -> Future<S> {
        return self.onCompleteWith(.Immediate)  { (completion) -> Completion<S> in
            switch completion {
            case let .Fail(e):
                return .ContinueWith(future)
            default:
                return .Cancelled
            }
        }
    }
    public final func OnCancelContinueWith<S>(future:Future<S>) -> Future<S> {
        return self.onCompleteWith(.Immediate)  { (completion) -> Completion<S> in
            switch completion {
            case let .Cancelled:
                return .ContinueWith(future)
            default:
                return .Cancelled
            }
        }
    }


    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a .Success(S)
    // ---------------------------------------------------------------------------------------------------
    public final func onCompleteWith<S>(executor: Executor, _ block:( (completion:Completion<T>)-> S)) -> Future<S> {
        return self.onCompleteWith(executor) { (c) -> Completion<S> in
            return .Success(block(completion:c))
            }
    }
    public final func onComplete<S>(block:( (completion:Completion<T>)-> S)) -> Future<S> {
        return self.onCompleteWith(.Primary,block)
    }

    public final func onSuccessResultWith<S>(executor : Executor, _ block:(result:T)-> S) -> Future<S> {
        return self.onSuccessResultWith(executor) { (s : T) -> Completion<S> in
            return .Success(block(result: s))
        }
    }
    
    public final func onSuccessResult<S>(block:(result:T)-> S) -> Future<S> {
        return self.onSuccessResultWith(.Primary,block)
    }

    
    public final func onSuccessWith<S>(executor : Executor, _ block:()-> S) -> Future<S> {
        return self.onSuccessWith(executor) { () -> Completion<S> in
            return .Success(block())
        }
    }
    
    public final func onSuccess<S>(block:()-> S) -> Future<S> {
        return self.onSuccessWith(.Primary,block)
    }

    // rather use map?  Sure!
    public final func mapWith<S>(executor : Executor, block:((success:T)-> S)) -> Future<S> {
        return self.onSuccessResultWith(executor,block)
    }
    public final func map<S>(block:(success:T) -> S) -> Future<S> {
        return self.onSuccessResultWith(.Primary,block)
    }

    
    public final func onFailWith<S>(executor : Executor, _ block:((error:NSError)-> S)) -> Future<S> {
        return self.onFailWith(executor) { (e) -> Completion<S> in
            return .Success(block(error:e))
        }
    }
    public final func onFail<S>(block:((error:NSError)-> S)) -> Future<S> {
        return self.onFailWith(.Primary,block)
    }
    

    
    public final func onCancelWith<S>(executor : Executor, _ block:(()-> S)) -> Future<S> {
        return self.onCancelWith(executor) { () -> Completion<S> in
            return .Success(block())
        }
    }
    public final func onCancel<S>(block:(()-> S)) -> Future<S> {
        return self.onCancelWith(.Primary,block)
    }
    
    // ---------------------------------------------------------------------------------------------------
    // THESE GUYS always return a .ContinueWith((Future<S>) ------
    // ---------------------------------------------------------------------------------------------------
    public final func onCompleteWith<S>(executor: Executor, _ block:( (completion:Completion<T>)-> Future<S>)) -> Future<S> {
        return self.onCompleteWith(executor, block: { (c) -> Completion<S> in
            return .ContinueWith(block(completion:c))
        })
    }
    public final func onComplete<S>(block:( (conpletion:Completion<T>)-> Future<S>)) -> Future<S> {
        return self.onCompleteWith(.Primary,block)
    }
    

    public final func onSuccessResultWith<S>(executor : Executor, _ block:( (result:T)-> Future<S>)) -> Future<S> {
        return self.onSuccessResultWith(executor) { (s:T) -> Completion<S> in
            return .ContinueWith(block(result:s))
        }
    }
    
    public func onSuccessResult<S>(block:( (success:T)-> Future<S>)) -> Future<S> {
        return self.onSuccessResultWith(.Primary,block)
    }

    public func onSuccessWith<S>(executor : Executor, _ block:( ()-> Future<S>)) -> Future<S> {
        return self.onSuccessWith(executor) { () -> Completion<S> in
            return .ContinueWith(block())
        }
    }
    public final func onSuccess<S>(block:( ()-> Future<S>)) -> Future<S> {
        return self.onSuccessWith(.Primary,block)
    }
    
    
    public final func onFailWith<S>(executor : Executor, _ block:( (error:NSError)-> Future<S>)) -> Future<S> {
        return self.onFailWith(executor) { (e) -> Completion<S> in
            return .ContinueWith(block(error:e))
        }
    }
    public final func onFail<S>(block:( (error:NSError)-> Future<S>)) -> Future<S> {
        return self.onFailWith(.Primary,block)
    }
    
    
    public final func onCancelWith<S>(executor : Executor, _ block:( ()-> Future<S>)) -> Future<S> {
        return self.onCancelWith(executor) { () -> Completion<S> in
            return .ContinueWith(block())
        }
    }
    public final func onCancel<S>(block:( ()-> Future<S>)) -> Future<S> {
        return self.onCancelWith(.Primary,block)
    }
    
    
    public func waitUntilCompleted() -> Completion<T> {
        let s = FutureWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted()
    }
    
    public func waitForResult() -> T? {
        return self.waitUntilCompleted().result
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
    return f.onSuccessResult { tval -> AnyObject in
        return tval
    }
}

public func toFutureAnyObjectOpt<T : AnyObject>(f : Future<T?>) -> Future<AnyObject?> {
    return f.onSuccessResult { tval -> AnyObject? in
        return tval
    }
}

typealias legacyTask = Future<AnyObject?>

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
    func iReturnFromBackgroundQueueUsingAutoClosureTrick() -> Future<Int> {
        //
        return Future(.Default) { self.iReturnFive() }
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
                return .Cancelled
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
            case .Cancelled:
                return .Cancelled
            default:
                assertionFailure("This shouldn't happen!")
                return Completion<Void>(failWithGenericError: "something bad happened")
            }
        }
        
        self.iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
            switch completion.state {
            case let .Success:
                return .Success(Void())
            case let .Fail:
                return .Fail(completion.error)
            case .Cancelled:
                return .Cancelled
            }
        }
        
        
        self.iMayFailRandomly().onSuccess { () -> Completion<Int> in
            return .Success(5)
        }
            
        
        self.iMayFailRandomly().onSuccessResult { (x) -> Void in
            NSLog("\(x)")
        }
        
    }
    
    func iDontReturnValues() -> Future<Void> {
        let f = Future(.Primary) { () -> Int in
            return 5
        }
        
        let p = Promise<Void>()
        
        f.onSuccessResult { (result) -> Void in
            dispatch_main_async {
                p.completeWithSuccess()
            }
        }
        // let's do some async dispatching of things here:
        return p.future
    }
    
    func imGonnaMapAVoidToAnInt() -> Future<Int> {
        
        
        let f = self.iDontReturnValues().onSuccess { () -> Int in
            return 5
        }
            
        
        let g : Future<Int> = f.onSuccessResult({(fffive : Int) -> Float in
            Float(fffive + 10)
        }).onSuccess { (floatFifteen) ->  Int in
            Int(floatFifteen) + 5
        }
        return g
    }
    
    func adding5To5Makes10() -> Future<Int> {
        return self.imGonnaMapAVoidToAnInt().onSuccessResult { (value) -> Int in
            return value + 5
        }
    }

    func convertNumbersToString() -> Future<String> {
        return self.imGonnaMapAVoidToAnInt().onSuccessResult { (value) -> String in
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







