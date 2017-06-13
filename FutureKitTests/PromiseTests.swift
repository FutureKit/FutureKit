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

    override func expectation(description: String) -> XCTestExpectation {
        current_expecatation_count += 1
        return super.expectation(description: description)
    }
    
    override func waitForExpectations(timeout: TimeInterval, handler handlerOrNil: XCWaitCompletionHandler!) {
        super.waitForExpectations(timeout: timeout, handler: handlerOrNil)
        self.current_expecatation_count = 0
        
    }

}


private enum PromiseState<T : Equatable> :  CustomStringConvertible, CustomDebugStringConvertible {
    case notCompleted
    case success(T)
    case fail(FutureKitError)
    case cancelled
    
    var description : String {
        switch self {
        case .notCompleted:
            return "NotCompleted"
        case let .success(r):
            return "Success(\(r))"
        case let .fail(e):
            return "Fail(\(e))"
        case .cancelled:
            return "Cancelled"
        }
    }
    var debugDescription : String {
        return self.description
    }
    
    init(errorMessage:String) {
        self = .fail(FutureKitError.genericError(errorMessage))
    }
    init(exception:NSException) {
        self = .fail(FutureKitError.exceptionCaught(exception,nil))
    }
    
    
    func create() -> Promise<T>   // create a promise in state
    {
        let p = Promise<T>()
        switch self {
        case .notCompleted:
            break
        case let .success(result):
            p.completeWithSuccess(result)
        case let .fail(e):
            p.completeWithFail(e)
        case .cancelled:
            p.completeWithCancel()
        }
        return p
    }
    
    
    
    func addExpectations(_ promise : Promise<T>,testCase : FKTestCase,testVars: PromiseTestCase<T>, name : String) { // validate promise in this state
        let future = promise.future
        
        switch self {
        case .notCompleted:
            break
            
        case let .success(expectedValue):
            let futureExecuctor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectation(description: "OnComplete")
            let onSuccessExpectation = testCase.expectation(description: "OnSuccess")


            future.onComplete (futureExecuctor) { (result) -> Void in
                
                switch result {
                case let .success(value):
                    XCTAssert(value == expectedValue, "unexpected result!")
                default:
                    XCTFail("completion with wrong value \(result)")
                }
                XCTAssert(result.value == expectedValue, "unexpected result!")
                XCTAssert(result.error == nil, "unexpected error!")
                XCTAssert(result.isSuccess == true, "unexpected state!")
                XCTAssert(result.isFail == false, "unexpected state!")
                XCTAssert(result.isCancelled == false, "unexpected state!")
                
                onCompleteExpecation.fulfill()
            }
            .ignoreFailures()
            
            future.onSuccess (futureExecuctor) { (value) -> Void in
                XCTAssert(value == expectedValue, "unexpected result!")
                onSuccessExpectation.fulfill()
            }
            .ignoreFailures()
            
            future.onCancel(futureExecuctor) { () -> Void in
                XCTFail("Did not expect onCancel")
            }
            future.onFail (futureExecuctor) { (error) -> Void in
                XCTFail("Did not expect onFail \(error)")
            }
            
        case let .fail(expectedError):
            let futureExecuctor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectation(description: "OnComplete")
            let onFailExpectation = testCase.expectation(description: "OnFail")
            
            future.onComplete (futureExecuctor) { (result) -> Void in
                
                switch result {
                case let .fail(error):
                    let nserror = error as! FutureKitError
                    XCTAssert(nserror == expectedError, "unexpected error! [\(nserror)]\n expected [\(expectedError)]")
                default:
                    XCTFail("completion with wrong value \(result)")
                }
                XCTAssert(result.value == nil, "unexpected result!")
                let cnserror = result.error as! FutureKitError
                XCTAssert(cnserror == expectedError, "unexpected error! \(cnserror) expected \(expectedError)")
                XCTAssert(result.isSuccess == false, "unexpected state!")
                XCTAssert(result.isFail == true, "unexpected state!")
                XCTAssert(result.isCancelled == false, "unexpected state!")
                
                onCompleteExpecation.fulfill()
            }
            .ignoreFailures()
            future.onSuccess (futureExecuctor) { (value) -> Void in
                XCTFail("Did not expect onSuccess \(value)")
            }.ignoreFailures()
            future.onCancel(futureExecuctor) { () -> Void in
                XCTFail("Did not expect onCancel")
            }
            future.onFail (futureExecuctor) { (error) -> Void in
                let nserror = error as! FutureKitError
                XCTAssert(nserror == expectedError, "unexpected error! [\(nserror)]\n expected [\(expectedError)]")
                onFailExpectation.fulfill()
            }

            
        case .cancelled:
            let futureExecutor = testVars.futureExecutor
            
            let onCompleteExpecation = testCase.expectation(description: "OnComplete")
            let onCancelExpectation = testCase.expectation(description: "OnCancel")
            
            future.onComplete (futureExecutor) { (result) -> Void in
                
                switch result {
                case .cancelled:
                    break;
                default:
                    XCTFail("completion with wrong value \(result)")
                }
                XCTAssert(result.error == nil, "unexpected error \(result)!")
                XCTAssert(result.isCancelled, "unexpected state! \(result)")
                
                onCompleteExpecation.fulfill()
            }.ignoreFailures()
            future.onSuccess (futureExecutor) { (value) -> Void in
                XCTFail("Did not expect onSuccess \(value)")
            }.ignoreFailures()
            future.onCancel (futureExecutor) { () -> Void in
                onCancelExpectation.fulfill()
            }
            future.onFail (futureExecutor) { (error) -> Void in
                XCTFail("Did not expect onFail \(error)")
            }

        }
        
    }
    
