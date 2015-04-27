//
//  LockPerformanceTests.swift
//  FutureKit
//
//  Created by Michael Gray on 4/20/15.
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

import XCTest
import FutureKit

let executor = Executor.createConcurrentQueue(label: "FuturekitTests")
let executor2 = Executor.createConcurrentQueue(label: "FuturekitTests2")



let opQueue = { () -> Executor in
    let opqueue = NSOperationQueue()
    opqueue.maxConcurrentOperationCount = 5
    return Executor.OperationQueue(opqueue)
    }()


func dumbAdd(executor:Executor,x : Int, y: Int) -> Future<Int> {
    let p = Promise<Int>()
    
    executor.execute { () -> Void in
        let z = x + y
        p.completeWithSuccess(z)
    }
    return p.future
}

func dumbJob() -> Future<Int> {
    return dumbAdd(.Primary, 0, 1)
}

func divideAndConquer(executor:Executor,x: Int, y: Int,iterationsDesired : Int) -> Future<Int> // returns iterations done
{
    let p = Promise<Int>()
    
    executor.execute { () -> Void in
        
        var subFutures : [Future<Int>] = []
        
        if (iterationsDesired == 1) {
            subFutures.append(dumbAdd(executor,x,y))
        }
        else {
            let half = iterationsDesired / 2
            subFutures.append(divideAndConquer(executor,x,y,half))
            subFutures.append(divideAndConquer(executor,x,y,half))
            if ((half * 2)  < iterationsDesired) {
                subFutures.append(dumbJob())
            }
        }
        
        let batch = FutureBatchOf<Int>(f: subFutures)
        let f = batch.future
        
        f.onSuccess({ (result) -> Void in
            var sum = 0
            for i in result {
                sum += i
            }
            p.completeWithSuccess(sum)
        })
    }
    return p.future
}


class FutureKitLockPerformanceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // serialQueueDispatchPool.flushQueue(keepCapacity: false)
        // concurrentQueueDispatchPool.flushQueue(keepCapacity: false)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func doATestCase(lockStategy: SynchronizationType, chaining : Bool, x : Int, y: Int, iterations : Int) {
        
        GLOBAL_PARMS.LOCKING_STRATEGY = lockStategy
        GLOBAL_PARMS.BATCH_FUTURES_WITH_CHAINING = chaining
        
        let f = divideAndConquer(.Primary,x,y,iterations)
        
        var ex = f.expectationTestForSuccess(self, "Description") { (result) -> BooleanType in
            return (result == (x+y)*iterations)
        }
        
        self.waitForExpectationsWithTimeout(120.0, handler: nil)
        
    }
    
    
    let lots = 5000
    
    func testLotsWithBarrierConcurrent() {
        self.measureBlock() {
            self.doATestCase(.BarrierConcurrent, chaining: false, x: 0, y: 1, iterations: self.lots)
        }
    }
    
    func testLotsWithSerialQueue() {
        self.measureBlock() {
            self.doATestCase(.SerialQueue, chaining: false,x: 0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithNSObjectLock() {
        self.measureBlock() {
            self.doATestCase(.NSObjectLock, chaining: false,x:0, y: 1, iterations: self.lots)
        }
    }
    
    func testLotsWithNSLock() {
        self.measureBlock() {
            self.doATestCase(.NSLock, chaining: false,x:0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithNSRecursiveLock() {
        self.measureBlock() {
            self.doATestCase(.NSRecursiveLock, chaining: false,x:0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithOSSpinLock() {
        self.measureBlock() {
            self.doATestCase(.OSSpinLock, chaining: false,x:0, y: 1, iterations: self.lots)
        }
    }
    
    func testLotsWithBarrierConcurrentChained() {
        self.measureBlock() {
            self.doATestCase(.BarrierConcurrent, chaining: true, x: 0, y: 1, iterations: self.lots)
        }
    }
    
    func testLotsWithSerialQueueChained() {
        self.measureBlock() {
            self.doATestCase(.SerialQueue, chaining: true,x: 0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithNSObjectLockChained() {
        self.measureBlock() {
            self.doATestCase(.NSObjectLock, chaining: true,x:0, y: 1, iterations: self.lots)
        }
    }
    
    func testLotsWithNSLockChained() {
        self.measureBlock() {
            self.doATestCase(.NSLock, chaining: true,x:0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithNSRecursiveLockChained() {
        self.measureBlock() {
            self.doATestCase(.NSRecursiveLock, chaining: true,x:0, y: 1, iterations: self.lots)
        }
    }
    func testLotsWithOSSpinLockChained() {
        self.measureBlock() {
            self.doATestCase(.OSSpinLock, chaining: true,x:0, y: 1, iterations: self.lots)
        }
    }
}
