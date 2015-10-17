//
//  FutureKitTests.swift
//  FutureKitTests
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

//import UIKit
import XCTest
import FutureKit


func iMayFailRandomly() -> Future<String>  {
    let p = Promise<String>()
    
    // This is a random number from 0..2:
    let randomNumber = arc4random_uniform(20)
    if (randomNumber == 0) {
        NSLog("yay!!")
        p.completeWithSuccess("Yay")
    }
    else {
        switch (randomNumber % 2){
        case 0:
            NSLog("FAIL!")
            p.completeWithFail(FutureKitError.GenericError("iMayFailRandomly failed"))
        default:
            NSLog("CANCEL!")
            p.completeWithCancel()
        }
    }
    return p.future
}

typealias keepTryingResultType = (tries:Int,result:String)
func iWillKeepTryingTillItWorks(var attemptNo: Int) -> Future<(tries:Int,result:String)> {
    
    attemptNo++
    return iMayFailRandomly().onComplete { (completion) -> Completion<(tries:Int,result:String)> in
        NSLog("completion = \(completion)")
        switch completion {
        case let .Success(yay):
            // Success uses Any as a payload type, so we have to convert it here.
            let result = (tries:attemptNo,result:yay)
            return .Success(result)
        default: // we didn't succeed!
            let nextFuture = iWillKeepTryingTillItWorks(attemptNo)
            return .CompleteUsing(nextFuture)
        }
    }
}


/* extension XCTestCase {
    
    func expectationTestForFutureCompletion<T>(description : String, future f: Future<T>,
        file: String = __FILE__,
        line: UInt = __LINE__,
        assertion : ((completion : Completion<T>) -> (assert:BooleanType,message:String))
        ) -> XCTestExpectation! {
            
            let e = self.expectationWithDescription(description)
            
            f.onComplete { (completion) -> Void in
                let test = assertion(completion:completion)
                
                XCTAssert(test.assert,test.message,file:file,line:line)
                e.fulfill()
            }
            return e
    }

    func expectationTestForFutureSuccess<T>(description : String,future f: Future<T>,
        file: String = __FILE__,
        line: UInt = __LINE__,
        test : ((result:T) -> BooleanType)
        ) -> XCTestExpectation! {
            
            return self.expectationTestForFutureCompletion(description,future: f, file:file,line:line)  { (completion : Completion<T>) -> (assert: BooleanType, message: String) in
                switch completion.state {
                case .Success:
                    let result = completion.result
                    return (test(result: result),"test result failure for Future with result \(result)" )
                case .Fail:
                    let e = completion.error
                    return (false,"Future Failed with \(e)" )
                case .Cancelled:
                    return (false,"Future Cancelled" )
                }
            }
    }
    
    func expectationTestForFutureSuccess<T>(description : String, future f: Future<T>,
        file: String = __FILE__,
        line: UInt = __LINE__
        ) -> XCTestExpectation! {
            
            return self.expectationTestForFutureSuccess(description, future: f, test: { (result) -> BooleanType in
                return true
            })
            
    }
} */

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
        
        XCTAssert(x.result!.value == 5, "it works")
    }
    
    func testADoneFutureExpectation() {
        let val = 5
        let f = Future<Int>(success: val)
        
        self.expectationTestForFutureSuccess("AsyncMadness", future: f) { (result:Int) -> BooleanType in
            return (result == val)
        }
        
        self.waitForExpectationsWithTimeout(30.0, handler: nil)
        
        
    }
    func testContinueWithRandomly() {
        
        iWillKeepTryingTillItWorks(0).expectationTestForAnySuccess(self, description: "Description")
        
        self.waitForExpectationsWithTimeout(120.0, handler: nil)
        
    }
    
}