    func validate(_ promise : Promise<T>,testCase : FKTestCase,testVars: PromiseTestCase<T>, name : String) { // validate promise in this state
        
        switch self {
        case .notCompleted:
            XCTAssert(!promise.isCompleted, "Promise is not in state \(self)")
            
        default:
            break
        }
    }
}

private var _testsNumber : Int = 0
private var _dateStarted : Date?
private var _number_of_tests :Int = 0

func howMuchTimeLeft() -> String {
    
    if let date = _dateStarted {
        let howLongSinceWeStarted = -date.timeIntervalSinceNow
        let avg_time_per_test = howLongSinceWeStarted / Double(_testsNumber)
        let number_of_tests_left = _number_of_tests - _testsNumber
        let timeRemaining = TimeInterval(number_of_tests_left) * avg_time_per_test
        
        let timeWeWillFinished = Date(timeIntervalSinceNow: timeRemaining)
        
        let localTime = DateFormatter.localizedString(from: timeWeWillFinished, dateStyle: .none, timeStyle: .short)
        
        let minsRemaining = Int(timeRemaining / 60.0)
        
        return "\(minsRemaining) mins remaining. ETA:\(localTime)"
        
    }
    else {
        _dateStarted = Date()
        return "estimating..??"
    }
    
    
    
}

private struct PromiseFunctionTest<T : Equatable> {
    typealias TupleType = (PromiseState<T>,PromiseFunctions<T>,PromiseState<T>)
    
    let initialState : PromiseState<T>
    let functionToTest : PromiseFunctions<T>
    let finalExpectedState : PromiseState<T>
    
    
    init(_ initialState : PromiseState<T>, _ functionToTest : PromiseFunctions<T>,_ finalExpectedState : PromiseState<T>) {
        self.initialState = initialState
        self.functionToTest = functionToTest
        self.finalExpectedState = finalExpectedState
    }
    
    var description : String {
        return "\(initialState.description)_\(functionToTest.description)_\(finalExpectedState.description)"
    }
    
