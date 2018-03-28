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
    case `continue`            // the promise will not be completed
    case complete(Completion<T>)  // ex: .Complete(.Cancelled)
}


public class Promise<T>  {
    
    public var future : Future<T>

    public init(_ file: StaticString = #file,
                _ line: UInt = #line) {
        self.future = Future<T>(file, line)
    }

    public init(_ fileLineInfo: FileLineInfo) {
        self.future = Future<T>(fileLineInfo)
    }

    public init(success:T,
                         _ file: StaticString = #file,
                         _ line: UInt = #line) {
        self.future = Future<T>(success: success, file, line)
    }
    public init(fail:Error,
                         _ file: StaticString = #file,
                         _ line: UInt = #line) {
        self.future = Future<T>(fail: fail, file, line)
    }
    public init(cancelled:(),
                         _ file: StaticString = #file,
                         _ line: UInt = #line) {
        self.future = Future<T>(cancelled: cancelled, file, line)
    }
    public init(completeUsing:Future<T>,
                         _ file: StaticString = #file,
                         _ line: UInt = #line) {
        self.future = Future<T>(completeUsing: completeUsing, file, line)
    }
    
    // *  complete commands  */
    
    public final func complete<C:CompletionType>(_ completion : C,
                                                 _ file: StaticString = #file,
                                                 _ line: UInt = #line) where C.T == T {
        self.future.completeWith(completion.completion, FileLineInfo(file, line))
    }


    public final func complete(_ result : AdvancedFutureResult<T>) {
        self.future.completeWith(result.completion, result.fileLineInfo)
    }

    public final func complete<C:CompletionType>(_ completion : C,
                                                 _ fileLineInfo: FileLineInfo) where C.T == T {
        self.future.completeWith(completion.completion, fileLineInfo)
    }

    public final func completeWithSuccess(_ result : T,
                                          _ file: StaticString = #file,
                                          _ line: UInt = #line) {
        self.future.completeWith(.success(result), FileLineInfo(file, line))
    }
    public final func completeWithSuccess(_ result : T,
                                          _ fileLineInfo: FileLineInfo) {
        self.future.completeWith(.success(result), fileLineInfo)
    }


    public final func completeWithFail(_ error : Error,
                                       _ file: StaticString = #file,
                                       _ line: UInt = #line) {
        self.future.completeWith(.fail(error), FileLineInfo(file, line))
    }
    public final func completeWithFail(_ error : Error,
                                       _ fileLineInfo: FileLineInfo) {
        self.future.completeWith(.fail(error), fileLineInfo)
    }

    public final func completeWithFail(_ errorMessage : String,
                                       _ file: StaticString = #file,
                                       _ line: UInt = #line) {
        self.future.completeWith(Completion<T>(failWithErrorMessage: errorMessage), FileLineInfo(file, line))
    }
    public final func completeWithErrorMessage(_ errorMessage : String,
                                               _ file: StaticString = #file,
                                               _ line: UInt = #line) {
        self.future.completeWith(Completion<T>(failWithErrorMessage: errorMessage), FileLineInfo(file, line))
    }
    
    public final func completeWithException(_ e : NSException,
                                            _ file: StaticString = #file,
                                            _ line: UInt = #line) {
        self.future.completeWith(Completion<T>(exception: e), FileLineInfo(file, line))
    }
    public final func completeWithCancel(_ file: StaticString = #file, _ line: UInt = #line) {
        self.future.completeWith(.cancelled, FileLineInfo(file, line))
    }
    public final func completeWithCancel(_ fileLineInfo: FileLineInfo) {
        self.future.completeWith(.cancelled, fileLineInfo)
    }
    public final func completeUsingFuture(_ f : Future<T>, _ file: StaticString = #file, _ line: UInt = #line) {
        self.future.completeWith(.completeUsing(f), FileLineInfo(file, line))
    }
    public final func completeUsingFuture(_ f : Future<T>, _ fileLineInfo: FileLineInfo) {
        self.future.completeWith(.completeUsing(f), fileLineInfo)
    }


