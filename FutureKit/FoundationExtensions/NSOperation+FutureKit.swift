//
//  NSOperation+FutureKit.swift
//  Shimmer
//
//  Created by Michael Gray on 6/2/15.
//  Copyright (c) 2015 FlybyMedia. All rights reserved.
//

import Foundation


class FutureOperation<T> : _FutureAnyOperation {
    
    class func OperationWithBlock(block b: () -> Future<T>) -> FutureOperation<T> {
        return FutureOperation<T>(block:b)
    }
    
    var future : Future<T> {
        return self.promise.future.As()
    }

    init(block b: () -> Future<T>) {
        super.init(block: { () -> FutureProtocol in
            return b()
        })
    }
    
}


class _FutureAnyOperation : NSOperation, FutureProtocol {
    
    private var getSubFuture : () -> FutureProtocol
    var subFuture : Future<Any>?
    var cancelToken : CancellationToken?
    
    var promise = Promise<Any>()
    
    override var asynchronous : Bool {
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
    
    override var executing : Bool {
        return _is_executing
    }
    
    override var finished : Bool {
        return _is_finished
    }
    
    init(block : () -> FutureProtocol) {
        self.getSubFuture = block
        self._is_executing = false
        self._is_finished = false
        super.init()
    }
    
    override func main() {
        
        if self.cancelled {
            self._is_executing = false
            self._is_finished = true
            self.promise.completeWithCancel()
            return
        }
        
        self._is_executing = true

        let f : Future<Any> = self.getSubFuture().As()
        self.subFuture = f
        self.cancelToken = f.getCancelToken()
        f.onComplete { completion in
            self._is_executing = false
            self._is_finished = true
            self.promise.complete(completion)
        }
        
    }
    override func cancel() {
        super.cancel()
        self.cancelToken?.cancel()
    }
    
    func As<S>() -> Future<S> {
        return self.promise.future.As()
    }
    
    func convertOptional<S>() -> Future<S?> {
        return self.promise.future.convertOptional()
    }
    
}
