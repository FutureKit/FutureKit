//
//  PromiseTests.swift
//  FutureKit
//
//  Created by Skyler Gray on 6/25/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import FutureKit
import Foundation
import XCTest


class FKTestCase : BlockBasedTestCase {
 
    var current_expecatation_count = 0
    
    override func expectationWithDescription(description: String!) -> XCTestExpectation! {
        current_expecatation_count++
        return super.expectationWithDescription(description)
    }
    
    override func waitForExpectationsWithTimeout(timeout: NSTimeInterval, handler handlerOrNil: XCWaitCompletionHandler!) {
        super.waitForExpectationsWithTimeout(timeout, handler: handlerOrNil)
        self.current_expecatation_count = 0
        
    }

}


private enum PromiseState :  Printable, DebugPrintable {
    case NotCompleted
    case Success(Any)
    case Fail(ErrorType)
    case Cancelled
    
    var description : String {
        switch self {
        case .NotCompleted:
            return "NotCompleted"
        case let .Success(r):
            return "Success\(r)"
        case let .Fail(_):
            return "Fail"
        case .Cancelled:
            return "Cancelled"
        }
    }
    var debugDescription : String {
        return self.description
    }
    
    init(errorMessage:String) {
        self = .Fail(FutureNSError(genericError: errorMessage))
    }
    init(exception:NSException) {
        self = .Fail(FutureNSError(exception:exception))
    }
    
    
    func create<T>() -> Promise<T>   // create a promise in state
    {
        let p = Promise<T>()
        switch self {
        case .NotCompleted:
            break
        case let .Success(a):
            let result = a as! T
            p.completeWithSuccess(result)
        case let .Fail(e):
            p.completeWithFail(e)
        case .Cancelled:
            p.completeWithCancel()
        }
        return p
    }
    
    
    
    func addExpectations<T : Equatable>(promise : Promise<T>,testCase : FKTestCase,testVars: PromiseTestCase<T>, name : String) { // validate promise in this state
        let future = promise.future
        
        switch self {
        case NotCompleted:
            break
            
        case let .Success(r):
            let expectedResult = r as! T
            let futureExecuctor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectationWithDescription("OnComplete")
            let onSuccessExpectation = testCase.expectationWithDescription("OnSuccess")
            
            future.onSuccess (futureExecuctor) { (result) -> Void in
                XCTAssert(result == expectedResult, "unexpected result!")
                onSuccessExpectation.fulfill()
            }
            future.onComplete (futureExecuctor) { (completion) -> Void in
                
                switch completion {
                case let .Success(r):
                    XCTAssert(r.result == expectedResult, "unexpected result!")
                default:
                    XCTFail("completion in wrong state \(completion)")
                }
                XCTAssert(completion.state == .Success, "unexpected state!")
                XCTAssert(completion.result == expectedResult, "unexpected result!")
                XCTAssert(completion.error == nil, "unexpected error!")
                XCTAssert(completion.isSuccess == true, "unexpected state!")
                XCTAssert(completion.isFail == false, "unexpected state!")
                XCTAssert(completion.isCancelled == false, "unexpected state!")
                XCTAssert(completion.isCompleteUsing == false, "unexpected state!")
                
                onCompleteExpecation.fulfill()
            }
            
            
        case let .Fail(expectedError):
            let futureExecuctor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectationWithDescription("OnComplete")
            let onFailExpectation = testCase.expectationWithDescription("OnFail")
            
            future.onFail (futureExecuctor) { (error) -> Void in
                XCTAssert(expectedError == error, "unexpected error!")
                onFailExpectation.fulfill()
            }
            future.onComplete (futureExecuctor) { (completion) -> Void in
                
                switch completion {
                case let .Fail(error):
                    XCTAssert(error == expectedError, "unexpected result!")
                default:
                    XCTFail("completion in wrong state \(completion)")
                }
                XCTAssert(completion.state == .Fail, "unexpected state!")
                XCTAssert(completion.result == nil, "unexpected result!")
                XCTAssert(completion.error == expectedError, "unexpected error!")
                XCTAssert(completion.isSuccess == false, "unexpected state!")
                XCTAssert(completion.isFail == true, "unexpected state!")
                XCTAssert(completion.isCancelled == false, "unexpected state!")
                XCTAssert(completion.isCompleteUsing == false, "unexpected state!")
                
                onCompleteExpecation.fulfill()
            }
            
        case .Cancelled:
            let futureExecuctor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectationWithDescription("OnComplete")
            let onCancelExpectation = testCase.expectationWithDescription("OnCancel")
            
            future.onCancel (futureExecuctor) { (_) -> Void in
                onCancelExpectation.fulfill()
            }
            future.onComplete (futureExecuctor) { (completion) -> Void in
                
                switch completion {
                case .Cancelled:
                    break;
                default:
                    XCTFail("completion in wrong state \(completion)")
                }
                XCTAssert(completion.error == nil, "unexpected error \(completion)!")
                XCTAssert(completion.state == .Cancelled, "unexpected state! \(completion)")
                
                onCompleteExpecation.fulfill()
            }
        }
        
    }
    
