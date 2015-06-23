//
//  OSFeature.swift
//  FutureKit
//
//  Created by Michael Gray on 6/22/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

#if os(iOS)

import UIKit

func SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(version: NSString) -> Bool {
    return UIDevice.currentDevice().systemVersion.compare(version as String,
        options: NSStringCompareOptions.NumericSearch) != NSComparisonResult.OrderedAscending
}
        
let is_ios_8_or_above = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO("8.0")
    
#else
        
#endif


enum OSFeature {
    
    case NSOperationQueuePriority
    case DispatchQueuesWithQos
    
    var is_supported : Bool {
#if os(ios)
    switch self {
        case .NSOperationQueuePriority:
            return is_ios_8_or_above
        case .DispatchQueuesWithQos:
            return is_ios_8_or_above
    }
#else
        return true
#endif
    }
    
}
