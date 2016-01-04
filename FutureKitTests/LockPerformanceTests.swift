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


let iterationCount1 = (1024*1024*32)
let iterationCount2 = (1024*1024)
let iterationCount3 = (1024*32)
let _iterationCount = (1024)
var testCount = 0


enum ThreadCases : Int {
    case one = 1
    case two = 2
    case four = 4
    
    static let allValues = [four, two, one]
}

enum NumberOfLockCases : Int {
    case one = 1
    case two = 2
    case four = 4
    
    static let allValues = [one, two, four]
}

enum ExecuteWith : String {
    case Threads = "Threads"
    case Queues = "Queues"
    
    static let allValues = [Threads, Queues]
    
}
enum SyncAsyncWrite : String {
    case Async = "Async"
    case Sync = "Sync"
    
    static let allValues = [Async, Sync]
}

struct AttributesForTest {
    let iterationCount : Int
    let threads: Int
    let syncType:SynchronizationType
    let number_of_locks : UInt32
    let shared_locks : Bool
    let with: ExecuteWith
    let sOrA: SyncAsyncWrite
    let reads: UInt32
    let writes: UInt32
    let description : String
    
    var testName : String {
        let percentage = Int(self.writePercentage * 100)
        
        return "test_\(syncType)_Threads_\(threads)_\(with.rawValue)_\(sOrA.rawValue)_writes_\(percentage)_lock_\(number_of_locks)_contention_\(contention)"
    }
    
    var contention : Int {
        if (!shared_locks) {
            return 0
        }
        return Int(100.0 / Float(number_of_locks) * Float(threads - 1))
    }


}

class LockPerformanceTests: BlockBasedTestCase {

    typealias TestBlockType = ((LockPerformanceTests) -> Void)
    
    override class func myBlockBasedTests() -> [AnyObject] {
        
        var tests = [AnyObject]()
        
        typealias readWriteRatios = (read:UInt32, write:UInt32)
        let readWriteCases : [readWriteRatios]  = [(0,1),(1,3),(1,1),(3,1),(1,0)]

        typealias locksAndThreads = (locks:UInt32, threads:Int, shared:Bool, description: String)
        let lockAndThreadCases : [locksAndThreads]  = [ (1, 2, true,"1 shared lock - 2 threads - 100% contention"),
                                                        (2, 2, false, "one thread each with one unshared lock - 0% contention"),
                                                        (2, 2, true, "2 theads 2 shared locks - 50% contention"),
                                                        (4, 2, true, "4 locks shared by 2 threads - 25% contention"),
                                                        (8, 2, true, "8 locks shared by 2 threads - 12% contention") ]

        
        for lockAndThread in lockAndThreadCases {
        
            for type in SynchronizationType.allValues {
                for with in ExecuteWith.allValues {
                    for sOrA in SyncAsyncWrite.allValues {
                        for rw in readWriteCases {
                            
                            let attributes = AttributesForTest(
                                iterationCount: _iterationCount,
                                threads: lockAndThread.threads,
                                syncType: type,
                                number_of_locks:lockAndThread.locks,
                                shared_locks:lockAndThread.shared,
                                with: with,
                                sOrA: sOrA,
                                reads: rw.read,
                                writes: rw.write,
                                description:lockAndThread.description)
                            
                            NSLog("adding test \(attributes.testName)")
                            
                            
                            if let test = self.addTest(attributes.testName, closure: { (_self : LockPerformanceTests) -> Void in
                                _self.measureTest(attributes)
                            }) {
                            
                                tests.append(test)
                            }
                        }
                        
                    }
                }
            }
        }
        
        return tests
        
        // call addTest a bunch of times... */
    }

    
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
    

    func iterateTestWithQueues(attributes:AttributesForTest) {

        let block = attributes.blockForTest()

        let queue = NSOperationQueue()

        queue.maxConcurrentOperationCount = attributes.threads
        
        for thread_number in 0..<attributes.threads {
            queue.addOperationWithBlock({ () -> Void in
                block(runningThreadNum: thread_number)
            })
        }

        queue.waitUntilAllOperationsAreFinished()
    }