    func validate<T : Equatable>(promise : Promise<T>,testCase : FKTestCase,testVars: PromiseTestCase<T>, name : String) { // validate promise in this state
        let future = promise.future
        
        switch self {
        case NotCompleted:
            XCTAssert(!promise.isCompleted, "Promise is not in state \(self)")
            
        default:
            break
        }
    }
}

private var _testsNumber : Int = 0
private var _dateStarted : NSDate?
private var _number_of_tests :Int = 0

func howMuchTimeLeft() -> String {
    
    if let date = _dateStarted {
        let howLongSinceWeStarted = -date.timeIntervalSinceNow
        let avg_time_per_test = howLongSinceWeStarted / Double(_testsNumber)
        let number_of_tests_left = _number_of_tests - _testsNumber
        let timeRemaining = NSTimeInterval(number_of_tests_left) * avg_time_per_test
        
        let timeWeWillFinished = NSDate(timeIntervalSinceNow: timeRemaining)
        
        let localTime = NSDateFormatter.localizedStringFromDate(timeWeWillFinished, dateStyle: .NoStyle, timeStyle: .ShortStyle)
        
        let minsRemaining = Int(timeRemaining / 60.0)
        
        return "\(minsRemaining) mins remaining. ETA:\(localTime)"
        
    }
    else {
        _dateStarted = NSDate()
        return "estimating..??"
    }
    
    
    
}

private struct PromiseFunctionTest<T : Equatable> {
    typealias TupleType = (PromiseState,PromiseFunctions,PromiseState)
    
    let initialState : PromiseState
    let functionToTest : PromiseFunctions
    let finalExpectedState : PromiseState
    
    
    init(_ initialState : PromiseState, _ functionToTest : PromiseFunctions,_ finalExpectedState : PromiseState) {
        self.initialState = initialState
        self.functionToTest = functionToTest
        self.finalExpectedState = finalExpectedState
    }
    
    var description : String {
        return "\(initialState.description)_\(functionToTest.description)_\(finalExpectedState.description)"
    }
    
    func executeTest(testCase : FKTestCase, testVars: PromiseTestCase<T>, name : String) {
        
        
        NSLog("testsNumber = \(_testsNumber) ")
        _testsNumber++
        NSLog("PromiseFunctionTest = \(howMuchTimeLeft()), \(_testsNumber)/\(_number_of_tests)")
        
        let promise : Promise<T> = initialState.create()
        
        let expectation = testCase.expectationWithDescription("testFinished")
        
        let funcExpectation = self.functionToTest.addExpectation(testCase)
        self.finalExpectedState.addExpectations(promise,testCase: testCase,testVars: testVars, name :name)

        testVars.promiseExecutor.execute { () -> Void in
            self.functionToTest.executeWith(promise,test: testVars,testCase:testCase,expectation: funcExpectation)
            
            testVars.promiseExecutor.execute { () -> Void in
                
                self.finalExpectedState.validate(promise,testCase: testCase,testVars: testVars, name :name)
                expectation.fulfill()
            }
            
        }
        
        testCase.waitForExpectationsWithTimeout(maxWaitForExpecations, handler: nil)
        
        _testsNumber++
        
        
    }

}

