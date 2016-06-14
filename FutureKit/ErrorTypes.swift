//
//  ErrorTypes.swift
//  FutureKit
//
//  Created by Michael Gray on 1/14/16.
//  Copyright © 2016 Michael Gray. All rights reserved.
//

import Foundation


//
// *  a protocol to extend ErrorTypes that might ACTUALLY be cancellations!
// If you are returning
public protocol ErrorTypeMightBeCancellation : ErrorType {
    
    // should return true if the Error value is actually a cancellation
    var isCancellation : Bool { get }
    
}

extension ErrorTypeMightBeCancellation {
    
    // don't use this, use ErrorType.toResult<T>()!
    internal func toFutureResult<T>() -> FutureResult<T> {
        if self.isCancellation {
            return .Cancelled
        }
        else {
            return .Fail(self)
        }
    }
    // don't use this, use ErrorType.toCompletion!
    
    internal func toFutureCompletion<T>() -> Completion<T> {
        if self.isCancellation {
            return .Cancelled
        }
        else {
            return .Fail(self)
        }
    }
}


// This is a protocol that helps you figure out if an ErrorType REALLY IS an NSError
// since error as NSError always works in swift, we will use a protocol test.
public protocol NSErrorType : ErrorTypeMightBeCancellation {
    var userInfo: [NSObject : AnyObject] { get }
    var domain: String { get }
    var code: Int { get }
    
}


public extension NSErrorType {
    public var isCancellation : Bool {
        
        if GLOBAL_PARMS.CONVERT_COMMON_NSERROR_VALUES_TO_CANCELLATIONS {
            // some common NSErrors!
            if self.domain == NSURLErrorDomain {
                if ((self.code == NSURLErrorCancelled) || (self.code == NSURLErrorUserCancelledAuthentication)) {
                    return true
                }
            }
                
            if (self.domain == NSCocoaErrorDomain) && (self.code == NSUserCancelledError) {
                return true
            }
        }
        return false
    }
}


public extension ErrorType {
    var isNSError : Bool {
        return ((self as? NSErrorType) != nil)
    }
    
    public var testForCancellation : Bool {
        return (self as? ErrorTypeMightBeCancellation)?.isCancellation ?? false
    }

    
    func toResult<T>() -> FutureResult<T> {
        return (self as? ErrorTypeMightBeCancellation)?.toFutureResult() ?? .Fail(self)
    }
    func toCompletion<T>() -> Completion<T> {
        return (self as? ErrorTypeMightBeCancellation)?.toFutureCompletion() ?? .Fail(self)
    }

}


extension NSError : NSErrorType {
    convenience init(error : ErrorType) {
        let e = error as NSError
        self.init(domain: e.domain, code: e.code, userInfo:e.userInfo)
    }
}