    func executeTest(_ testCase : FKTestCase, testVars: PromiseTestCase<T>, name : String) {
        
        
        NSLog("testsNumber = \(_testsNumber) ")
        _testsNumber += 1
        NSLog("PromiseFunctionTest = \(howMuchTimeLeft()), \(_testsNumber)/\(_number_of_tests)")
        
        let promise : Promise<T> = initialState.create()
        
        let expectation = testCase.expectation(description: "testFinished")
        
        let funcExpectation = self.functionToTest.addExpectation(testCase)
        self.finalExpectedState.addExpectations(promise,testCase: testCase,testVars: testVars, name :name)

        testVars.promiseExecutor.execute { () -> Void in
            self.functionToTest.executeWith(promise,test: testVars,testCase:testCase,expectation: funcExpectation)
            
            testVars.promiseExecutor.execute { () -> Void in
                
                self.finalExpectedState.validate(promise,testCase: testCase,testVars: testVars, name :name)
                expectation.fulfill()
            }
            
        }
        
        testCase.waitForExpectations(timeout: maxWaitForExpecations, handler: nil)
        
    }

}

let maxWaitForExpecations : TimeInterval = 5.0

private struct PromiseTestCase<T : Equatable> {

    let functionTest : PromiseFunctionTest<T>
    let promiseExecutor: Executor
    let futureExecutor: Executor
    
    var description : String {
        return "\(functionTest.description)_\(promiseExecutor.description)_\(futureExecutor.description)"
    }
    
    func executeTest(_ testCase : FKTestCase, name : String) {
        self.functionTest.executeTest(testCase, testVars: self, name: name)
    }
}

extension PromiseFunctionTest {
    
