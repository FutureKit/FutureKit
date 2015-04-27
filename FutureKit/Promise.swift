//
//  Promise.swift
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

public class Promise<T>  {
    
    // Warning - reusing this lock for other purposes is danger when using LOCKING_STRATEGY.NSLock
    // don't read or write values on the Promise or Future
    internal var synchObject : SynchronizationProtocol  {
        get {
            return future.synchObject
        }
    }

    public typealias completionErrorHandler = (() -> Void)
    
    public var future : Future<T>
    
    public init() {
        self.future = Future<T>()
    }

    /**
        creates a promise that enables the Future.cancel()
        The cancellationHandler will execute using Executor.Primary
    */
    public init(cancellationHandler h: () -> Void) {
        let newHandler = Executor.Primary.callbackBlockFor(h)
        self.future = Future<T>(cancellationHandler: newHandler)
    }

    /**
    creates a promise that enables the Future.cancel()
    The cancellationHandler will execute using the executor
    */
    public init(executor:Executor,cancellationHandler h: () -> Void) {
        let newHandler = executor.callbackBlockFor(h)
        self.future = Future<T>(cancellationHandler: newHandler)
    }

    
    public init(automaticallyFailAfter: NSTimeInterval, file : String = __FILE__, line : Int32 = __LINE__) {
        self.future = Future<T>()
        Executor.Default.executeAfterDelay(automaticallyFailAfter) { () -> Void in
            self.failIfNotCompleted("Promise created on \(file):line\(line) timed out")
        }
    }
    public init(automaticallyAssertAfter: NSTimeInterval, file : String = __FILE__, line : Int32 = __LINE__) {
        self.future = Future<T>()
        Executor.Default.executeAfterDelay(automaticallyAssertAfter) { () -> Void in
            if (!self.isCompleted) {
                let message = "Promise created on \(file):line\(line) timed out"
                if (self.failIfNotCompleted(message)) {
                    assertionFailure(message)
                }
            }
        }
    }
    
    public final func complete(completion : Completion<T>) {
        self.future.completeWith(completion)
    }
    
//    public final func completeWithVoidSuccess() {
//        assert(toString(T.self) == toString(Void.self),"You must send a result if the type isn't Promise<Void> - USE completeWithSuccess(result : T) instead!")
//        self.future.completeWith(.Success(Result(Void)))
//    }
    public final func completeWithSuccess(result : T) {
        self.future.completeWith(.Success(Result(result)))
    }
    public final func completeWithFail(e : NSError) {
        self.future.completeWith(.Fail(e))
    }
    public final func completeWithFail(errorMessage : String) {
        self.future.completeWith(Completion<T>(failWithErrorMessage: errorMessage))
    }
    public final func completeWithException(e : NSException) {
        self.future.completeWith(Completion<T>(exception: e))
    }
    public final func completeWithCancel() {
        self.future.completeWith(.Cancelled)
    }
    public final func continueWithFuture(f : Future<T>) {
        self.future.completeWith(.CompleteUsing(f))
    }

    /**
    completes the Future using the supplied completionBlock.

    the completionBlock will ONLY be executed if the future is successfully completed.
    
    If the future/promise has already been completed than the block will not be executed.

    if you need to know if the completion was successful, use 'completeWithBlocks()'
    
    :param: completionBlock a block that will run iff the future has not yet been completed.  It must return a completion value for the promise.
    */
    public final func completeWithBlock(completionBlock : ()->Completion<T>) {
        self.future.completeWithBlocks(completionBlock,onCompletionError: nil)
    }
    
    /**
    completes the Future using the supplied completionBlock.
    
    the completionBlock will ONLY be executed if the future has not yet been completed prior to this call.

    the onAlreadyCompleted will ONLY be executed if the future was already been completed prior to this call.
    
    These blocks may end up running inside any potential thread or queue, so avoid using external/shared memory.

    :param: completionBlock a block that will run iff the future has not yet been completed.  It must return a completion value for the promise.

    :param: onAlreadyCompleted a block that will run iff the future has already been completed. 
    */
    public final func completeWithBlocks(completionBlock : ()->Completion<T>, onAlreadyCompleted : () -> Void)
    {
        self.future.completeWithBlocks(completionBlock, onCompletionError: onAlreadyCompleted)
    }


    public final func failIfNotCompleted(e : NSError) -> Bool {
        if (!self.isCompleted) {
            return self.future.completeWithSync(.Fail(e))
        }
        return false
    }
    public final func failIfNotCompleted(errorMessage : String) -> Bool {
        if (!self.isCompleted) {
            return self.future.completeWithSync(Completion<T>(failWithErrorMessage: errorMessage))
        }
        return false
    }

    public var isCompleted : Bool {
        get {
            return self.future.isCompleted
        }
    }
    
    
    // can return true if completion was successful.
    // can block the current thread
    public final func tryComplete(completion : Completion<T>) -> Bool {
        return self.future.completeWithSync(completion)
    }
    
    // execute a block if the completion "fails" because the future is already completed.
    public final func complete(completion : Completion<T>,onCompletionError errorBlock: completionErrorHandler) {
        self.future.completeWith(completion,onCompletionError:errorBlock)
    }
    
    // experimental.  Not a good idea really
    func __reset() {
        self.future.__reset()
    }
}
