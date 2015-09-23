//
//  Completion.swift
//  FutureKit
//
//  Created by Michael Gray on 4/21/15.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation


public protocol CompletionType {
    typealias SuccessResultType
    
    var result : SuccessResultType! { get }
    var error : ErrorType! { get }
    
    var isSuccess : Bool { get }
    var isFail : Bool { get }
    var isCancelled : Bool { get }

    var completion : Completion<SuccessResultType> { get }
    var value : CompletionValue<SuccessResultType> { get }

}
/**
Defines a simple enumeration of the legal Completion states of a Future.

- Success: The Future has completed Succesfully.
- Fail: The Future has failed.
- Cancelled:  The Future was cancelled. This is typically not seen as an error.

The enumeration is Objective-C Friendly
*/
public enum CompletionValue<T>  {
    
    case Success(T)
    case Fail(ErrorType)
    case Cancelled
    
    public var completion : Completion<T> {
        get {
            switch self {
            case let .Success(result):
                return .Success(result)
            case let .Fail(error):
                return .Fail(error)
            case .Cancelled:
                return .Cancelled
            }
        }
    }
    public var value : CompletionValue<T> {
        return self
    }
    
}

/**
Defines a an enumeration that stores both the state and the data associated with a Future completion.

- Success(T): The Future completed Succesfully with a Result

- Fail(ErrorType): The Future has failed with an ErrorType.

- Cancelled(Any?):  The Future was cancelled. The cancellation can optionally include a token.

- CompleteUsing(FutureProtocol):  This Future will be completed with the result of a "sub" Future. Only used by block handlers.
*/
public enum Completion<T>  {
    
    /**
    Future completed with a result of T
    */
    case Success(T)
    
    /**
    Future failed with error ErrorType
    */
    case Fail(ErrorType)
    
    /**
    Future was Cancelled.
    */
    case Cancelled
    
    /**
    This Future's completion will be set by some other Future<T>.  This will only be used as a return value from the onComplete/onSuccess/onFail/onCancel handlers.  the var "completion" on Future should never be set to 'CompleteUsing'.
    
    FutureProtocol needs to be a Future<S> where S : T
    */
    case CompleteUsing(Future<T>)
}



public extension CompletionValue { // initializers
    
    /**
    returns a .Fail(FutureNSError) with a simple error string message.
    */
    public init(failWithErrorMessage : String) {
        self = .Fail(FutureKitError(genericError: failWithErrorMessage))
    }
    /**
    converts an NSException into an NSError.
    useful for generic Objective-C excecptions into a Future
    */
    public init(exception ex:NSException) {
        self = .Fail(FutureKitError(exception: ex))
    }
    
    public init(success s:T) {
        self = .Success(s)
    }
}

extension CompletionValue : CompletionType {
    public typealias SuccessResultType = T
   
    /**
    make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var result : T! {
        get {
            switch self {
            case let .Success(t):
                return t
            default:
                return nil
            }
        }
    }
    /**
    make sure this enum is a .Fail before calling `result`. Use a switch or check .isError() first.
    */
    public var error : ErrorType! {
        get {
            switch self {
            case let .Fail(e):
                return e
            default:
                return nil
            }
        }
    }
    
    public var isSuccess : Bool {
        get {
            switch self {
            case .Success:
                return true
            default:
                return false
            }
        }
    }
    public var isFail : Bool {
        get {
            switch self {
            case .Fail:
                return true
            default:
                return false
            }
        }
    }
    public var isCancelled : Bool {
        get {
            switch self {
            case .Cancelled:
                return true
            default:
                return false
            }
        }
    }
    
    
}


public extension CompletionValue { // conversions
    
    public func As() -> CompletionValue<T> {
        return self
    }
    /**
    convert this completion of type Completion<T> into another type Completion<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    - example:
    
    `let c : CompletionValue<Int> = .Success(5)`
    
    `let c2 : CompletionValue<Int32> =  c.As()`
    
    `assert(c2.result == Int32(5))`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func As<S>() -> CompletionValue<S> {
        switch self {
        case let .Success(t):
            let r = t as! S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        }
    }
    
    /**
    convert this completion of type `Completion<T>` into another type `Completion<S?>`.
    
    WARNING: if `T as! S` isn't legal, than all Success values may be converted to nil
    - example:
    
    let c : CompletionValue<String> = .Success("5")
    let c2 : CompletionValue<[Int]?> =  c.convertOptional()
    assert(c2.result == nil)
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    
    - returns: a new completionValue of type Completion<S?>
    
    */
    public func convertOptional<S>() -> CompletionValue<S?> {
        switch self {
        case let .Success(t):
            let r = t as? S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        }
    }
}

extension CompletionValue : CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case let .Success(result):
            return ".Success<\(T.self)>(\(result))"
        case let .Fail(error):
            return ".Fail<\(T.self)>(\(error))"
        case .Cancelled:
            return ".Cancelled<\(T.self)>)"
        }
    }
    public var debugDescription: String {
        return self.description
    }
    
    /**
    This doesn't seem to work yet in the XCode Debugger or Playgrounds.
    it seems that only NSObjectProtocol objects can use this method.
    Since this is a Swift Generic, it seems to be ignored.
    Sigh.
    */
    func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
}






