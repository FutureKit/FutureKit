//
//  FutureFIFO.swift
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


// can execute a FIFO set of Blocks and Futures, guaranteeing that Blocks and Futures execute in order
public class FutureFIFO {
    
    private var lastFuture = Future<Any>(success: ())
    
    public init() {
        
    }
    // add a block and it won't execute until all previosuly submitted Blocks have finished and returned a result.
    // If the block returns a result, than the next ask in the queue is started.
    // If the block returns a Task, that Task must complete before the next block in the Queue is executed.
    
    // A Failed or Canceled task doesn't stop execution of the queue
    // If you care about the Result of specific committed block, you can add a dependency to the Task returned from this function
    public func add<T>(executor: Executor = .Primary, operation: () -> Future<T>) -> Future<T> {
    
        let t = self.lastFuture.onComplete { _ in
            return operation()
        }
        self.lastFuture = t.mapAs()
        return t
    }

}
