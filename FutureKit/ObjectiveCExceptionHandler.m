//
//  SwiftExtras.m
//  MapMyVenue
//
//  Created by Michael Gray on 10/24/14.
//  Copyright (c) 2014 Flyby Media LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ObjectiveCExceptionHandler.h"


@implementation ObjectiveCExceptionHandler


+ (void)Try:(void(^)())tryBlock catch:(void(^)(NSException *exception))exceptionBlock finally:(void(^)())finallyBlock
{
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        exceptionBlock(exception);
    }
    @finally {
        finallyBlock();
    }
}


+ (void)Try:(void(^)())tryBlock catch:(void(^)(NSException *exception))exceptionBlock
{
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        exceptionBlock(exception);
    }
}

+ (void)Try:(void(^)())tryBlock finally:(void(^)())finallyBlock
{
    @try {
        tryBlock();
    }
    @finally {
        finallyBlock();
    }
}

@end