let maxWaitForExpecations : NSTimeInterval = 5.0

private struct PromiseTestCase<T : Equatable> {

    let functionTest : PromiseFunctionTest<T>
    let promiseExecutor: Executor
    let futureExecutor: Executor
    
    var description : String {
        return "\(functionTest.description)_\(promiseExecutor.description)_\(futureExecutor.description)"
    }
    
    func executeTest(testCase : FKTestCase, name : String) {
        self.functionTest.executeTest(testCase, testVars: self, name: name)
    }
}

extension PromiseFunctionTest {
    
    static func createAllTheTests(result:T, result2:T, promiseExecutor:Executor,futureExecutor:Executor) -> [PromiseFunctionTest] {
        
        var tests = [PromiseFunctionTest]()
        let error = NSError(domain: "PromiseFunctionTest", code: -1, userInfo: nil)
        let error2 = NSError(domain: "PromiseFunctionTest 2", code: -2, userInfo: nil)
        let errorMessage = "PromiseFunctionTest Error Message!"
        let errorMessage2 = "PromiseFunctionTest Error Message 2!"
        
        let exception = NSException(name: "PromiseFunctionTest", reason: "Reason 1", userInfo: nil)
        let exception2 = NSException(name: "PromiseFunctionTest 2", reason: "Reason 2", userInfo: nil)
        
        let successFuture = Future<T>(success:result)
        let failedFuture = Future<T>(failed:error)
        let cancelledFuture = Future<T>(cancelled:())
        let promiseForUnfinishedFuture = Promise<T>()
        let unfinishedFuture = promiseForUnfinishedFuture.future
        
        
        let failErrorMessage = PromiseState(errorMessage: errorMessage)
        let failException = PromiseState(exception:exception)

        
        let futureDelay: NSTimeInterval = 2.0
        let blockThatMakesDelayedFuture = { (delay : NSTimeInterval, completion:Completion<T>) -> Future<T> in
            let p = Promise<T>()
            promiseExecutor.executeAfterDelay(delay) {
                p.complete(completion)
            }
            return p.future
        }
        let blockThatMakesDelayedDelayedFuture = { (delay : NSTimeInterval, future:Future<T>) -> Future<T> in
            let p = Promise<T>()
            
            promiseExecutor.executeAfterDelay(delay) {
                p.completeUsingFuture(future)
            }
            return p.future
        }
        
        let autoDelay = NSTimeInterval(0.2)

        tests.append(PromiseFunctionTest(.NotCompleted,    .automaticallyCancelAfter(autoDelay), .NotCompleted))
        tests.append(PromiseFunctionTest(.NotCompleted,    .automaticallyCancelAfter(autoDelay), .Cancelled))
        tests.append(PromiseFunctionTest(.Success(result), .automaticallyCancelAfter(autoDelay), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .automaticallyCancelAfter(autoDelay), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .automaticallyCancelAfter(autoDelay), .Cancelled))

        
        tests.append(PromiseFunctionTest(.NotCompleted,    .automaticallyFailAfter(autoDelay, error), .NotCompleted))
        tests.append(PromiseFunctionTest(.NotCompleted,    .automaticallyFailAfter(autoDelay, error), .Fail(error)))
        tests.append(PromiseFunctionTest(.Success(result), .automaticallyFailAfter(autoDelay, error), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .automaticallyFailAfter(autoDelay, error2), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .automaticallyFailAfter(autoDelay, error), .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(SUCCESS(result)),  .Success(result)))
        tests.append(PromiseFunctionTest(.Success(result), .complete(SUCCESS(result2)), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(SUCCESS(result)),  .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(SUCCESS(result)),  .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(FAIL(error)),  .Fail(error)))
        tests.append(PromiseFunctionTest(.Success(result), .complete(FAIL(error)),  .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(FAIL(error2)), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(FAIL(error)),  .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(CANCELLED()),  .Cancelled))
        tests.append(PromiseFunctionTest(.Success(result), .complete(CANCELLED()),  .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(CANCELLED()),  .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(CANCELLED()),  .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(COMPLETE_USING(successFuture).As()), .Success(result)))
        tests.append(PromiseFunctionTest(.Success(result2),.complete(COMPLETE_USING(successFuture).As()), .Success(result2)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(COMPLETE_USING(successFuture).As()), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(COMPLETE_USING(successFuture).As()), .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(COMPLETE_USING(failedFuture).As()), .Fail(error)))
        tests.append(PromiseFunctionTest(.Success(result), .complete(COMPLETE_USING(failedFuture).As()), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error2),    .complete(COMPLETE_USING(failedFuture).As()), .Fail(error2)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(COMPLETE_USING(failedFuture).As()), .Cancelled))

        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(COMPLETE_USING(cancelledFuture).As()), .Cancelled))
        tests.append(PromiseFunctionTest(.Success(result), .complete(COMPLETE_USING(cancelledFuture).As()), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(COMPLETE_USING(cancelledFuture).As()), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(COMPLETE_USING(cancelledFuture).As()), .Cancelled))
        
        tests.append(PromiseFunctionTest(.NotCompleted,    .complete(COMPLETE_USING(unfinishedFuture).As()), .NotCompleted))
        tests.append(PromiseFunctionTest(.Success(result), .complete(COMPLETE_USING(unfinishedFuture).As()), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error),     .complete(COMPLETE_USING(unfinishedFuture).As()), .Fail(error)))
        tests.append(PromiseFunctionTest(.Cancelled,       .complete(COMPLETE_USING(unfinishedFuture).As()), .Cancelled))


        
        tests.append(PromiseFunctionTest(.NotCompleted,    .completeWithSuccess(result),  .Success(result)))
        tests.append(PromiseFunctionTest(.Success(result), .completeWithSuccess(result2), .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted,    .completeWithFail(error),  .Fail(error)))
        tests.append(PromiseFunctionTest(.Fail(error),     .completeWithFail(error2), .Fail(error)))

        tests.append(PromiseFunctionTest(.NotCompleted,    .completeWithFailErrorMessage(errorMessage), failErrorMessage))
        tests.append(PromiseFunctionTest(failErrorMessage, .completeWithFailErrorMessage(errorMessage2), failErrorMessage))

        tests.append(PromiseFunctionTest(.NotCompleted,    .completeWithException(exception),  failException))
        tests.append(PromiseFunctionTest(failException,    .completeWithException(exception2), failException))

        tests.append(PromiseFunctionTest(.NotCompleted,    .completeWithCancel, .Cancelled))
        tests.append(PromiseFunctionTest(.Success(result), .completeWithCancel, .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeUsingFuture(successFuture), .Success(result)))
        tests.append(PromiseFunctionTest(.Success(result2), .completeUsingFuture(successFuture), .Success(result2)))
        tests.append(PromiseFunctionTest(.Fail(error),      .completeUsingFuture(successFuture), .Fail(error)))

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeUsingFuture(failedFuture), .Fail(error)))
        
        let successBlock = { () -> Completion<Any> in
            return SUCCESS(result)
        }
        let failBlock = { () -> Completion<Any> in
            return FAIL(error)
        }
        
        let delayedSuccessBlock =  { () -> Completion<Any> in
            let f = blockThatMakesDelayedFuture(autoDelay,SUCCESS(result))
            
            return .CompleteUsing(f.As())
        }

        let extraDelayedSuccessBlock =  { () -> Completion<Any> in
            let f = blockThatMakesDelayedFuture(autoDelay,SUCCESS(result))
            let f2 = blockThatMakesDelayedFuture(autoDelay,COMPLETE_USING(f))
            
            return .CompleteUsing(f2.As())
        }
        let extraDelayedFailBlock =  { () -> Completion<Any> in
            let f = blockThatMakesDelayedFuture(autoDelay,FAIL(error))
            let f2 = blockThatMakesDelayedFuture(autoDelay,COMPLETE_USING(f))
            
            return .CompleteUsing(f2.As())
        }
        

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(successBlock), .Success(result)))
        tests.append(PromiseFunctionTest(.Success(result2), .completeWithBlock(successBlock), .Success(result2)))
        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(failBlock),    .Fail(error)))
        tests.append(PromiseFunctionTest(.Success(result),  .completeWithBlock(failBlock),    .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(delayedSuccessBlock), .NotCompleted))
        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(delayedSuccessBlock), .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(extraDelayedSuccessBlock), .Success(result)))
        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(extraDelayedFailBlock), .Fail(error)))

        tests.append(PromiseFunctionTest(.NotCompleted,     .completeWithBlock(extraDelayedFailBlock), .Fail(error)))
        

        let testSetupNoExpecataion = { (testCase:FKTestCase) -> XCTestExpectation? in
            return nil
        }
        let testSetupWithExpecataion = { (testCase:FKTestCase) -> XCTestExpectation? in
            return testCase.expectationWithDescription("expect already block to run")
        }
        
        tests.append(PromiseFunctionTest(.NotCompleted, .completeWithBlocksOnAlreadyCompleted(successBlock,true), .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted, .completeWithBlocksOnAlreadyCompleted(failBlock,true), .Fail(error)))

        tests.append(PromiseFunctionTest(.Success(result2), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .Success(result2)))
        
        tests.append(PromiseFunctionTest(.Success(result), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .Success(result)))

        tests.append(PromiseFunctionTest(.Fail(error), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .Fail(error)))

        tests.append(PromiseFunctionTest(.Fail(error2), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .Fail(error2)))

        
        tests.append(PromiseFunctionTest(.NotCompleted, .tryComplete(SUCCESS(result),true), .Success(result)))

        tests.append(PromiseFunctionTest(.NotCompleted, .tryComplete(FAIL(error),true), .Fail(error)))

        tests.append(PromiseFunctionTest(.Success(result2), .tryComplete(SUCCESS(result),false), .Success(result2)))
        tests.append(PromiseFunctionTest(.Success(result), .tryComplete(FAIL(error),false), .Success(result)))
        tests.append(PromiseFunctionTest(.Fail(error), .tryComplete(SUCCESS(result),false), .Fail(error)))
        tests.append(PromiseFunctionTest(.Fail(error2), .tryComplete(FAIL(error),false), .Fail(error2)))

        
        tests.append(PromiseFunctionTest(.NotCompleted, .completeWithBlocksOnAlreadyCompleted(failBlock,true), .Fail(error)))
        
        tests.append(PromiseFunctionTest(.Success(result2), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .Success(result2)))
        
        tests.append(PromiseFunctionTest(.Success(result), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .Success(result)))
        
        tests.append(PromiseFunctionTest(.Fail(error), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .Fail(error)))
        
        tests.append(PromiseFunctionTest(.Fail(error2), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .Fail(error2)))

        
        
        return tests
        
    }
}



