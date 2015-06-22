//
//  ObjCBlockBasedTest.h
//  FutureKit
//
//  Created by Michael Gray on 6/20/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

#ifndef ObjCBlockBasedTest_h
#define ObjCBlockBasedTest_h


@interface ObjCBlockBasedTest : XCTestCase
+ (id)addTestWithName:(NSString*)name cname:(NSString*)cname b:(void (^)(id))b;

+ (NSArray*) myInvocations;

@end


#endif /* ObjCBlockBasedTest_h */
