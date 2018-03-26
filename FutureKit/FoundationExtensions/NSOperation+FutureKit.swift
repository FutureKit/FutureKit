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



//open class FutureOperation<T> : FutureAnyOperation {
//
//    public typealias FutureOperationBlockType = () throws -> (Future<T>)
//
//    open class func OperationWithBlock(_ executor:Executor = .primary, block b: @escaping () throws -> Future<T>) -> FutureOperation<T> {
//        return FutureOperation<T>(executor: executor,block:b)
//    }
//
//    open var future : Future<T> {
//        return self.futureAny.mapAs(T.self)
//    }
//
//    public init(executor:Executor = .primary, block b: @escaping () throws -> Future<T>) {
//        super.init(executor: executor,block: { () throws -> AnyFuture in
//            return try b()
//        })
//    }
//
//}

open class FutureOperation<T> : Operation {
    
    //    private var getSubFuture : () -> FutureProtocol
    public typealias FutureAnyOperationBlockType = () throws -> Future<Any>
    fileprivate var getSubFuture: (() throws -> Future<T>)?
    
    
    public let executor: Executor
    
    public var future: Future<T> {
        return self.externalPromise.future
    }
    private let externalPromise: Promise<T>

//    private let internalPromise: Promise<T>

    private var subFutureToken : CancellationToken?
    private var subFuture: Future<T>?

    private let fileLineInfo: FileLineInfo
    
    override open var isAsynchronous : Bool {
        return true
    }
    
    private var atomicIsExecuting = Atomic<Bool>(false)
    private var atomicIsFinished = Atomic<Bool>(false)
    
    override open var isExecuting : Bool {
        get {
            return atomicIsExecuting.value
        }
        set(newValue) {
            self.willChangeValue(forKey: "isExecuting")
            atomicIsExecuting.swap(newValue)
            self.didChangeValue(forKey: "isExecuting")
        }
    }
    
    override open var isFinished : Bool {
        get {
            return atomicIsFinished.value
        }
        set(newValue) {
            self.willChangeValue(forKey: "isFinished")
            atomicIsFinished.swap(newValue)
            self.didChangeValue(forKey: "isFinished")
        }
    }
    
    public init(executor exec:Executor,
                _ file: StaticString = #file,
                _ line: UInt = #line,
                block : @escaping () throws -> Future<T>) {
        fileLineInfo = FileLineInfo(file,line)
        executor = exec
        getSubFuture = block
        externalPromise = Promise<T>()
 //       internalPromise = Promise<T>()
        super.init()

        externalPromise.onRequestCancel { (options) -> CancelRequestResponse<T> in
            self.cancel()
            return .complete(.cancelled)
        }
    }
    override open func start() {
        super.start()
        externalPromise.future.onComplete { _ in
            self.isExecuting = false
            self.isFinished = true
        }
    }

    override open func main() {

        guard !isCancelled, let getSubFutureBlock = getSubFuture else {
            isExecuting = false
            isFinished = true
            return
        }

        let subFuture = executor.execute { () -> Future<T> in
            return try getSubFutureBlock()
        }
        getSubFuture = nil
        externalPromise.completeUsingFuture(subFuture)
        isExecuting = true
        subFutureToken = subFuture.getCancelToken()

        self.subFuture = subFuture
    }
    override open func cancel() {
        super.cancel()

        subFutureToken?.cancel()
        externalPromise.completeWithCancel()
    }
    override open var description: String {
        return "\(super.description) - \(self.externalPromise.future) \(String(describing: self.subFuture))"
    }

    override open var debugDescription: String {
        return "\(super.debugDescription) - \(self.externalPromise.future) - \(String(describing: self.subFuture))"
    }
}


public extension OperationQueue {
    
    /*: just add an Operation using a block that returns a Future.
     
     returns a new Future<T> that can be used to compose when this operation runs and completes
     
     */
    public func add<T>(_ executor: Executor = .primary,
                       _ file: StaticString = #file,
                       _ line: UInt = #line,
                       priority : Operation.QueuePriority = .normal,
                       block: @escaping () throws -> Future<T>) -> Future<T> {
        
        let operation = FutureOperation<T>(executor: executor, file, line, block: block)
        operation.queuePriority = priority

        if !operation.isFinished {
            self.addOperation(operation)
        }
        
        return operation.future
        
    }

    public var unfinishedOperationCount: Int {
        return self.operations.reduce(0) { (total, operation) -> Int in
            if !operation.isFinished {
                return total + 1
            }
            return total
        }
    }
    
    
}





