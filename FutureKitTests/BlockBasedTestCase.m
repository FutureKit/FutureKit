//
//  BlockBasedTestCase.m
//  FutureKit
//
//  Created by Michael Gray on 6/20/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ObjectiveC;

#include "BlockBasedTestCase.h"

@implementation BlockBasedTestCase


+ (NSArray *)testInvocations {
    
    return [self myBlockBasedTests];
}


+(NSArray*)myBlockBasedTests {
    
    // overload me!
    
    return [NSArray new];
    
}

+ (BlockBasedTest *)_addTestWithName:(NSString*)name block:(void (^)(BlockBasedTestCase *))block {
    
    NSString * n = [name stringByReplacingOccurrencesOfString:@"." withString:@"_"];

    IMP i = imp_implementationWithBlock(block);
    
    SEL exampleSelector = NSSelectorFromString(@"testExample");
    
    Method exampleMethod = class_getInstanceMethod([self class],
                                                exampleSelector);
    
    const char * encoding = method_getTypeEncoding(exampleMethod);
    
    SEL newMethodSelector = NSSelectorFromString(n);
    
    BOOL worked = class_addMethod([self class],newMethodSelector,i,encoding);
    
    if (worked) {
        XCTestCase * t = [self testCaseWithSelector:newMethodSelector];
        NSInvocation * i = [t invocation];
        return i;
    }
    else {
        NSAssert(false, @"couldn't add test with name %@.  Make sure test names are unique!",n);
        return nil;
    }
    
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
