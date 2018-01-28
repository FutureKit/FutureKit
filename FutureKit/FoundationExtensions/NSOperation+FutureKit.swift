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



open class FutureOperation<T> : Operation, FutureConvertable {
    
    public typealias FutureOperationBlockType = () throws -> (Future<T>.Completion)
    
    private var getSubFuture: FutureOperationBlockType


//    open class func OperationWithBlock(_ executor:Executor = .primary, block b: @escaping () throws -> Future<T>) -> FutureOperation<T> {
//        return FutureOperation<T>(executor: executor,block:b)
//    }

    open var future : Future<T> {
        return self.promise.future
    }

    open var executor: Executor
 
    var cancelToken : CancellationToken?    
    var promise = Promise<T>()
    
    override open var isAsynchronous : Bool {
        return true
    }
    
    private var isExecutingKvo : Bool {
        willSet {
            self.willChangeValue(forKey: "isExecuting")
        }
        didSet {
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    private var isFinishedKvo : Bool {
        willSet {
            self.willChangeValue(forKey: "isFinished")
        }
        didSet {
            self.didChangeValue(forKey: "isFinished")
        }
    }
    
    override open var isExecuting : Bool {
        return isExecutingKvo
    }
    
    override open var isFinished : Bool {
        return isFinishedKvo
    }
    
    public init<C: CompletionConvertable>(executor:Executor, block : @escaping () throws -> C) where C.T == T {
        self.executor = executor
        self.getSubFuture = { () throws -> Future<T>.Completion in 
            return try block().completion
        }
        self.isExecutingKvo = false
        self.isFinishedKvo = false
        super.init()
        
        self.promise.onRequestCancel { [weak self] _ -> Future<T>.CancelResponse in
            self?.cancel()
            return .continue
        }

    }
    
    
    override open func main() {
        
        if self.isCancelled {
            self.isExecutingKvo = false
            self.isFinishedKvo = true
            self.promise.completeWithCancel()
            return
        }
        
        self.isExecutingKvo = true

        self.cancelToken = self.executor
            .execute { () -> Completion<T> in
                return try self.getSubFuture()
            }
            .onComplete(executor) { (value) -> Void in
                self.isExecutingKvo = false
                self.isFinishedKvo = true
                self.promise.complete(value)
            }        
            .getCancelToken()
        
    }
    override open func cancel() {
        super.cancel()
        self.cancelToken?.cancel()
    }

}


public extension OperationQueue {
    
    /*: just add an Operation using a block that returns a Future.
    
    returns a new Future<T> that can be used to compose when this operation runs and completes
    
    */
     
    public func add<C: CompletionType>(_ executor: Executor = .primary,
                       
                       priority : Operation.QueuePriority = .normal,
                       block: @escaping () throws -> (C)) -> Future<C.T> {
        
        let operation = FutureOperation<C.T>(executor: executor, block: block)
        operation.queuePriority = priority
        
        self.addOperation(operation)
        
        return operation.future
        
    }

    
    
}