private enum PromiseFunctions {
    
    
    case automaticallyCancelAfter(NSTimeInterval)
    case automaticallyFailAfter(NSTimeInterval,ErrorType)
    
//    case automaticallyAssertOnFail(NSTimeInterval)  // can't test assert
  
    // TODO: Test Cancelation Requests
//    case onRequestCancelExecutor(CancelRequestHandler)
//    case onRequestCancel(CancelRequestHandler)
    
//    case automaticallyCancelOnRequestCancel
    
    case complete(Completion<Any>)
    case completeWithSuccess(Any)
    case completeWithFail(ErrorType)
    case completeWithFailErrorMessage(String)
    case completeWithException(NSException)
    case completeWithCancel
    case completeUsingFuture(FutureProtocol)
    
    case completeWithBlock(()->Completion<Any>)
    //  The block is executed.  The Bool should be TRUE is we expect that the completeWithBlocks will succeed.
    case completeWithBlocksOnAlreadyCompleted(()->Completion<Any>,Bool)
    
    case failIfNotCompleted(ErrorType)
    case failIfNotCompletedErrorMessage(String)
    
    case tryComplete(Completion<Any>,Bool)     // The Bool should be TRUE is we expect that the tryComplete will succeed.
    case completeWithOnCompletionError(Completion<Any>,Bool)  // last value is TRUE if we expect the completion to succeed
    
    
    
