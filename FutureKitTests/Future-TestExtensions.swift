//
//  Future-TestExtensions.swift
//  FutureKit
//
//  Created by Michael Gray on 4/18/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import XCTest
import FutureKit


extension Future {
    
    func expectationTestForCompletion(testcase: XCTestCase, _ description : String,
        assertion : ((completion : Completion<T>) -> (assert:BooleanType,message:String)),
        file: String = __FILE__,
        line: UInt = __LINE__
        ) -> XCTestExpectation! {
            
            let e = testcase.expectationWithDescription(description)
            
            self.onComplete { (completion) -> Void in
                let test = assertion(completion:completion)
                
                XCTAssert(test.assert,test.message,file:file,line:line)
                e.fulfill()
            }
            return e
    }
    
    
    func expectationTestForSuccess(testcase: XCTestCase, _ description : String,
        test : ((result:T) -> BooleanType)) -> XCTestExpectation! {
            
            return self.expectationTestForCompletion(testcase, description, assertion: { (completion : Completion<T>) -> (assert: BooleanType, message: String) in
                switch completion.state {
                case .Success:
                    let result = completion.result
                    return (test(result: result),"test result failure for Future with result \(result)" )
                case let .Fail:
                    let e = completion.error
                    return (false,"Future Failed with \(e) \(e.localizedDescription)" )
                case .Cancelled:
                    return (false,"Future Cancelled" )
                }
            })
    }
    
    func expectationTestForAnySuccess(testcase: XCTestCase, _  description : String,
        file: String = __FILE__,
        line: UInt = __LINE__
        ) -> XCTestExpectation! {
            
            return self.expectationTestForCompletion(testcase, description, assertion: { (completion : Completion<T>) -> (assert: BooleanType, message: String) in
                switch completion.state {
                case .Success:
                    return (true, "")
                case .Fail:
                    let e = completion.error
                    return (false,"Future Failed with \(e) \(e.localizedDescription)" )
                case .Cancelled:
                    return (false,"Future Cancelled" )
                }
                }, file:file, line:line)
    }
    
    
    
}