    public convenience init(automaticallyCancelAfter delay: TimeInterval,
                            _ file: StaticString = #file,
                            _ line: UInt = #line) {
        self.init(file, line)
        self.automaticallyCancel(afterDelay:delay)
    }

    public convenience init(automaticallyFailAfter delay: TimeInterval,
                            error:Error,
                            _ file: StaticString = #file,
                            _ line: UInt = #line) {
        self.init(file, line)
        self.automaticallyFail(afterDelay:delay,with:error)
    }

    public convenience init(automaticallyFailAfter delay: TimeInterval,
                            errorMessage:String,
                            _ file: StaticString = #file,
                            _ line: UInt = #line) {
        self.init(file, line)
        self.automaticallyFail(afterDelay:delay,with:FutureKitError(genericError: errorMessage))
    }

    // untestable?
    public convenience init(automaticallyAssertAfter delay: TimeInterval,
                            file : StaticString = #file,
                            line : UInt = #line) {
        self.init(file, line)
    }
    
    
    @available(*, deprecated, renamed: "automaticallyCancel(afterDelay:)")
    public final func automaticallyCancelAfter(_ delay: TimeInterval,
                                               _ file: StaticString = #file,
                                               _ line: UInt = #line) {
        self.automaticallyCancelOnRequestCancel()
        Executor.default.execute(afterDelay:delay) { () -> Void in
            self.completeWithCancel(file, line)
        }
    }

    public final func automaticallyCancel(afterDelay delay: TimeInterval,
                                          _ file: StaticString = #file,
                                          _ line: UInt = #line) {
        self.automaticallyCancelOnRequestCancel()
        Executor.default.execute(afterDelay:delay) { () -> Void in
            self.completeWithCancel(file, line)
        }
    }

    @available(*, deprecated, renamed: "automaticallyFail(afterDelay:with:)")
    public final func automaticallyFailAfter(_ delay: TimeInterval,
                                             error:Error,
                                             _ file: StaticString = #file,
                                             _ line: UInt = #line) {
        self.automaticallyCancelOnRequestCancel()
        Executor.default.execute(afterDelay:delay) { () -> Void in
            self.failIfNotCompleted(error, file, line)
        }
    }

    public final func automaticallyFail(afterDelay delay: TimeInterval,
                                        with:Error,
                                        _ file: StaticString = #file,
                                        _ line: UInt = #line) {
        self.automaticallyCancelOnRequestCancel()
        Executor.default.execute(afterDelay:delay) { () -> Void in
            self.failIfNotCompleted(with, file, line)
        }
    }

    
    public final func automaticallyAssertOnFail(_ message:String, _ file : StaticString = #file, _ line : Int32 = #line) {
        self.future.onFail { (error) -> Void in
            assertionFailure("\(message) on at:\(file):\(line)")
            return
        }
    }

