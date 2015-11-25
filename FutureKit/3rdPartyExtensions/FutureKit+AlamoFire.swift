//
//  FutureKit+AlamoFire.swift
//  CoverPages
//
//  Created by Michael Gray on 9/21/15.
//  Copyright © 2015 Squarespace. All rights reserved.
//

import Foundation
import Alamofire
import FutureKit
import SwiftyJSON


public protocol ResponseType {
    typealias ResultValueType
    typealias ResultErrorType : ErrorType

    var _request: NSURLRequest? { get }
    
    /// The server's response to the URL request.
    var _response: NSHTTPURLResponse? { get }
    
    /// The data returned by the server.
    var _data: NSData? { get }
    
    /// The result of response serialization.
    var _result: Result<ResultValueType, ResultErrorType> { get }

}



extension Alamofire.Response : ResponseType {
    public typealias ResultValueType = Value
    public typealias ResultErrorType = Error
    
    
    public var _request: NSURLRequest?  {
        return self.request
    }

    public var _response: NSHTTPURLResponse?  {
        return self.response
    }

    public var _data: NSData?  {
        return self.data
    }

    public var _result: Result<ResultValueType, ResultErrorType>  {
        return self.result
    }
    
}

extension Alamofire.Result {
    
    public func asCompletion() -> Completion<Value>  {
        switch self {
        case let .Success(value):
            return .Success(value)
            
        case let .Failure(error):
            return .Fail(error)
        }
        
    }

}

private struct MIMEType {
    let type: String
    let subtype: String
    
    init?(_ string: String) {
        let components: [String] = {
            let stripped = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            let split = stripped.substringToIndex(stripped.rangeOfString(";")?.startIndex ?? stripped.endIndex)
            return split.componentsSeparatedByString("/")
        }()
        
        if let
            type = components.first,
            subtype = components.last
        {
            self.type = type
            self.subtype = subtype
        } else {
            return nil
        }
    }
    
    func matches(MIME: MIMEType) -> Bool {
        switch (type, subtype) {
        case (MIME.type, MIME.subtype), (MIME.type, "*"), ("*", MIME.subtype), ("*", "*"):
            return true
        default:
            return false
        }
    }
}

extension Alamofire.ResponseSerializerType {
    
    func serialize<R : ResponseType>(response: R) -> Response<SerializedObject, ErrorObject> {
        
        let result = self.serializeResponse(response._request,response._response,response._data,nil)
        return Response<SerializedObject, ErrorObject>(
                request: response._request,
                response: response._response,
                data:response._data,
                result:result)
        
    }
    
    
}

extension ResponseType {
    
    public func validate(validation: Alamofire.Request.Validation) -> Alamofire.Request.ValidationResult {
        
        if case let .Failure(error) = validation(self._request,self._response!) {
            return .Failure(error)
        }
        return .Success
    }

    public func validate<S: SequenceType where S.Generator.Element == Int>(statusCode acceptableStatusCode: S) -> Alamofire.Request.ValidationResult {
        
        return validate { _, response in
            if acceptableStatusCode.contains(response.statusCode) {
                return .Success
            } else {
                let failureReason = "Response status code was unacceptable: \(response.statusCode)"
                return .Failure(Error.errorWithCode(.StatusCodeValidationFailed, failureReason: failureReason))
            }
        }
    }
    
    /**
     Validates that the response has a content type in the specified array.
     
     If validation fails, subsequent calls to response handlers will have an associated error.
     
     - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
     
     - returns: The request.
     */
    public func validate<S : SequenceType where S.Generator.Element == String>(contentType acceptableContentTypes: S) -> Alamofire.Request.ValidationResult {
        return validate { _, response in
            guard let validData = self._data where validData.length > 0 else { return .Success }
            
            if let
                responseContentType = response.MIMEType,
                responseMIMEType = MIMEType(responseContentType)
            {
                for contentType in acceptableContentTypes {
                    if let acceptableMIMEType = MIMEType(contentType) where acceptableMIMEType.matches(responseMIMEType) {
                        return .Success
                    }
                }
            } else {
                for contentType in acceptableContentTypes {
                    if let MIMEType = MIMEType(contentType) where MIMEType.type == "*" && MIMEType.subtype == "*" {
                        return .Success
                    }
                }
            }
            
            let failureReason: String
            
            if let responseContentType = response.MIMEType {
                failureReason = (
                    "Response content type \"\(responseContentType)\" does not match any acceptable " +
                    "content types: \(acceptableContentTypes)"
                )
            } else {
                failureReason = "Response content type was missing and acceptable content type does not match \"*/*\""
            }
            
            return .Failure(Error.errorWithCode(.ContentTypeValidationFailed, failureReason: failureReason))
        }
    }
    
