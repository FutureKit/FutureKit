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



open class FutureOperation<T> : _FutureAnyOperation {
    
    public typealias FutureOperationBlockType = () throws -> (Future<T>)

    open class func OperationWithBlock(_ executor:Executor = .primary, block b: @escaping () throws -> Future<T>) -> FutureOperation<T> {
        return FutureOperation<T>(executor: executor,block:b)
    }

    open var future : Future<T> {
        return self.promise.future.mapAs()
    }

    public init(executor:Executor = .primary, block b: @escaping () throws -> Future<T>) {
        super.init(executor: executor,block: { () throws -> AnyFuture in
            return try b()
        })
    }

}


open class _FutureAnyOperation : Operation, AnyFuture {
    
//    private var getSubFuture : () -> FutureProtocol
    public typealias FutureAnyOperationBlockType = () throws -> AnyFuture
    fileprivate var getSubFuture: FutureAnyOperationBlockType

    
    open var executor: Executor
    
    open var futureAny = Future<Any>(success: ())
    
    var cancelToken : CancellationToken?
    
    var promise = Promise<Any>()
    
    override open var isAsynchronous : Bool {
        return true
    }
    
    fileprivate var _is_executing : Bool {
        willSet {
            self.willChangeValue(forKey: "isExecuting")
        }
        didSet {
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    fileprivate var _is_finished : Bool {
        willSet {
            self.willChangeValue(forKey: "isFinished")
        }
        didSet {
            self.didChangeValue(forKey: "isFinished")
        }
    }
    
    override open var isExecuting : Bool {
        return _is_executing
    }
    
    override open var isFinished : Bool {
        return _is_finished
    }
    
    public init(executor:Executor, block : @escaping () throws -> AnyFuture) {
        self.executor = executor
        self.getSubFuture = block
        self._is_executing = false
        self._is_finished = false
        super.init()
    }
    
    
    override open func main() {
        
        if self.isCancelled {
            self._is_executing = false
            self._is_finished = true
            self.promise.completeWithCancel()
            return
        }
        
        self._is_executing = true

        
        let f: Future<Any> = self.executor.execute { () -> Future<Any> in
            return try self.getSubFuture().futureAny
        }
        self.futureAny = f
        self.cancelToken = f.getCancelToken()
        f.onComplete(executor) { (value) -> Void in
            self._is_executing = false
            self._is_finished = true
            self.promise.complete(value)
        }
        .ignoreFailures()
        
    }
    override open func cancel() {
        super.cancel()
        self.cancelToken?.cancel()
    }
    
    @available(*, deprecated: 1.1, message: "renamed to mapAs()")
    open func As<S>() -> Future<S> {
        return self.mapAs()
    }
    open func mapAs<S>() -> Future<S> {
        return self.promise.future.mapAs()
    }
    
    @available(*, deprecated: 1.1, message: "renamed to mapAsOptional()")
    open func convertOptional<S>() -> Future<S?> {
        return self.mapAsOptional()
    }

    open func mapAsOptional<S>() -> Future<S?> {
        return self.promise.future.mapAsOptional()
    }

}


public extension OperationQueue {
    
    /*: just add an Operation using a block that returns a Future.
    
    returns a new Future<T> that can be used to compose when this operation runs and completes
    
    */
    public func add<T>(_ executor: Executor = .primary,

                    priority : Operation.QueuePriority = .normal,
                    block: @escaping FutureOperation<T>.FutureOperationBlockType) -> Future<T> {
        
        let operation = FutureOperation.OperationWithBlock(executor,block: block)
        operation.queuePriority = priority
        
        self.addOperation(operation)
        
        return operation.future
        
    }
    
    
}