    func iterateTestWithThreads(attributes:AttributesForTest) {
        
        let block = attributes.blockForTest()
        typealias ThreadType = FutureThread
        
        var threads = [ThreadType]()
        
        for thread_number in 0..<attributes.threads {
            let t = ThreadType(block: { () -> Any in
                block(runningThreadNum: thread_number)
            })
            threads.append(t)
        }
        
        var futures = [Future<Any>]()
        for thread in threads {
            futures.append(thread.future)
            thread.start()
        }
        
        self.expectationTestForFutureSuccess("threads", future: FutureBatchOf(futures:futures).future)
        self.waitForExpectationsWithTimeout(600, handler: nil)
    }
    
    
 
    func iterateLocks(attributes:AttributesForTest) {
        
        switch attributes.with {
        case .Queues:
            self.iterateTestWithQueues(attributes)
        case .Threads:
            self.iterateTestWithThreads(attributes)
        }
    }

    func measureTest(attributes:AttributesForTest) {
        self.measureBlock { () -> Void in
            self.iterateLocks(attributes)
        }
    }
}

extension AttributesForTest {
    
    
    var numops : UInt32 {
        return reads+writes
    }
    
    var writePercentage : Float {
        return Float(writes) / Float(numops)
    }
    
    // we want to ranomly decide whether this will be a read or a write
    // but we need to keep it in the ratio of reads : writes
    func doReadCoinFlip() -> Bool {
        return (writes == 0) ||
            ((reads > 0) && (arc4random_uniform(numops) < reads))
    }
    
    func blockForTest() -> ((runningThreadNum:Int) -> Void) {
        
        assert(number_of_locks >= 1, "need at least 1 lock")
        
/*        typealias Key = String
        typealias Value = Int
        typealias DictType = Dictionary<Key,Value>
        
        let keys : [Key] = ["one","two","three"]
        let keysCount = UInt32(keys.count) */

        typealias Key = Int
        typealias Value = Int
        typealias DictType = Dictionary<Key,Value>
        
        let keys : [Key] = [0,1,2]
        let keysCount = UInt32(keys.count)

        
        // these will be the dictionaries the locks will control access for
        
        typealias DataPair = (dict:DictType, lock:SynchronizationProtocol)
        
        var data : [DataPair] = []
        
        for _ in 0..<number_of_locks {
            let lock = syncType.lockObject()
            let dict = DictType()
            
            data.append((dict,lock))
        }
        
        let iterate = iterationCount / threads // we want the total 'effort' to the same for all tests
        let sharedLocks = shared_locks
        
        let block = { (runningThreadNum:Int) -> Void in
            
            for _ in 0..<iterate {
                
                // pick the dictionary and lock we are going to use
                let data_index_to_use: Int
                if (sharedLocks) {
                    data_index_to_use = Int(arc4random_uniform(self.number_of_locks))
                }
                else {
                    data_index_to_use = runningThreadNum
                }
                
                let data_to_use = data[data_index_to_use]

                let lock = data_to_use.lock
                var dict = data_to_use.dict
                
                let keyToUseIndex = Int(arc4random_uniform(keysCount))
                let keyTouse = keys[keyToUseIndex]
                
                if self.doReadCoinFlip() {
                    lock.lockAndReadSync { () -> Value? in
                        return dict[keyTouse]
                    }
                }
                else {
                    let modifyBlock = { () -> Void in
                        if let i = dict[keyTouse] {
                            dict[keyTouse] = i + 1
                        }
                        else {
                            dict[keyTouse] = 1
                        }
                    }
                    switch self.sOrA {
                    case .Async:
                        lock.lockAndModify(modifyBlock)
                    case .Sync:
                        lock.lockAndModifySync(modifyBlock)
                    }
                }
            }
        }
        return block
        
    }
    
}