    static func createAllTheTests(_ result:T, result2:T, promiseExecutor:Executor,futureExecutor:Executor) -> [PromiseFunctionTest] {
        
        var tests = [PromiseFunctionTest]()
        let error : FutureKitError = .genericError("PromiseFunctionTest")
        let error2 : FutureKitError = .genericError("PromiseFunctionTest2")
        let errorMessage = "PromiseFunctionTest Error Message!"
        let errorMessage2 = "PromiseFunctionTest Error Message 2!"
        
        let exception = NSException(name: NSExceptionName(rawValue: "PromiseFunctionTest"), reason: "Reason 1", userInfo: nil)
        let exception2 = NSException(name: NSExceptionName(rawValue: "PromiseFunctionTest 2"), reason: "Reason 2", userInfo: nil)
        
        let successFuture = Future<T>(success:result)
        let failedFuture = Future<T>(fail:error)
        let cancelledFuture = Future<T>(cancelled:())
        let promiseForUnfinishedFuture = Promise<T>()
        let unfinishedFuture = promiseForUnfinishedFuture.future
        
        
        let failErrorMessage = PromiseState<T>(errorMessage: errorMessage)
        let failException = PromiseState<T>(exception:exception)

        
        let blockThatMakesDelayedFuture = { (delay : TimeInterval, completion:Completion<T>) -> Future<T> in
            let p = Promise<T>()
            promiseExecutor.execute(afterDelay:delay) {
                p.complete(completion)
            }
            return p.future
        }
        
        let autoDelay = TimeInterval(0.1)

        tests.append(PromiseFunctionTest<T>(.notCompleted,    .automaticallyCancelAfter(autoDelay), .notCompleted))
        
        
        tests.append(PromiseFunctionTest(.notCompleted,    .automaticallyCancelAfter(autoDelay), .cancelled))
        tests.append(PromiseFunctionTest(.success(result), .automaticallyCancelAfter(autoDelay), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .automaticallyCancelAfter(autoDelay), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .automaticallyCancelAfter(autoDelay), .cancelled))

        
        tests.append(PromiseFunctionTest(.notCompleted,    .automaticallyFailAfter(autoDelay, error), .notCompleted))
        tests.append(PromiseFunctionTest(.notCompleted,    .automaticallyFailAfter(autoDelay, error), .fail(error)))
        tests.append(PromiseFunctionTest(.success(result), .automaticallyFailAfter(autoDelay, error), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .automaticallyFailAfter(autoDelay, error2), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .automaticallyFailAfter(autoDelay, error), .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.success(result)),  .success(result)))
        tests.append(PromiseFunctionTest(.success(result), .complete(.success(result2)), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.success(result)),  .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.success(result)),  .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.fail(error)),  .fail(error)))
        tests.append(PromiseFunctionTest(.success(result), .complete(.fail(error)),  .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.fail(error2)), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.fail(error)),  .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.cancelled),  .cancelled))
        tests.append(PromiseFunctionTest(.success(result), .complete(.cancelled),  .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.cancelled),  .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.cancelled),  .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.completeUsing(successFuture)),.success(result)))
        tests.append(PromiseFunctionTest(.success(result2),.complete(.completeUsing(successFuture)), .success(result2)))
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.completeUsing(successFuture)), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.completeUsing(successFuture)), .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.completeUsing(failedFuture)), .fail(error)))
        tests.append(PromiseFunctionTest(.success(result), .complete(.completeUsing(failedFuture)), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error2),    .complete(.completeUsing(failedFuture)), .fail(error2)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.completeUsing(failedFuture)), .cancelled))

        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.completeUsing(cancelledFuture)), .cancelled))
        tests.append(PromiseFunctionTest(.success(result), .complete(.completeUsing(cancelledFuture)), .success(result)))
        
        
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.completeUsing(cancelledFuture)), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.completeUsing(cancelledFuture)), .cancelled))
        
        tests.append(PromiseFunctionTest(.notCompleted,    .complete(.completeUsing(unfinishedFuture)), .notCompleted))
        tests.append(PromiseFunctionTest(.success(result), .complete(.completeUsing(unfinishedFuture)), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error),     .complete(.completeUsing(unfinishedFuture)), .fail(error)))
        tests.append(PromiseFunctionTest(.cancelled,       .complete(.completeUsing(unfinishedFuture)), .cancelled))


        
        tests.append(PromiseFunctionTest(.notCompleted,    .completeWithSuccess(result),  .success(result)))
        tests.append(PromiseFunctionTest(.success(result), .completeWithSuccess(result2), .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted,    .completeWithFail(error),  .fail(error)))
        tests.append(PromiseFunctionTest(.fail(error),     .completeWithFail(error2), .fail(error)))

        tests.append(PromiseFunctionTest(.notCompleted,    .completeWithFailErrorMessage(errorMessage), failErrorMessage))
        tests.append(PromiseFunctionTest(failErrorMessage, .completeWithFailErrorMessage(errorMessage2), failErrorMessage))

        tests.append(PromiseFunctionTest(.notCompleted,    .completeWithException(exception),  failException))
        tests.append(PromiseFunctionTest(failException,    .completeWithException(exception2), failException))

        tests.append(PromiseFunctionTest(.notCompleted,    .completeWithCancel, .cancelled))
        tests.append(PromiseFunctionTest(.success(result), .completeWithCancel, .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted,     .completeUsingFuture(successFuture), .success(result)))
        tests.append(PromiseFunctionTest(.success(result2), .completeUsingFuture(successFuture), .success(result2)))
        tests.append(PromiseFunctionTest(.fail(error),      .completeUsingFuture(successFuture), .fail(error)))

        tests.append(PromiseFunctionTest(.notCompleted,     .completeUsingFuture(failedFuture), .fail(error)))
        
        let successBlock = { () -> Completion<T> in
            return .success(result)
        }
        let failBlock = { () -> Completion<T> in
            return .fail(error)
        }
        
        let delayedSuccessBlock =  { () -> Completion<T> in
            let f = blockThatMakesDelayedFuture(autoDelay,.success(result))
            
            return .completeUsing(f)
        }

        let extraDelayedSuccessBlock =  { () -> Completion<T> in
            let f = blockThatMakesDelayedFuture(autoDelay,.success(result))
            let f2 = blockThatMakesDelayedFuture(autoDelay,.completeUsing(f))
            
            return .completeUsing(f2)
        }
        let extraDelayedFailBlock =  { () -> Completion<T> in
            let f = blockThatMakesDelayedFuture(autoDelay,.fail(error))
            let f2 = blockThatMakesDelayedFuture(autoDelay,.completeUsing(f))
            
            return .completeUsing(f2)
        }
        

        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(successBlock), .success(result)))
        tests.append(PromiseFunctionTest(.success(result2), .completeWithBlock(successBlock), .success(result2)))
        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(failBlock),    .fail(error)))
        tests.append(PromiseFunctionTest(.success(result),  .completeWithBlock(failBlock),    .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(delayedSuccessBlock), .notCompleted))
        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(delayedSuccessBlock), .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(extraDelayedSuccessBlock), .success(result)))
        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(extraDelayedFailBlock), .fail(error)))

        tests.append(PromiseFunctionTest(.notCompleted,     .completeWithBlock(extraDelayedFailBlock), .fail(error)))
        
        tests.append(PromiseFunctionTest(.notCompleted, .completeWithBlocksOnAlreadyCompleted(successBlock,true), .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted, .completeWithBlocksOnAlreadyCompleted(failBlock,true), .fail(error)))

        tests.append(PromiseFunctionTest(.success(result2), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .success(result2)))
        
        tests.append(PromiseFunctionTest(.success(result), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .success(result)))

        tests.append(PromiseFunctionTest(.fail(error), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .fail(error)))

        tests.append(PromiseFunctionTest(.fail(error2), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .fail(error2)))

        
        tests.append(PromiseFunctionTest(.notCompleted, .tryComplete(.success(result),true), .success(result)))

        tests.append(PromiseFunctionTest(.notCompleted, .tryComplete(.fail(error),true), .fail(error)))

        tests.append(PromiseFunctionTest(.success(result2), .tryComplete(.success(result),false), .success(result2)))
        tests.append(PromiseFunctionTest(.success(result), .tryComplete(.fail(error),false), .success(result)))
        tests.append(PromiseFunctionTest(.fail(error), .tryComplete(.success(result),false), .fail(error)))
        tests.append(PromiseFunctionTest(.fail(error2), .tryComplete(.fail(error),false), .fail(error2)))

        
        tests.append(PromiseFunctionTest(.notCompleted, .completeWithBlocksOnAlreadyCompleted(failBlock,true), .fail(error)))
        
        tests.append(PromiseFunctionTest(.success(result2), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .success(result2)))
        
        tests.append(PromiseFunctionTest(.success(result), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .success(result)))
        
        tests.append(PromiseFunctionTest(.fail(error), .completeWithBlocksOnAlreadyCompleted(successBlock,false), .fail(error)))
        
        tests.append(PromiseFunctionTest(.fail(error2), .completeWithBlocksOnAlreadyCompleted(failBlock,false), .fail(error2)))

        
        
        return tests
        
    }
}