    // MARK: - Automatic
    
    /**
    Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    type matches any specified in the Accept HTTP header field.
    
    If validation fails, subsequent calls to response handlers will have an associated error.
    
    - returns: The request.
    */
    public func validate() -> Alamofire.Request.ValidationResult {
        let acceptableStatusCodes: Range<Int> = 200..<300
        let acceptableContentTypes: [String] = {
            if let accept = _request?.valueForHTTPHeaderField("Accept") {
                return accept.componentsSeparatedByString(",")
            }
            
            return ["*/*"]
        }()
        
        var result = validate(statusCode: acceptableStatusCodes)
        if case .Success = result {
            
            result = validate(contentType: acceptableContentTypes)
        }
        return result
    }

    
    public func asCompletion() -> Completion<ResultValueType>  {
        
        switch self._result {
        case let .Success(value):
            if case let .Failure(error) = self.validate() {
                return .Fail(error)
            }
            return .Success(value)
            
        case let .Failure(error):
            return .Fail(error)
        }
        
    }

}


extension Future where T : ResponseType {
    
    public func validate(validation: T -> Alamofire.Request.ValidationResult) -> Future<T.ResultValueType> {
        
        return self.onSuccess { $0.asCompletion() }
    }
    
    public func validate<S: SequenceType where S.Generator.Element == Int>(statusCode acceptableStatusCode: S) -> Future<T.ResultValueType>  {
        
        return self.validate { response in
            response.validate(statusCode: acceptableStatusCode)
        }
        
    }

    public func validate<S : SequenceType where S.Generator.Element == String>(contentType acceptableContentTypes: S) -> Future<T.ResultValueType>  {
        
        return self.validate { response in
            response.validate(contentType: acceptableContentTypes)
        }
        
    }
    public func validate() -> Future<T.ResultValueType>  {
        return self.validate { response in
            response.validate()
        }
    }


    
}



extension Request {
    

    // returns an non-validated response from Alamofire (that has been serialized).
    func responseFuture<T: ResponseSerializerType>(responseSerializer s: T) -> Future<Alamofire.Response<T.SerializedObject,T.ErrorObject>> {
        let p = Promise<Alamofire.Response<T.SerializedObject,T.ErrorObject>>()
        p.onRequestCancel { _  in
            self.cancel()       // AlamoFire will send NSURLErrorDomain,.NSURLErrorCancelled error if cancel is successful
            return .Continue    // wait for NSError to arrive before canceling future.
        }
        
        self.response(queue: nil, responseSerializer: s) { response -> Void in
            switch response.result {
            case .Success:
                p.completeWithSuccess(response)
            case let .Failure(error):
                let e = error as NSError
                if (e.domain == NSURLErrorDomain) && (e.code == NSURLErrorCancelled) {
                    p.completeWithCancel()
                }
                else {
                    p.completeWithSuccess(response)
                }
            }
        }
        
        
        return p.future
        
    }

    func future<T: ResponseSerializerType>(responseSerializer s: T) -> Future<T.SerializedObject> {
        
        return self.responseFuture(responseSerializer: s).onSuccess { (response) -> Completion<T.SerializedObject> in
            
            switch response.result {
            case let .Success(value):
                return .Success(value)
            case let .Failure(error):
                return .Fail(error)
            }
        }
    }

    func futureNSData() -> Future<NSData> {
        return future(responseSerializer:Request.dataResponseSerializer())
    }

    // uses NSJSONSerialization
    func futureJSONObject(options: NSJSONReadingOptions = .AllowFragments) -> Future<AnyObject> {
        return future(responseSerializer:Request.JSONResponseSerializer(options: options))
    }
    
    func futureString(encoding: NSStringEncoding? = nil) -> Future<String> {
        return future(responseSerializer:Request.stringResponseSerializer(encoding: encoding))
    }
    func futurePropertyList(options: NSPropertyListReadOptions = []) -> Future<AnyObject> {
        return future(responseSerializer:Request.propertyListResponseSerializer(options: options))
    }
    
    
}
 