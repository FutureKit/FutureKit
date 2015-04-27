//
//  FTask.swift
//  Bikey
//
//  Created by Michael Gray on 4/12/15.
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


public class FTaskCompletion : NSObject {
    
    public typealias rtype = FTask.resultType
    
    var completion : Completion<rtype>
 
    init(completion c:Completion<rtype>) {
        self.completion = c
    }
    
    init(exception ex:NSException) {
        self.completion = FAIL(FutureNSError(exception: ex))
    }
    init(success : rtype) {
        self.completion = SUCCESS(success)
    }
    init(cancelled : ()) {
        self.completion = .Cancelled
    }
    init (fail : NSError) {
        self.completion = FAIL(fail)
    }
    init (continueWith f: FTask) {
        self.completion = COMPLETE_USING(f.future)
    }

    
    class func Success(success : rtype) -> FTaskCompletion {
        return FTaskCompletion(success: success)
    }
    class func Fail(fail : NSError) -> FTaskCompletion {
        return FTaskCompletion(fail: fail)
    }
    class func Cancelled() -> FTaskCompletion {
        return FTaskCompletion(cancelled: ())
    }
}




public class FTaskPromise : NSObject {
    
    public override init() {
        super.init()
    }
    
    public typealias rtype = FTask.resultType
    
    var promise =  Promise<rtype>()
    
    public var ftask : FTask {
        get {
            return FTask(self.promise.future)
        }
    }
    
    public final func complete(completion c: FTaskCompletion) {
        self.promise.complete(c.completion)
    }

    public final func completeWithSuccess(result : rtype) {
        self.promise.completeWithSuccess(result)
    }
    public final func completeWithFail(e : NSError) {
        self.promise.completeWithFail(e)
    }
    public final func completeWithException(e : NSException) {
        self.promise.completeWithException(e)
    }
    public final func completeWithCancel() {
        self.promise.completeWithCancel()
    }
    public final func continueWithFuture(f : FTask) {
        self.promise.continueWithFuture(f.future)
    }
    
    
    // can return true if completion was successful.
    // can block the current thread
    final func tryComplete(completion c: FTaskCompletion) -> Bool {
        return self.promise.tryComplete(c.completion)
    }
    
    public typealias completionErrorHandler = Promise<rtype>.completionErrorHandler

    // execute a block if the completion "fails" because the future is already completed.
    public final func complete(completion c: FTaskCompletion,onCompletionError errorBlock: completionErrorHandler) {
        self.promise.complete(c.completion, onCompletionError: errorBlock)
    }
    
}

extension FTaskPromise : Printable, DebugPrintable {
    
    public override var description: String {
        return "FTaskPromise!"
    }
    public override var debugDescription: String {
        return "FTaskPromise! - \(self.promise.future.debugDescription)"
    }
    
    public func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription + "QL"
    }
    
}


@objc public enum FTaskExecutor : Int {
    
    case Primary                    // use the default configured executor.  Current set to Immediate.
    // There are deep philosphical arguments about Immediate vs Async.
    // So whenever we figure out what's better we will set the Primary to that!
    
    case Immediate                  // Never performs an Async Dispatch, Ok for simple mappings. But use with care!
    // Blocks using the Immediate executor can run in ANY Block
    
    case Async                      // Always performs an Async Dispatch to some non-main q (usually Default)
    
    case StackCheckingImmediate     // Will try to perform immediate, but does some stack checking.  Safer than Immediate
    // But is less efficient.  Maybe useful if an Immediate handler is somehow causing stack overflow issues
    
    case Main                       // will use MainAsync or MainImmediate based on MainStrategy
    
    case MainAsync                  // will always do a dispatch_async to the mainQ
    case MainImmediate              // will try to avoid dispatch_async if already on the MainQ
    
    
    
    case UserInteractive            // QOS_CLASS_USER_INTERACTIVE
    case UserInitiated              // QOS_CLASS_USER_INITIATED
    case Default                    // QOS_CLASS_DEFAULT
    case Utility                    // QOS_CLASS_UTILITY
    case Background                 // QOS_CLASS_BACKGROUND
    
//    case Queue(dispatch_queue_t)    // Dispatch to a Queue of your choice!
    // Use this for your own custom queues
    
//    case ManagedObjectContext(NSManagedObjectContext)   // block will run inside the managed object's context via context.performBlock()
    