private enum PromiseFunctions<T : Equatable> {
    
    
    case automaticallyCancelAfter(TimeInterval)
    case automaticallyFailAfter(TimeInterval,Error)
    
//    case automaticallyAssertOnFail(NSTimeInterval)  // can't test assert
  
    // TODO: Test Cancelation Requests
//    case onRequestCancelExecutor(CancelRequestHandler)
//    case onRequestCancel(CancelRequestHandler)
    
//    case automaticallyCancelOnRequestCancel
    
    case complete(Completion<T>)
    case completeWithSuccess(T)
    case completeWithFail(Error)
    case completeWithFailErrorMessage(String)
    case completeWithException(NSException)
    case completeWithCancel
    case completeUsingFuture(AnyFuture)
    
    case completeWithBlock(()->Completion<T>)
    //  The block is executed.  The Bool should be TRUE is we expect that the completeWithBlocks will succeed.
    case completeWithBlocksOnAlreadyCompleted(()->Completion<T>,Bool)
    
    case failIfNotCompleted(Error)
    case failIfNotCompletedErrorMessage(String)
    
    case tryComplete(Completion<T>,Bool)     // The Bool should be TRUE is we expect that the tryComplete will succeed.
    case completeWithOnCompletionError(Completion<T>,Bool)  // last value is TRUE if we expect the completion to succeed
    
    
    
    func addExpectation(_ testCase : FKTestCase) -> XCTestExpectation? {
        
        switch self {
            
        case let .completeWithBlocksOnAlreadyCompleted(_,completeWillSucceed):
            if (!completeWillSucceed) {
                return testCase.expectation(description: "we expect OnAlreadyCompleted to be executed")
            }
            else {
                return nil
            }

        case let .completeWithOnCompletionError(_,completeWillSucceed):
            if (!completeWillSucceed) {
                return testCase.expectation(description: "we expect OnCompletionError to be executed")
            }
            else {
                return nil
            }
            
            
        default:
            return nil
        }
        
    }
    
    
    func executeWith(_ promise : Promise<T>,test : PromiseTestCase<T>, testCase : FKTestCase, expectation:XCTestExpectation?)
    