    func addExpectation(testCase : FKTestCase) -> XCTestExpectation? {
        
        switch self {
            
        case let .completeWithBlocksOnAlreadyCompleted(_,completeWillSucceed):
            if (!completeWillSucceed) {
                return testCase.expectationWithDescription("we expect OnAlreadyCompleted to be executed")
            }
            else {
                return nil
            }

        case let .completeWithOnCompletionError(_,completeWillSucceed):
            if (!completeWillSucceed) {
                return testCase.expectationWithDescription("we expect OnCompletionError to be executed")
            }
            else {
                return nil
            }
            
            
        default:
            return nil
        }
        
    }
    
    
    func executeWith<T>(promise : Promise<T>,test : PromiseTestCase<T>, testCase : FKTestCase, expectation:XCTestExpectation?)
    
    {
        switch self {
            
        case let .automaticallyCancelAfter(delay):
            promise.automaticallyCancelAfter(delay)

        case let .automaticallyFailAfter(delay,error):
            promise.automaticallyFailAfter(delay,error:error)

/*        case let .onRequestCancelExecutor(handler):
            promise.onRequestCancel(test.promiseExecutor, handler: handler)
            
        case let .onRequestCancel(handler):
            promise.onRequestCancel(handler)

        case .automaticallyCancelOnRequestCancel:
            promise.automaticallyCancelOnRequestCancel() */


        case let .complete(completion):
            promise.complete(completion.As())

            
        case let .completeWithSuccess(r):
            let result = r as! T
            promise.completeWithSuccess(result)

        case let .completeWithFail(error):
            promise.completeWithFail(error)

        case let .completeWithFailErrorMessage(message):
            promise.completeWithFail(message)
            
        case let .completeWithException(exception):
            promise.completeWithException(exception)

        case .completeWithCancel:
            promise.completeWithCancel()

        case let .completeUsingFuture(future):
            promise.completeUsingFuture(future.As())

        case let .completeWithBlock(block):
            promise.completeWithBlock { () -> Completion<T> in
                return block().As()
            }
            
        case let .completeWithBlocksOnAlreadyCompleted(completeBlock,_):
            promise.completeWithBlocks( { () -> Completion<T> in
                return completeBlock().As()
                }, onAlreadyCompleted: { () -> Void in
                    if let ex = expectation {
                        ex.fulfill()
                    }
                    else {
                        XCTFail("we did not expect onAlreadyCompleted to be executed!")
                    }
                }
            )

        case let .failIfNotCompleted(error):
            promise.failIfNotCompleted(error)

        case let .failIfNotCompletedErrorMessage(message):
            promise.failIfNotCompleted(message)


        case let .tryComplete(completion,expectedReturnValue):
            let r = promise.tryComplete(completion.As())
            XCTAssert(r == expectedReturnValue, "tryComplete returned \(r)")

        case let .completeWithOnCompletionError(completion,_):
            promise.complete(completion.As(),onCompletionError: { () -> Void in
                if let ex = expectation {
                    ex.fulfill()
                }
                else {
                    XCTFail("we did not expect onAlreadyCompleted to be executed!")
                }
            })

        }
    }

