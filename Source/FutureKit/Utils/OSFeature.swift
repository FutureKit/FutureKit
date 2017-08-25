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

func IOS_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(_ version: NSString) -> Bool {
    return UIDevice.current.systemVersion.compare(version as String,
        options: NSString.CompareOptions.numeric) != ComparisonResult.orderedAscending
}
        
let is_ios_8_or_above = IOS_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO("8.0")
    
#else
        
#endif


enum OSFeature {
    
    case nsOperationQueuePriority
    case dispatchQueuesWithQos
    
    var is_supported : Bool {
#if os(iOS)
    switch self {
        case .nsOperationQueuePriority:
            return is_ios_8_or_above
        case .dispatchQueuesWithQos:
            return is_ios_8_or_above
    }
#else
        return true
#endif
    }
    
}