    {
        switch self {
            
        case let .automaticallyCancelAfter(delay):
            promise.automaticallyCancel(afterDelay:delay)

        case let .automaticallyFailAfter(delay,error):
            promise.automaticallyFail(afterDelay:delay,with:error)

/*        case let .onRequestCancelExecutor(handler):
            promise.onRequestCancel(test.promiseExecutor, handler: handler)
            
        case let .onRequestCancel(handler):
            promise.onRequestCancel(handler)

        case .automaticallyCancelOnRequestCancel:
            promise.automaticallyCancelOnRequestCancel() */


        case let .complete(completion):
            promise.complete(completion.As())

            
        case let .completeWithSuccess(result):
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
            promise.completeUsingFuture(future.mapAs())

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
            
        case let .automaticallyFailAfter(delay,_):
            return "automaticallyFailAfter\(delay)"
            
            /*        case let .onRequestCancelExecutor(handler):
            return "onRequestCancel(test.promiseExecutor, handler: handler)
            
            case let .onRequestCancel(handler):
            return "onRequestCancel(handler)
            
            case .automaticallyCancelOnRequestCancel:
            return "automaticallyCancelOnRequestCancel() */
            
            
        case let .complete(completion):
            switch completion {
            case let .success(r):
                return "complete_Success_\(r)"
            case let .fail(e):
                return "complete_Fail_\(e)"
            case .cancelled:
                return "complete_Cancelled"
            case  .completeUsing(_):
                return "complete_CompleteUsing"
            }
            
            
        case let .completeWithSuccess(r):
            return "completeWithSuccess\(r)"
            
        case .completeWithFail(_):
            return "completeWithFail"
            
        case .completeWithFailErrorMessage(_):
            return "completeWithFailErrorMessage"
            
        case .completeWithException(_):
            return "completeWithException"
            
        case .completeWithCancel:
            return "completeWithCancel"
            
        case .completeUsingFuture(_):
            return "completeUsingFuture)"
            
        case .completeWithBlock(_):
            return "completeWithBlock"
            
            
        case .completeWithBlocksOnAlreadyCompleted(_,_):
            return "completeWithBlocksOnAlreadyCompleted"
            
        case .failIfNotCompleted(_):
            return "failIfNotCompleted"
            
        case .failIfNotCompletedErrorMessage(_):
            return "failIfNotCompletedErrorMessage"
            
            
        case let .tryComplete(completion,_):
            return "tryComplete\(completion)"
            
        case .completeWithOnCompletionError(_,_):
            return "completeWithOnCompletionError"
            
        }
    }
}
    



class PromiseTests: FKTestCase {
    

    class func testsFor<T : Equatable>(_ result:T, result2:T) -> [BlockBasedTest] {
        
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 2
        
/*        let custom : Executor.CustomCallBackBlock = { (callback) -> Void in
            Executor.Background.execute {
                Executor.Main.execute {
                    callback()
                }
            }
        }
        
        
        let q = dispatch_queue_create("custom q", DISPATCH_QUEUE_CONCURRENT)
        
        let old_executors : [Executor] = [.Primary, .Main, .Async, .Current, .Immediate, .StackCheckingImmediate, .MainAsync, .MainImmediate, .UserInteractive, .UserInitiated, .Default,  .Utility, .Background, .OperationQueue(opQueue), .Custom(custom), .Queue(q)]

        let full_executors_list : [Executor] = [
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
            .Queue(q)] */

        let quick_executors_list : [Executor] = [
            .mainAsync,
            .async,
            .current,
            .immediate]

//        let future_executors : [Executor] = [.MainAsync, .MainImmediate]

        
        var blockTests = [BlockBasedTest]()
        
        let setOfCharsWeGottaGetRidOf = CharacterSet(charactersIn: ".(),\n\t {}[];:=-")
        
