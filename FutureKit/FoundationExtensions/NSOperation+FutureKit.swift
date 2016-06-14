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


// iOS 7 doesn't have built in queuePriority logic.  So we are baking our own.
public enum FutureOperationQueuePriority : Int {
    // these number mirror the NSOperationQueuePriority
    case VeryLow    = -8
    case Low        = -4
    case Normal     = 0
    case High       = 4
    case VeryHigh   = 8
    
    
    var operationQueuePriority : NSOperationQueuePriority {
        switch self {
        case .VeryHigh:
            return .VeryHigh
        case .High:
            return .High
        case .Normal:
            return .Normal
        case .Low:
            return .Low
        case .VeryLow:
            return .VeryLow
        }
    }
    
    
    init(opq :NSOperationQueuePriority) {
        switch opq {
        case .VeryHigh:
            self = .VeryHigh
        case .High:
            self =  .High
        case .Normal:
            self =  .Normal
        case .Low:
            self =  .Low
        case .VeryLow:
            self = .VeryLow
        }
    }
    
}

private var _futureOpPriorityVar = ExtensionVarHandlerFor<NSOperation>()

// we are going to add an iOS_7 compatible version of NSOperationQueuePriority
extension NSOperation {
    
    var futureOperationQueuePriority : FutureOperationQueuePriority {
        get {
            if OSFeature.NSOperationQueuePriority.is_supported {
                return FutureOperationQueuePriority(opq: self.queuePriority)
            }
            else {
                return _futureOpPriorityVar.getValueFrom(self, defaultvalue: .Normal)
            }
        }
        set(newPriority) {
            if OSFeature.NSOperationQueuePriority.is_supported {
                self.queuePriority = newPriority.operationQueuePriority
            }
            else {
                _futureOpPriorityVar.setValueOn(self, value: newPriority)
            }
            
        }
    }
    
}


public class FutureOperation<T> : _FutureAnyOperation {
    
    public typealias FutureOperationBlockType = () throws -> (Future<T>)

    public class func OperationWithBlock(executor:Executor = .Primary, block b: () throws -> Future<T>) -> FutureOperation<T> {
        return FutureOperation<T>(executor: executor,block:b)
    }

    public var future : Future<T> {
        return self.promise.future.mapAs()
    }

    public init(executor:Executor = .Primary, block b: () throws -> Future<T>) {
        super.init(executor: executor,block: { () throws -> AnyFuture in
            return try b()
        })
    }

}


public class _FutureAnyOperation : NSOperation, AnyFuture {
    
//    private var getSubFuture : () -> FutureProtocol
    public typealias FutureAnyOperationBlockType = () throws -> AnyFuture
    private var getSubFuture: FutureAnyOperationBlockType

    
    public var executor: Executor
    
    public var futureAny = Future<Any>(success: ())
    
    var cancelToken : CancellationToken?
    
    var promise = Promise<Any>()
    
    override public var asynchronous : Bool {
        return true
    }
    
    private var _is_executing : Bool {
        willSet {
            self.willChangeValueForKey("isExecuting")
        }
        didSet {
            self.didChangeValueForKey("isExecuting")
        }
    }
    private var _is_finished : Bool {
        willSet {
            self.willChangeValueForKey("isFinished")
        }
        didSet {
            self.didChangeValueForKey("isFinished")
        }
    }
    
    override public var executing : Bool {
        return _is_executing
    }
    
    override public var finished : Bool {
        return _is_finished
    }
    
    public init(executor:Executor, block : () throws -> AnyFuture) {
        self.executor = executor
        self.getSubFuture = block
        self._is_executing = false
        self._is_finished = false
        super.init()
    }
    
    
    override public func main() {
        
        if self.cancelled {
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
        
    }
    override public func cancel() {
        super.cancel()
        self.cancelToken?.cancel()
    }
    
    @available(*, deprecated=1.1, message="renamed to mapAs()")
    public func As<S>() -> Future<S> {
        return self.mapAs()
    }
    public func mapAs<S>() -> Future<S> {
        return self.promise.future.mapAs()
    }
    
    @available(*, deprecated=1.1, message="renamed to mapAsOptional()")
    public func convertOptional<S>() -> Future<S?> {
        return self.mapAsOptional()
    }

    public func mapAsOptional<S>() -> Future<S?> {
        return self.promise.future.mapAsOptional()
    }

}


public typealias FutureOperationQueue = NSOperationQueue

public extension NSOperationQueue {
    
    /*: just add an Operation using a block that returns a Future.
    
    returns a new Future<T> that can be used to compose when this operation runs and completes
    
    */
    public func add<T>(executor: Executor = .Primary,

                    priority : FutureOperationQueuePriority = .Normal,
                    block: FutureOperation<T>.FutureOperationBlockType) -> Future<T> {
        
        let operation = FutureOperation.OperationWithBlock(executor,block: block)
        operation.futureOperationQueuePriority = priority
        
        self.addOperation(operation)
        
        return operation.future
        
    }
    
    
}





