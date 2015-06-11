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