        for promiseE in quick_executors_list {
            for futureE in quick_executors_list {
                
                let tests = PromiseFunctionTest<T>.createAllTheTests(result,result2: result2,promiseExecutor: promiseE,futureExecutor: futureE)
                
                
                for (index,t) in tests.enumerated() {
                    
                    let tvars = PromiseTestCase<T>(functionTest:t,
                        promiseExecutor:promiseE,
                        futureExecutor:futureE)
                    
                    let n = NSString(string:"test_\(index)_\(T.self)_\(result)_\(tvars.description)")
                    
                    let c = n.components(separatedBy: setOfCharsWeGottaGetRidOf)
                    let name = c.joined(separator: "")

                    let t = self.addTest(name, closure: { (_self : PromiseTests) -> Void in
                        tvars.executeTest(_self, name: name)
                    })!
                    blockTests.append(t)
                    
                }
                
                
                
            }
        }
        
        

        return blockTests
        
    }
    
    override class func myBlockBasedTests() -> [Any] {
        var tests = [BlockBasedTest]()
        
//        let v: () = ()
//        tests += self.testsFor(v, result2: v)
        
//        tests += self.testsFor(result: ["Bob" : 1.0], result2: ["Jane" : 2.0])

        tests += self.testsFor(Int(0),result2: Int(1))

        tests += self.testsFor(String("Hi"),result2: String("Bye"))
        
        tests += self.testsFor(Float(0.0),result2: Float(1.0))

        // array
//        tests += self.testsFor(result: [0.0, 1.0],result2: [2.0, 3.0])

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
        
        let completeExpectation = self.expectation(description: "Future.onComplete")
        let successExpectation = self.expectation(description: "Future.onSuccess")
        
        f.onComplete(futureExecutor) { (completion) -> Void in
            
            switch completion {
            case .success(_):
                break
            default:
                XCTFail("unexpectad completion value \(completion)")
            }
            completeExpectation.fulfill()
        }
        .ignoreFailures()
        
        // TODO: Can we get this to compile?
        
        f.onSuccess(futureExecutor) { (result:()) -> Void in
            
            successExpectation.fulfill()
            
        }.ignoreFailures()
        f.onFail(futureExecutor) { (error) -> Void in
            XCTFail("unexpectad onFail error \(error)")
            
        }
        f.onCancel(futureExecutor) { () -> Void in
            XCTFail("unexpectad onCancel" )
        }
        
        promise.completeWithSuccess(success)
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
        
    }

    func onPromiseSuccess<T : Equatable>(_ success:T, promiseExecutor : Executor, futureExecutor : Executor) {
        
        let promise = Promise<T>()
        let f = promise.future
        
        
        let completeExpectation = self.expectation(description: "Future.onComplete")
        let successExpectation = self.expectation(description: "Future.onSuccess")
        
        
        f.onComplete(futureExecutor) { (result) -> Void in
            
            switch result {
            case let .success(value):
                XCTAssert(value == success, "Didn't get expected success value \(success)")
            default:
                XCTFail("unexpected result \(result)")
            }
            completeExpectation.fulfill()
        }
        .ignoreFailures()
        
        f.onSuccess(futureExecutor) { (result) -> Void in
            
            XCTAssert(result == success, "Didn't get expected success value \(success)")
            successExpectation.fulfill()
            
        }.ignoreFailures()
        f.onFail(futureExecutor) { (error) -> Void in
            XCTFail("unexpectad onFail error \(error)")
            
        }
        f.onCancel(futureExecutor) { () -> Void in
            XCTFail("unexpectad onCancel" )
        }
        
        promiseExecutor.execute {
            promise.completeWithSuccess(success)
        }
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
        
    }
    
    func testPromiseSuccess()  {


        self.onPromiseSuccess(0, promiseExecutor: .primary, futureExecutor: .primary)
        self.onPromiseSuccess("String", promiseExecutor: .primary, futureExecutor: .primary)
//        self.onPromiseSuccess(success: [1,2], promiseExecutor: .primary, futureExecutor: .primary)

        self.onPromiseSuccessVoid(promiseExecutor: .primary, futureExecutor: .primary)

    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }

}