    var description : String
        
    {
        switch self {
            
        case let .automaticallyCancelAfter(delay):
            return "automaticallyCancelAfter\(delay)"
            
        case let .automaticallyFailAfter(delay,error):
            return "automaticallyFailAfter\(delay)"
            
            /*        case let .onRequestCancelExecutor(handler):
            return "onRequestCancel(test.promiseExecutor, handler: handler)
            
            case let .onRequestCancel(handler):
            return "onRequestCancel(handler)
            
            case .automaticallyCancelOnRequestCancel:
            return "automaticallyCancelOnRequestCancel() */
            
            
        case let .complete(completion):
            switch completion {
            case let .Success(r):
                return "complete_Success_\(r.result)"
            case let .Fail(e):
                return "complete_Fail_\(e.code)"
            case .Cancelled:
                return "complete_Cancelled"
            case let .CompleteUsing(f):
                return "complete_CompleteUsing"
            }
            
            
        case let .completeWithSuccess(r):
            return "completeWithSuccess\(r)"
            
        case let .completeWithFail(error):
            return "completeWithFail"
            
        case let .completeWithFailErrorMessage(message):
            return "completeWithFailErrorMessage"
            
        case let .completeWithException(exception):
            return "completeWithException"
            
        case .completeWithCancel:
            return "completeWithCancel"
            
        case let .completeUsingFuture(future):
            return "completeUsingFuture)"
            
        case let .completeWithBlock(block):
            return "completeWithBlock"
            
            
        case let .completeWithBlocksOnAlreadyCompleted(_,_):
            return "completeWithBlocksOnAlreadyCompleted"
            
        case let .failIfNotCompleted(error):
            return "failIfNotCompleted"
            
        case let .failIfNotCompletedErrorMessage(message):
            return "failIfNotCompletedErrorMessage"
            
            
        case let .tryComplete(completion,_):
            return "tryComplete\(completion.state)"
            
        case let .completeWithOnCompletionError(_,_):
            return "completeWithOnCompletionError"
            
        }
    }
}
    