    internal final func onRequestCancelAdvanced(_ executor:Executor = .primary,
                                                  handler: @escaping (_ arguments: CancellationArguments) -> CancelRequestResponse<T>) {
        let newHandler : (CancellationArguments) -> Void  = { [weak self] (arguments) -> Void in
            switch handler(arguments) {
            case .complete(let completion):
                self?.complete(completion, arguments.fileLineInfo)
            default:
                break
            }

        }
        let wrappedNewHandler = Executor.primary.callbackBlockFor(newHandler)
        self.future.addRequestHandler(wrappedNewHandler)

    }

    
    public final func onRequestCancel(_ executor:Executor = .primary, handler: @escaping (_ options:CancellationOptions) -> CancelRequestResponse<T>) {
        return self.onRequestCancelAdvanced(executor, handler: { (arguments) -> CancelRequestResponse<T> in
            return handler(arguments.options)
        })
    }
    public final func automaticallyCancelOnRequestCancel() {
        self.onRequestCancel { (force) -> CancelRequestResponse<T> in
            return .complete(.cancelled)
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
    public final func completeWithBlock<C:CompletionType>(_ file : StaticString = #file,
                                                          _ line : UInt = #line,
                                                          _ completionBlock : @escaping () throws ->C) where C.T == T {
        self.future.completeWithBlocks(FileLineInfo(file, line),
                                       waitUntilDone: false,
                                       completionBlock: completionBlock)
    }
    
    /**
    completes the Future using the supplied completionBlock.
    
    the completionBlock will ONLY be executed if the future has not yet been completed prior to this call.

    the onAlreadyCompleted will ONLY be executed if the future was already been completed prior to this call.
    
    These blocks may end up running inside any potential thread or queue, so avoid using external/shared memory.

    - parameter completionBlock: a block that will run iff the future has not yet been completed.  It must return a completion value for the promise.

    - parameter onAlreadyCompleted: a block that will run iff the future has already been completed. 
    */
    public final func completeWithBlocks<C:CompletionType>(_ file : StaticString = #file,
                                                           _ line : UInt = #line,
                                                           _ completionBlock : @escaping () throws ->C,
                                                           onAlreadyCompleted : @escaping () -> Void) where C.T == T
    {
        self.future.completeWithBlocks(FileLineInfo(file, line),
                                       waitUntilDone: false,
                                       completionBlock: completionBlock,
                                       onCompletionError: onAlreadyCompleted)
    }


    @discardableResult
    public final func failIfNotCompleted(_ e : Error,
                                         _ file : StaticString = #file,
                                         _ line : UInt = #line) -> Bool {
        if (!self.isCompleted) {
            return self.future.completeWithSync(.fail(e), FileLineInfo(file, line))
        }
        return false
    }

    @discardableResult
    public final func failIfNotCompleted(_ errorMessage : String,
                                         _ file : StaticString = #file,
                                         _ line : UInt = #line) -> Bool {
        if (!self.isCompleted) {
            return self.future.completeWithSync(Completion<T>(failWithErrorMessage: errorMessage), FileLineInfo(file, line))
        }
        return false
    }

    open var isCompleted : Bool {
        get {
            return self.future.isCompleted
        }
    }
    
    
    // can return true if completion was successful.
    // can block the current thread
    public final func tryComplete<C:CompletionType>(_ completion : C,
                                                    _ file : StaticString = #file,
                                                    _ line : UInt = #line) -> Bool where C.T == T {
        return self.future.completeWithSync(completion, FileLineInfo(file, line))
    }
    
    public typealias CompletionErrorHandler = (() -> Void)
    // execute a block if the completion "fails" because the future is already completed.
    
    public final func complete<C:CompletionType>(_ completion : C,
                                                 _ file : StaticString = #file,
                                                 _ line : UInt = #line,
                                                 onCompletionError errorBlock: @escaping () -> Void) where C.T == T {
        self.future.completeWith(completion.completion, FileLineInfo(file, line), onCompletionError:errorBlock)
    }
    
    
    // public convenience methods
    public final func futureWithCancel(_ file : StaticString = #file,
                                       _ line : UInt = #line) -> Future<T>{
        self.completeWithCancel(file, line)
        return future
    }
    
    public final func futureWithSuccess(result : T,
                                        _ file : StaticString = #file,
                                        _ line : UInt = #line) -> Future<T>{
        self.completeWithSuccess(result, file, line)
        return future
    }
    
    public final func futureWithFailure(error : Error,
                                        _ file : StaticString = #file,
                                        _ line : UInt = #line) -> Future<T>{
        self.completeWithFail(error, file, line)
        return future
    }
    
    public final func futureWithFailure(errorMessage : String,
                                        _ file : StaticString = #file,
                                        _ line : UInt = #line) -> Future<T>{
        self.completeWithFail(errorMessage, file, line)
        return future
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