public extension Completion { // initializers
    
    /**
    returns a .Fail(FutureNSError) with a simple error string message.
    */
    public init(failWithErrorMessage : String) {
        self = .Fail(FutureKitError(genericError: failWithErrorMessage))
    }
    /**
    converts an NSException into an NSError.
    useful for generic Objective-C excecptions into a Future
    */
    public init(exception ex:NSException) {
        self = .Fail(FutureKitError(exception: ex))
    }
    
    public init(success s:T) {
        self = .Success(s)
    }
}

extension Completion : CompletionType { // properties

    public typealias SuccessResultType = T
    public var completion : Completion<T> {
        return self
    }
   
    public var isSuccess : Bool {
        get {
            switch self {
            case .Success:
                return true
            default:
                return false
            }
        }
    }
    public var isFail : Bool {
        get {
            switch self {
            case .Fail:
                return true
            default:
                return false
            }
        }
    }
    public var isCancelled : Bool {
        get {
            switch self {
            case .Cancelled:
                return true
            default:
                return false
            }
        }
    }
    public var isCompleteUsing : Bool {
        get {
            switch self {
            case .CompleteUsing:
                return true
            default:
                return false
            }
        }
    }
    
    /**
    get the Completion state for a completed state. It's easier to create a switch statement on a completion.state, rather than the completion itself (since a completion block will never be sent a .CompleteUsing).
    */
    public var value : CompletionValue<T> {
        get {
            switch self {
            case let .Success(result):
                return .Success(result)
            case let .Fail(error):
                return .Fail(error)
            case .Cancelled:
                return .Cancelled
            case .CompleteUsing:
                let error = FutureKitError(genericError: "can't convert .CompleteUsing to CompletionValue<T>")
                assertionFailure("\(error)")
                return .Fail(error)
            }
        }
    }
    
    /**
    make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var result : T! {
        get {
            switch self {
            case let .Success(t):
                return t
            default:
                //                assertionFailure("don't call result without checking that the enumeration is .Error first.")
                return nil
            }
        }
    }
/*    public var forced : Bool {
        get {
            switch self {
            case let .Cancelled(forced):
                return forced
            default:
                //                assertionFailure("don't call result without checking that the enumeration is .Error first.")
                return false
            }
        }
    } */
    
    /**
    make sure this enum is a .Fail before calling `result`. Use a switch or check .isError() first.
    */
    public var error : ErrorType! {
        get {
            switch self {
            case let .Fail(e):
                return e
            default:
                //                assertionFailure("don't call .error without checking that the enumeration is .Error first.")
                return nil
            }
        }
    }
    
    internal var completeUsingFuture:Future<T>! {
        get {
            switch self {
            case let .CompleteUsing(f):
                return f.As()
            default:
                return nil
            }
        }
    }
    
}

public extension Completion { // conversions
    
    public func As() -> Completion<T> {
        return self
    }
    /**
    convert this completion of type Completion<T> into another type Completion<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    - example:
    
    `let c : Complete<Int> = .Success(5)`
    
    `let c2 : Complete<Int32> =  c.As()`
    
    `assert(c2.result == Int32(5))`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func As<S>() -> Completion<S> {
        switch self {
        case let .Success(t):
            let r = t as! S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .CompleteUsing(f):
            return .CompleteUsing(f.As())
        }
    }
    
    /**
    convert this completion of type `Completion<T>` into another type `Completion<S?>`.
    
    WARNING: if `T as! S` isn't legal, than all Success values may be converted to nil
    - example:
    
    let c : Complete<String> = .Success("5")
    let c2 : Complete<[Int]?> =  c.convertOptional()
    assert(c2.result == nil)
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    
    - returns: a new completionValue of type Completion<S?>
    
    */
    public func convertOptional<S>() -> Completion<S?> {
        switch self {
        case let .Success(t):
            let r = t as? S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .CompleteUsing(f):
            return .CompleteUsing(f.As())
        }
    }
}

extension Completion : CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        switch self {
        case let .Success(t):
            return ".Success<\(T.self)>(\(t))"
        case let .Fail(f):
            return ".Fail<\(T.self)>(\(f))"
        case let .Cancelled(reason):
            return ".Cancelled<\(T.self)>(\(reason))"
        case let .CompleteUsing(f):
            return ".CompleteUsing<\(T.self)>(\(f.description))"
        }
    }
    public var debugDescription: String {
        return self.description
    }
    
    /**
    This doesn't seem to work yet in the XCode Debugger or Playgrounds.
    it seems that only NSObjectProtocol objects can use this method.
    Since this is a Swift Generic, it seems to be ignored.
    Sigh.
    */
    func debugQuickLookObject() -> AnyObject? {
        return self.debugDescription
    }
}

 