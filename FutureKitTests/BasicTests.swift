//
//  FutureKitTests.swift
//  FutureKitTests
//
//  Created by Michael Gray on 4/12/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

//import UIKit
import XCTest
import FutureKit




func iMayFailRandomly() -> Future<String>  {
    let p = Promise<String>()
    
    // This is a random number from 0..2:
    let randomNumber = arc4random_uniform(3)
    switch randomNumber {
    case 0:
        p.completeWithFail(FutureNSError(error: .GenericException, userInfo: nil))
    case 1:
        p.completeWithCancel()
    default:
        p.completeWithSuccess("Yay")
    }
    return p.future
}

typealias keepTryingResultType = (tries:Int,result:String)
func iWillKeepTryingTillItWorks(var attemptNo: Int) -> Future<(tries:Int,result:String)> {
    
    attemptNo++
    return iMayFailRandomly().onComplete { (completion) -> Completion<(tries:Int,result:String)> in
        switch completion {
        case let .Success(yay):
            // Success uses Any as a payload type, so we have to convert it here.
            let s = yay as! String
            let result = (attemptNo,s)
            return .Success(result)
        default: // we didn't succeed!
            let nextFuture = iWillKeepTryingTillItWorks(attemptNo)
            return .CompleteUsing(nextFuture)
        }
    }
}


class FutureKitBasicTests: XCTestCase {
    
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
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testFuture() {
        let x = Future<Int>(success: 5)
        
        XCTAssert(x.completion!.result == 5, "it works")
    }
    func testFutureWait() {
        let f = dumbAdd(.Primary,1, 1).waitUntilCompleted()

        XCTAssert(f.result == 2, "it works")
    }
    
    func doATestCaseSync(x : Int, y: Int, iterations : Int) {
        let f = divideAndConquer(.Primary,x,y,iterations).waitUntilCompleted()
        
        let expectedResult = (x+y)*iterations
        XCTAssert(f.result == expectedResult, "it works")
        
    }
    
    func testADoneFutureExpectation() {
        let val = 5
        
        let f = Future<Int>(success: val)
        var ex = f.expectationTestForSuccess(self, "AsyncMadness") { (result) -> BooleanType in
            return (result == val)
        }
        
        self.waitForExpectationsWithTimeout(30.0, handler: nil)
        
        
    }
    func testContinueWithRandomly() {
        
        let f = iWillKeepTryingTillItWorks(0)
 
        var ex = f.expectationTestForAnySuccess(self, "Description")
        
        self.waitForExpectationsWithTimeout(120.0, handler: nil)
        
    }
    
}
