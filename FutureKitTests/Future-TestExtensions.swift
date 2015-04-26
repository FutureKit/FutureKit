//
//  Future-TestExtensions.swift
//  FutureKit
//
//  Created by Michael Gray on 4/18/15.
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
