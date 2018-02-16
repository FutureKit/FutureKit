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
    
    @discardableResult
    func expectationTestForCompletion(_ testcase: XCTestCase,
                                      description : String,
                                      file: StaticString = #file,
                                      line: UInt = #line,
        assertion : @escaping ((FutureResult<T>) -> (Bool,String))
        ) -> XCTestExpectation! {
        
            let e = testcase.expectation(description: description)
        
            self.onComplete { (value) -> Void in
                let test = assertion(value)
                
                XCTAssert(test.0,test.1,file:file,line:line)
                e.fulfill()
            }
            .ignoreFailures()
            return e
    }
    
    
    @discardableResult
    func expectationTestForSuccess(_ testcase: XCTestCase, description : String,
        file: StaticString = #file,
        line: UInt = #line,
        test : @escaping ((T) -> Bool)
        ) -> XCTestExpectation! {
        
        
        return self.expectationTestForCompletion(testcase, description: description, file:file, line:line,
                                                 assertion: { result -> (Bool, String) in
                                                    switch result {
                                                    case let .success(result):
                                                        return (test(result),"test result failure for Future with result \(result)" )
                                                    case let .fail(e):
                                                        return (false,"Future Failed with \(e)" )
                                                    case .cancelled:
                                                        return (false,"Future Cancelled" )
                                                    }
        })
    }
    
    @discardableResult
    func expectationTestForAnySuccess(_ testcase: XCTestCase, description : String,
        file: StaticString = #file,
        line: UInt = #line
        ) -> XCTestExpectation! {
            
        return self.expectationTestForCompletion(testcase, description: description, file:file, line:line) { result -> (Bool, String) in
                switch result {
                case .success:
                    return (true, "")
                case let .fail(e):
                    return (false,"Future Failed with \(e)" )
                case .cancelled:
                    return (false,"Future Cancelled" )
                }
            }
    }
    
    
    
}