    func execute<T>(block b: dispatch_block_t) {
        let executionBlock = self.executor().callbackBlockFor(b)
        executionBlock()
    }
    
    func executor() -> Executor {
        switch self {
        case .Primary:
            return .Primary
        case .Immediate:
            return .Immediate
        case .Async:
            return .Async
        case StackCheckingImmediate:
            return .StackCheckingImmediate
        case Main:
            return .Main
        case MainAsync:
            return .MainAsync
        case MainImmediate:
            return .MainImmediate
        case UserInteractive:
            return .UserInteractive
        case UserInitiated:
            return .UserInitiated
        case Default:
            return .Default
        case Utility:
            return .Utility
        case Background:
            return .Background
        }
    }
    
}



public class FTask : NSObject {
    
    public typealias resultType = AnyObject?
    
    public typealias futureType = Future<resultType>
    
    var future : Future<resultType>
    
    
    override init() {
        self.future = Future<resultType>()
        super.init()
    }
    init(_ f : Future<resultType>) {
        self.future = f
    }
    }


public extension FTask {
    
    private class func toCompletion(a : AnyObject?) -> Completion<resultType> {
        switch a {
        case let f as Future<resultType>:
            return .CompleteUsing(f)
        case let f as FTask:
            return .CompleteUsing(f.future)

        case let c as Completion<resultType>:
            return c
        case let c as FTaskCompletion:
            return c.completion
            
        case let error as NSError:
            return .Fail(error)
        case let ex as NSException:
            return Completion<resultType>(exception: ex)
        default:
            return SUCCESS(a)
        }
    }
    private class func toCompletionObjc(a : AnyObject?) -> FTaskCompletion {
        return FTaskCompletion(completion: self.toCompletion(a))
    }

    final func onCompleteQ(q : dispatch_queue_t,block b:( (completion:FTaskCompletion)-> AnyObject?)) -> FTask {
        
        let f = self.future.onComplete(Executor.Queue(q)) { (completion) -> Completion<resultType> in
            let c = FTaskCompletion(completion: completion)
            return FTask.toCompletion(b(completion: c))
        }
        return FTask(f)
    }

    final func onComplete(executor : FTaskExecutor,block b:( (completion:FTaskCompletion)-> AnyObject?)) -> FTask {
        let f = self.future.onComplete(executor.executor()) { (completion) -> Completion<resultType> in
            let c = FTaskCompletion(completion: completion)
            return FTask.toCompletion(b(completion: c))
        }
        return FTask(f)
    }

    
    final func onComplete(block:( (completion:FTaskCompletion)-> AnyObject?)) -> FTask {
        return self.onComplete(.Primary, block: block)
    }


    final func onSuccessResultWithQ(q : dispatch_queue_t, _ block:((result:resultType) -> AnyObject?)) -> FTask {
        return self.onCompleteQ(q)  { (c) -> AnyObject? in
            if c.completion.isSuccess {
                return block(result: c.completion.result)
            }
            else {
                return c
            }
        }
    }

    final func onSuccessResultWith(executor : FTaskExecutor, _ block:((result:resultType) -> AnyObject?)) -> FTask {
        return self.onComplete(executor)  { (c) -> AnyObject? in
            if c.completion.isSuccess {
                return block(result: c.completion.result)
            }
            else {
                return c
            }
        }
    }

    final func onSuccessWithQ(q : dispatch_queue_t, block:(() -> AnyObject?)) -> FTask {
        return self.onCompleteQ(q)  { (c) -> AnyObject? in
            if c.completion.isSuccess {
                return block()
            }
            else {
                return c
            }
        }
    }
    final func onSuccess(executor : FTaskExecutor, block:(() -> AnyObject?)) -> FTask {
        return self.onComplete(executor)  { (c) -> AnyObject? in
            if c.completion.isSuccess {
                return block()
            }
            else {
                return c
            }
        }
    }

    final func onSuccessResult(block:((result:resultType)-> AnyObject?)) -> FTask {
        return self.onSuccessResultWith(.Primary,block)
    }
    
    final func onSuccess(block:(() -> AnyObject?)) -> FTask {
        return self.onSuccess(.Primary,block: block)
    }


}



























