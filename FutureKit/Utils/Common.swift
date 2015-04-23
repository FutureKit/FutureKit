//
//  Common.swift
//  Shimmer
//
//  Created by Jeffrey Arenberg on 10/30/14.
//  Copyright (c) 2014 FlybyMedia. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
// UI
let IS_SMALLSCREEN = ( UIScreen.mainScreen().bounds.size.height < 568.0)
let SCREEN_WIDTH = UIScreen.mainScreen().bounds.size.width
let SCREEN_HEIGHT = UIScreen.mainScreen().bounds.size.height


// System Versions
func SYSTEM_VERSION_EQUAL_TO(version: String) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version,
        options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedSame
}

func SYSTEM_VERSION_GREATER_THAN(version: String) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version,
        options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedDescending
}

func SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(version: String) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version,
        options: NSStringCompareOptions.NumericSearch) != NSComparisonResult.OrderedAscending
}

func SYSTEM_VERSION_LESS_THAN(version: String) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version,
        options: NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending
}

func SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(version: String) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version,
        options: NSStringCompareOptions.NumericSearch) != NSComparisonResult.OrderedDescending
}

#endif
    
// Enums
func LocalizedString(key: String) -> String {
    return NSLocalizedString(key, comment: key)
}



func synchronized<T>(lockObj: AnyObject!, closure: ()->T) -> T
{
    objc_sync_enter(lockObj)
    var retVal: T = closure()
    objc_sync_exit(lockObj)
    return retVal
}

func synchronized(lockObj: AnyObject!, closure: ()->Void) -> Void
{
    objc_sync_enter(lockObj)
    closure()
    objc_sync_exit(lockObj)
}


func dispatch_main_sync_safe(block: dispatch_block_t)
{
    if (NSThread.isMainThread())
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
    
}


func dispatch_main_async_safe(block: dispatch_block_t)
{
    if (NSThread.isMainThread())
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    
}

/* func dispatch_main_async_task(always_dispatch : Bool = false, block: dispatch_block_t) -> Task
{
    let tcs = TaskCompletionSource()
    
    if (!always_dispatch && NSThread.isMainThread())
    {
        block();
        tcs.setResult(nil)
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(),  {
            block()
            tcs.setResult(nil)
        })
    }
    return tcs.task
    
}

func dispatch_main_async_task(block: dispatch_block_t) -> Task {
    return dispatch_main_async_task(always_dispatch: false, block)
} */

func dispatch_main_sync(block: dispatch_block_t)
{
    dispatch_sync(dispatch_get_main_queue(), block);
}

func dispatch_main_async(block: dispatch_block_t)
{
    dispatch_async(dispatch_get_main_queue(), block);
}

// takes an array of optionals and returns an array of unwinded vales
// the unwinded array may be smaller (with nil values removed)
func unwindArrayOfOptionals<T>(array:[T?]) -> [T] {
    return array.filter{ (opt:T?) -> Bool in
                                switch opt {
                                case .None:
                                    return false
                                default:
                                    return true
                                }}  // filter out the non-nils
                .map{ (opt:T?) -> T in opt! }  // map each optional to it's unwinded value
}



