//
//  BlockBasedTestCase.swift
//  FutureKit
//
//  Created by Michael Gray on 6/22/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

import XCTest

extension BlockBasedTestCase {
    
    typealias BlockBasedTest = NSObject
 
    class func addTest<T : BlockBasedTestCase>(_ name:String, closure:@escaping ((T) -> Void)) -> BlockBasedTest? {
        return self._addTest(withName: name) { (test : BlockBasedTestCase?) -> Void in
            if let t = test as? T {
                closure(t)
            }
        }
    }

    
}
