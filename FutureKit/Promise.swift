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

public enum CancelRequestResponse<T> {
    case Continue            // the promise will not be completed
    case Complete(Completion<T>)  // ex: .Complete(.Cancelled)
}


public class Promise<T>  {
    
    public var future : Future<T>

    public init() {
        self.future = Future<T>()
    }
    public required init(success:T) {
        self.future = Future<T>(success: success)
    }
    public required init(fail:ErrorType) {
        self.future = Future<T>(fail: fail)
    }
    public required init(cancelled:()) {
        self.future = Future<T>(cancelled: cancelled)
    }
    public required init(completeUsing:Future<T>) {
        self.future = Future<T>(completeUsing: completeUsing)
    }
    
    // *  complete commands  */
    
    public final func complete<C:CompletionType where C.T == T>(completion : C) {
        self.future.completeWith(completion.completion)
    }
    
    public final func completeWithSuccess(result : T) {
        self.future.completeWith(.Success(result))
    }
    public final func completeWithFail(error : ErrorType) {
        self.future.completeWith(.Fail(error))
    }
    public final func completeWithFail(errorMessage : String) {
        self.future.completeWith(Completion<T>(failWithErrorMessage: errorMessage))
    }
    public final func completeWithErrorMessage(errorMessage : String) {
        self.future.completeWith(Completion<T>(failWithErrorMessage: errorMessage))
    }
    
    public final func completeWithException(e : NSException) {
        self.future.completeWith(Completion<T>(exception: e))
    }
    public final func completeWithCancel() {
        self.future.completeWith(.Cancelled)
    }
    public final func completeUsingFuture(f : Future<T>) {
        self.future.completeWith(.CompleteUsing(f))
    }


    public convenience init(automaticallyCancelAfter delay: NSTimeInterval) {
        self.init()
        self.automaticallyCancelAfter(delay)
    }

    public convenience init(automaticallyFailAfter delay: NSTimeInterval, error:ErrorType ) {
        self.init()
        self.automaticallyFailAfter(delay,error:error)
    }

    public convenience init(automaticallyFailAfter delay: NSTimeInterval, errorMessage:String ) {
        self.init()
        self.automaticallyFailAfter(delay,error:FutureKitError(genericError: errorMessage))
    }

    // untestable?
    public convenience init(automaticallyAssertAfter delay: NSTimeInterval, file : StaticString = #file, line : Int32 = #line) {
        self.init()
    }
    
    
    public final func automaticallyCancelAfter(delay: NSTimeInterval) {
        self.automaticallyCancelOnRequestCancel()
        Executor.Default.executeAfterDelay(delay) { () -> Void in
            self.completeWithCancel()
        }
    }

    public final func automaticallyFailAfter(delay: NSTimeInterval, error:ErrorType) {
        self.automaticallyCancelOnRequestCancel()
        Executor.Default.executeAfterDelay(delay) { () -> Void in
            self.failIfNotCompleted(error)
        }
    }

    
    public final func automaticallyAssertOnFail(message:String, file : StaticString = #file, line : Int32 = #line) {
        self.future.onFail { (error) -> Void in
            assertionFailure("\(message) on at:\(file):\(line)")
            return
        }
    }

    
    public final func onRequestCancel(executor:Executor = .Primary, handler: (options:CancellationOptions) -> CancelRequestResponse<T>) {
        let newHandler : (CancellationOptions) -> Void  = { [weak self] (options) -> Void in
            switch handler(options: options) {
            case .Complete(let completion):
                self?.complete(completion)
            default:
                break
            }
            
        }
        let wrappedNewHandler = Executor.Primary.callbackBlockFor(newHandler)
        self.future.addRequestHandler(wrappedNewHandler)
        
    }
    public final func automaticallyCancelOnRequestCancel() {
        self.onRequestCancel { (force) -> CancelRequestResponse<T> in
            return .Complete(.Cancelled)
        }
    }
    
    
/*    public final func completeWithThrowingBlock(block: () throws -> T) {
        do {
            let t = try block()
            self.completeWithSuccess(t)
        }
        catch {
            self.completeWithFail(error)
        }
    } */

    /**
    completes the Future using the supplied completionBlock.

    the completionBlock will ONLY be executed if the future is successfully completed.
    
    If the future/promise has already been completed than the block will not be executed.

    if you need to know if the completion was successful, use 'completeWithBlocks()'
    
    - parameter completionBlock: a block that will run iff the future has not yet been completed.  It must return a completion value for the promise.
    */
    public final func completeWithBlock<C:CompletionType where C.T == T>(completionBlock : () throws ->C) {
        self.future.completeWithBlocks(waitUntilDone: false,completionBlock: completionBlock,onCompletionError: nil)
    }
    
    /**
    completes the Future using the supplied completionBlock.
    
    the completionBlock will ONLY be executed if the future has not yet been completed prior to this call.

    the onAlreadyCompleted will ONLY be executed if the future was already been completed prior to this call.
    
    These blocks may end up running inside any potential thread or queue, so avoid using external/shared memory.

    - parameter completionBlock: a block that will run iff the future has not yet been completed.  It must return a completion value for the promise.

    - parameter onAlreadyCompleted: a block that will run iff the future has already been completed. 
    */
    public final func completeWithBlocks<C:CompletionType where C.T == T>(completionBlock : () throws ->C, onAlreadyCompleted : () -> Void)
    {
        self.future.completeWithBlocks(waitUntilDone: false,completionBlock: completionBlock, onCompletionError: onAlreadyCompleted)
    }


    public final func failIfNotCompleted(e : ErrorType) -> Bool {
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
    public final func tryComplete<C:CompletionType where C.T == T>(completion : C) -> Bool {
        return self.future.completeWithSync(completion)
    }
    
    public typealias CompletionErrorHandler = (() -> Void)
    // execute a block if the completion "fails" because the future is already completed.
    
    public final func complete<C:CompletionType where C.T == T>(completion : C,onCompletionError errorBlock: CompletionErrorHandler) {
        self.future.completeWith(completion.completion,onCompletionError:errorBlock)
    }
    

}

extension Promise {
    // Warning - reusing this lock for other purposes is danger when using LOCKING_STRATEGY.NSLock
    // don't read or write values on the Promise or Future
    internal var synchObject : SynchronizationProtocol  {
        get {
            return future.synchObject
        }
    }
    
}
