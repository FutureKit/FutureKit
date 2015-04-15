//
//  SwiftExtras.h
//  MapMyVenue
//
//  Created by Michael Gray on 10/24/14.
//  Copyright (c) 2014 Flyby Media LLC. All rights reserved.
//

@interface ObjectiveCExceptionHandler : NSObject


// soo.. Swift has no Try Catch logic.
// BUT - UIKit throws em.  and sometimes we need to catcth them.
// written in ObjectiveC but it's expecto that we use it in Swift

+ (void)Try:(void(^)())tryBlock catch:(void(^)(NSException *exception))exceptionBlock finally:(void(^)())finallyBlock;
+ (void)Try:(void(^)())tryBlock catch:(void(^)(NSException *exception))exceptionBlock;
+ (void)Try:(void(^)())tryBlock finally:(void(^)())finallyBlock;


@end
