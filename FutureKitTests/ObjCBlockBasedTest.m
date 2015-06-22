//
//  ObjCBlockBasedTest.m
//  FutureKit
//
//  Created by Michael Gray on 6/20/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

#import <XCTest/XCTest.h>
@import ObjectiveC;

/*
Class c = objc_getClass("AFJSONResponseSerializer");
id block = ^NSSet*()
{
    return [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", nil];
};

SEL selctor = NSSelectorFromString(@"acceptableContentTypes");
IMP test = imp_implementationWithBlock(block);
Method origMethod = class_getInstanceMethod(c,
                                            selctor);

if(!class_addMethod(c, selctor, test,
                    method_getTypeEncoding(origMethod)))
{
    method_setImplementation(origMethod, test);
}
 */

/*
class func addTest<T : XCTestCase>(name:String, closure:(T) -> Void) -> Selector {
    let block: @convention(block) (AnyObject!) -> () = { (instance : AnyObject!) -> () in
        let testCase = instance as! T
        closure(testCase)
    }
    
    let imp = imp_implementationWithBlock(unsafeBitCast(block, T.self))
    let selectorName = name.stringByReplacingOccurrencesOfString(" ", withString: "_", options: NSStringCompareOptions(rawValue: 0), range: nil)
    let selector = Selector(selectorName)
    let method = class_getInstanceMethod(self, "example") // No @encode in swift, creating a dummy method to get encoding
    let types = method_getTypeEncoding(method)
    let added = class_addMethod(self, selector, imp, types)
    print(name)
    assert(added, "Failed to add `\(name)` as `\(selector)`")
    
    let xct = XCTestCase(selector: selector).invocation
    return xct
    }
    
    func example() { See addTest() */
/* } */

#include "ObjCBlockBasedTest.h"

@implementation ObjCBlockBasedTest


+ (NSArray <NSInvocation *> *)testInvocations {
    
    return [self myInvocations];
}


+(NSArray*)myInvocations {
    
    // overload me!
    
    return [NSArray new];
    
}

+ (id)addTestWithName:(NSString*)name cname:(NSString*)cname b:(void (^)(id))b {


    IMP i = imp_implementationWithBlock(b);
    
    SEL exampleSelector = NSSelectorFromString(@"testExample");
    
    Method exampleMethod = class_getInstanceMethod([self class],
                                                exampleSelector);
    
    const char * encoding = method_getTypeEncoding(exampleMethod);
    
    SEL newMethodSelector = NSSelectorFromString(name);
    
    BOOL worked = class_addMethod([self class],newMethodSelector,i,encoding);
    
    if (worked) {
        XCTestCase * t = [self testCaseWithSelector:newMethodSelector];
        NSInvocation * i = [t invocation];
        return i;
    }
    return nil;
    
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
