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
public protocol ErrorTypeMightBeCancellation: Error {
    
    // should return true if the Error value is actually a cancellation
    var isCancellation : Bool { get }
    
}

extension ErrorTypeMightBeCancellation {
    
    // don't use this, use ErrorType.toResult<T>()!
    internal func toFutureResult<T>() -> FutureResult<T> {
        if self.isCancellation {
            return .cancelled
        }
        else {
            return .fail(self)
        }
    }
    // don't use this, use ErrorType.toCompletion!
    
    internal func toFutureCompletion<T>() -> Completion<T> {
        if self.isCancellation {
            return .cancelled
        }
        else {
            return .fail(self)
        }
    }
}


// This is a protocol that helps you figure out if an ErrorType REALLY IS an NSError
// since error as NSError always works in swift, we will use a protocol test.
public protocol NSErrorType : ErrorTypeMightBeCancellation {
    var userInfo: [AnyHashable: Any] { get }
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


public extension Error {
    var isNSError : Bool {
        return (Self.self is NSErrorType.Type)
    }

    var userInfo: [AnyHashable: Any] {
        return [:]
    }
    
    public var testForCancellation : Bool {
        if Self.self is ErrorTypeMightBeCancellation.Type {
            return (self as ErrorTypeMightBeCancellation).isCancellation
        }
        return false;
    }

    func toResult<T>() -> FutureResult<T> {
        if Self.self is ErrorTypeMightBeCancellation.Type {
            let errorType = self as ErrorTypeMightBeCancellation & Error
            return errorType.toFutureResult()
        }
        return .fail(self)
    }

    func toCompletion<T>() -> Completion<T> {
        if Self.self is ErrorTypeMightBeCancellation.Type {
            let errorType = self as ErrorTypeMightBeCancellation & Error
            return errorType.toFutureCompletion()
        }
        return .fail(self)
    }

}


extension NSError : NSErrorType {
    convenience init(error : Error) {
        let e = error as NSError
        self.init(domain: e.domain, code: e.code, userInfo:e.userInfo)
    }
}
