//
//  PromiseTests.swift
//  FutureKit
//
//  Created by Skyler Gray on 6/25/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation
import XCTest
import FutureKit

struct TestCaseVariables<T> {
    var promise: Promise<T>?
    var success:T?
    var error:ErrorType?
    var promiseExecutor : Executor?
    var futureExecutor : Executor?
    
    var onRequestHandler : CancelRequestHandler?
}

func ex() {
    
    let t = TestCaseVariables<Int>()
    var s = t
    
    s.promise = Promise<Int>()
    
    assert(t.promise == nil, "see!")
    
}

enum PromiseFunctions {
    
    case initDefault
    case onRequestCancelExecutor
    case onRequestCancel
    case automaticallyCancelOnRequestCancel
    case initWithAutomaticallyCancelAfter
    case initWithAutomaticallyFailAfter
    case initWithAutomaticallyAssertAfter
    
    case complete
    case completeWithSuccess
    case completeWithFailErrorMessage
    case completeWithFail
    case completeWithException
    case completeWithCancel
    case continueWithFuture
    case completeWithBlock
    
    case failIfNotCompleted
    case failIfNotCompletedErrorMessage
    case isCompleted
    
    case tryComplete
    case completeWithOnCompletionError
    
    
    func executeWith<T>(inout test : TestCaseVariables<T>)
    
    {
        switch self {
            
        case initDefault:
            test.promise = Promise<T>()
            
        case completeWithSuccess:
            test.promise.complete

        case completeWithSuccess:
            test.promise!.completeWithSuccess(test.success!)

        case completeWithSuccess:
            test.promise!.completeWithSuccess(test.success!)
            

        default:
            assertionFailure("haven't implemeted \(self) yet!")
            XCTFail("haven't impleneted test case yet!")
            
            
    }
    
    
    
    
    
}

class PromiseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    func onPromiseSuccessVoid(promiseExecutor p: Executor, futureExecutor : Executor) {
        
        let promise = Promise<Void>()
        let f = promise.future
        let success: () = ()
        
        let completeExpectation = self.expectationWithDescription("Future.onComplete")
        let successExpectation = self.expectationWithDescription("Future.onSuccess")
        let anySuccessExpectation = self.expectationWithDescription("Future.onAnySuccess")
        
        
        f.onComplete(futureExecutor) { (completion) -> Void in
            
            switch completion {
            case let .Success(t):
                break
            default:
                XCTFail("unexpectad completion value \(completion)")
            }
            completeExpectation.fulfill()
        }
        
        // TODO: Can we get this to compile?
        
/*        f.onSuccess(futureExecutor) { (result:()) -> Void in
            
            successExpectation.fulfill()
            
        } */
        f.onAnySuccess(futureExecutor) { (result) -> Void in
            XCTAssert(result is Void, "Didn't get expected success value \(success)")
            anySuccessExpectation.fulfill()
        }
        
        f.onFail(futureExecutor) { (error) -> Void in
            XCTFail("unexpectad onFail error \(error)")
            
        }
        f.onCancel(futureExecutor) { () -> Void in
            XCTFail("unexpectad onCancel" )
        }
        
        promise.completeWithSuccess(success)
        
        self.waitForExpectationsWithTimeout(0.5, handler: nil)
        
    }

    func onPromiseSuccess<T : Equatable>(success:T, promiseExecutor : Executor, futureExecutor : Executor) {
        
        let promise = Promise<T>()
        let f = promise.future
        
        
        let completeExpectation = self.expectationWithDescription("Future.onComplete")
        let successExpectation = self.expectationWithDescription("Future.onSuccess")
        let anySuccessExpectation = self.expectationWithDescription("Future.onAnySuccess")
        
        
        f.onComplete(futureExecutor) { (completion) -> Void in
            
            switch completion {
            case let .Success(t):
                XCTAssert(t.result == success, "Didn't get expected success value \(success)")
                XCTAssert(completion.result == success, "Didn't get expected success value \(success)")
            default:
                XCTFail("unexpectad completion value \(completion)")
            }
            completeExpectation.fulfill()
        }
        
        f.onSuccess(futureExecutor) { (result) -> Void in
            
            XCTAssert(result == success, "Didn't get expected success value \(success)")
            successExpectation.fulfill()
            
        }
        f.onAnySuccess(futureExecutor) { (result) -> Void in
            let r = result as! T
            XCTAssert(r == success, "Didn't get expected success value \(success)")
            anySuccessExpectation.fulfill()
            
        }
        
        f.onFail(futureExecutor) { (error) -> Void in
            XCTFail("unexpectad onFail error \(error)")
            
        }
        f.onCancel(futureExecutor) { () -> Void in
            XCTFail("unexpectad onCancel" )
        }
        
        promiseExecutor.execute {
            promise.completeWithSuccess(success)
        }
        
        self.waitForExpectationsWithTimeout(0.5, handler: nil)
        
    }
    
    func testPromiseSuccess()  {


        self.onPromiseSuccess(0, promiseExecutor: .Primary, futureExecutor: .Primary)
        self.onPromiseSuccess("String", promiseExecutor: .Primary, futureExecutor: .Primary)
        self.onPromiseSuccess([1,2], promiseExecutor: .Primary, futureExecutor: .Primary)

        self.onPromiseSuccessVoid(promiseExecutor: .Primary, futureExecutor: .Primary)

    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}