class PromiseTests: FKTestCase {
    

    class func testsFor<T : Equatable>(result:T, result2:T) -> [BlockBasedTest] {
        
        
        let custom : Executor.CustomCallBackBlock = { (callback) -> Void in
            Executor.Background.execute {
                Executor.Main.execute {
                    callback()
                }
            }
        }
        
        let opQueue = NSOperationQueue()
        opQueue.maxConcurrentOperationCount = 2
        
        let q = dispatch_queue_create("custom q", DISPATCH_QUEUE_CONCURRENT)
        
        let old_executors : [Executor] = [.Primary, .Main, .Async, .Current, .Immediate, .StackCheckingImmediate, .MainAsync, .MainImmediate, .UserInteractive, .UserInitiated, .Default,  .Utility, .Background, .OperationQueue(opQueue), .Custom(custom), .Queue(q)]

        let executors : [Executor] = [
            .Main,
            .Current,
            .MainAsync,
            .MainImmediate,
            .Default,
            .Immediate,
            .Background,
            .StackCheckingImmediate,
            .OperationQueue(opQueue),
            .Custom(custom),
            .Queue(q)]
        
        let future_executors : [Executor] = [.MainAsync, .MainImmediate]

        
        var blockTests = [BlockBasedTest]()
        
        let setOfCharsWeGottaGetRidOf = NSCharacterSet(charactersInString: ".(),\n\t {}[];:=-")
        
        for promiseE in executors {
            for futureE in executors {
                
                let tests = PromiseFunctionTest<T>.createAllTheTests(result,result2: result2,promiseExecutor: promiseE,futureExecutor: futureE)
                
                
                for (index,t) in enumerate(tests) {
                    
                    let tvars = PromiseTestCase<T>(functionTest:t,
                        promiseExecutor:promiseE,
                        futureExecutor:futureE)
                    
                    let n: NSString = "test_\(index)_\(T.self)_\(result)_\(tvars.description)"
                    
                    let c : NSArray = n.componentsSeparatedByCharactersInSet(setOfCharsWeGottaGetRidOf)
                    let name = c.componentsJoinedByString("")

                    let t = self.addTest(name, closure: { (_self : PromiseTests) -> Void in
                        tvars.executeTest(_self, name: name)
                    })!
                    blockTests.append(t)
                    
                }
                
                
                
            }
        }
        
        

        return blockTests
        
    }
    
    override class func myBlockBasedTests() -> [AnyObject] {
        var tests = [BlockBasedTest]()
        
//        let v: () = ()
//        tests += self.testsFor(v, result2: v)
        
        tests += self.testsFor(["Bob" : 1.0],result2: ["Jane" : 2.0])

        tests += self.testsFor(Int(0),result2: Int(1))

        tests += self.testsFor(String("Hi"),result2: String("Bye"))
        
        tests += self.testsFor(Float(0.0),result2: Float(1.0))

        // array
        tests += self.testsFor([0.0,1.0],result2: [2.0,3.0])

        // dictionary

        _number_of_tests = tests.count
        return tests
    }
    

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

