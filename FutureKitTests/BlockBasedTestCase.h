//
//  BlockBasedTestCase_h
//  FutureKit
//
//  Created by Michael Gray on 6/20/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

#ifndef BlockBasedTestCase_h
#define BlockBasedTestCase_h

typedef NSObject BlockBasedTest;



@interface BlockBasedTestCase : XCTestCase

+ (BlockBasedTest *)_addTestWithName:(NSString*)name block:(void (^)(BlockBasedTestCase *))block;

// Overload this class method, and call 'addTestWithName'
+ (NSArray*) myBlockBasedTests;

@end


#endif /* BlockBasedTestCase_h */
