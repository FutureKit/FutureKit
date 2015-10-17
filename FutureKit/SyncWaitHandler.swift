//
//  SyncFuture.swift
//  FutureKit
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

public func warnOperationOnMainThread() {
    NSLog("Warning: A long-running Future wait operation is being executed on the main thread. \n Break on FutureKit.warnOperationOnMainThread() to debug.")
}

class SyncWaitHandler<T>  {
    
    private var condition : NSCondition = NSCondition()
    
    private var value : FutureResult<T>?
    
    init (waitingOnFuture f: Future<T>) {
        f.onComplete { (v) -> Void in
            self.condition.lock()
            self.value = v
            self.condition.broadcast()
            self.condition.unlock()
        }
    }
    
    final func waitUntilCompleted(doMainQWarning warn: Bool = true) -> FutureResult<T> {
        self.condition.lock()
        if (warn && NSThread.isMainThread()) {
            if (self.value == nil) {
                warnOperationOnMainThread()
            }
        }
        while (self.value == nil) {
            self.condition.wait()
        }
        self.condition.unlock()
        
        return self.value!
    }
    
}

/* extension Future {
    
    public func waitUntilCompleted() -> Completion<T> {
        let s = FutureWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted()
    }
    
    public func waitForResult() -> T? {
        return self.waitUntilCompleted().result
    }
} */

