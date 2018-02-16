//
//  BlockBasedTestCase_h
//  FutureKit
//
//  Created by Michael Gray on 6/20/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

@import Foundation;
@import XCTest;

typedef NSObject BlockBasedTest;

@interface BlockBasedTestCase : XCTestCase

+ (BlockBasedTest *)_addTestWithName:(NSString*)name block:(void (^)(BlockBasedTestCase *))block;

// Overload this class method, and call 'addTestWithName'
+ (NSArray*) myBlockBasedTests;

@end
