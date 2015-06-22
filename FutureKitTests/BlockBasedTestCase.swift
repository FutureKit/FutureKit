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
 
    class func addTest<T : BlockBasedTestCase>(name:String, closure:((_self:T) -> Void)) -> BlockBasedTest? {
        return self._addTestWithName(name) { (test : BlockBasedTestCase!) -> Void in
            let t = test as! T
            closure(_self: t)
        }
    }

    
}
