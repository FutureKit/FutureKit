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
    typealias ValueType
    
    var value : ValueType! { get }
    var error : ErrorType! { get }
    
    var isSuccess : Bool { get }
    var isFail : Bool { get }
    var isCancelled : Bool { get }

    func asCompletion() -> Completion<ValueType>
    func asResult() -> FutureResult<ValueType>

}
/**
Defines a simple enumeration of the legal Completion states of a Future.

- case Success(T):      the Future has completed Succesfully.
- case Fail(ErrorType): the Future has failed.
- case Cancelled:       the Future was cancelled. This is typically not seen as an error.

*/
public enum FutureResult<T>  {
    
    case Success(T)
    case Fail(ErrorType)
    case Cancelled

}

extension FutureResult {
    public func asCompletion() -> Completion<T> {
        switch self {
        case let .Success(result):
            return .Success(result)
        case let .Fail(error):
            return .Fail(error)
        case .Cancelled:
            return .Cancelled
        }
    }
    public func asResult() -> FutureResult<T> {
        return self
    }
    
}

/**
Defines a an enumeration that can be used to complete a Promise/Future.

- Success(T): The Future should complete with a `FutureResult.Success(T)`

- Fail(ErrorType): The Future should complete with a `FutureResult.Fail(ErrorType)`

- Cancelled:  
    The Future should complete with with `FutureResult.Cancelled`.

- CompleteUsing(Future<T>):  
    The Future should be completed with the result of a another dependent Future, when the dependent Future completes.
    
    If The Future receives a cancelation request, than the cancellation request will be forwarded to the depedent future.
*/
public enum Completion<T>  {
    
    case Success(T)
    case Fail(ErrorType)
    case Cancelled
    case CompleteUsing(Future<T>)
}



public extension FutureResult { // initializers
    
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

extension FutureResult : CompletionType {
    public typealias ValueType = T
   
    /**
    make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var value : T! {
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
    
    /** 
    can be used inside a do/try/catch block to 'try' and get the result of a Future.
    
    Useful if you want to use a swift 2.0 error handling block to resolve errors
    
        let f: Future<Int> = samplefunction()
        f.onComplete { (value) -> Void in
            do {
                let r: Int = try resultValue()
            }
            catch {
                print("error : \(error)")
            }
        }
    
    */
    func tryValue() throws -> T {
        switch self {
        case let .Success(value):
            return value
        case let .Fail(error):
            throw error
        case .Cancelled:
            throw FutureKitError(genericError: "Future was canceled.")
        }
    }
    
    /**
    can be used inside a do/try/catch block to 'try' and get the result of a Future.
    
    Useful if you want to use a swift 2.0 error handling block to resolve errors
    
        let f: Future<Int> = samplefunction()
        f.onComplete { (value) -> Void in
            do {
                try throwIfFail()
            }
            catch {
                print("error : \(error)")
            }
        }`
    
    .Cancelled does not throw an error.  If you want to also trap cancellations use 'throwIfFailOrCancel()`
    
    */
    func throwIfFail() throws {
        switch self {
        case let .Fail(error):
            throw error
        default:
            break
        }
    }

    /**
    can be used inside a do/try/catch block to 'try' and get the result of a Future.
    
    Useful if you want to use a swift 2.0 error handling block to resolve errors
    
        let f: Future<Int> = samplefunction()
        f.onComplete { (value) -> Void in
            do {
                try throwIfFailOrCancel()
            }
            catch {
                print("error : \(error)")
            }
        }
    
    */
    func throwIfFailOrCancel() throws {
        switch self {
        case let .Fail(error):
            throw error
        case .Cancelled:
            throw FutureKitError(genericError: "Future was canceled.")
        default:
            break
        }
    }

}


public extension FutureResult { // conversions
    
    
    public func map<S>(block:(T) throws -> S) -> FutureResult<S> {
        switch self {
        case let .Success(t):
            do {
                return .Success(try block(t))
            }
            catch {
                return .Fail(error)
            }
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        }
    }

    public func As() -> FutureResult<T> {
        return self
    }
    /**
    convert this completion of type Completion<T> into another type Completion<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    - example:
    
    `let c : FutureResult<Int> = .Success(5)`
    
    `let c2 : FutureResult<Int32> =  c.As()`
    
    `assert(c2.result == Int32(5))`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    @available(*, deprecated=1.1, message="renamed to mapAs()")
    public func As<S>() -> FutureResult<S> {
        return mapAs()
    }

    /**
    convert this completion of type Completion<T> into another type Completion<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    - example:
    
    `let c : FutureResult<Int> = .Success(5)`
    
    `let c2 : FutureResult<Int32> =  c.As()`
    
    `assert(c2.result == Int32(5))`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func mapAs<S>() -> FutureResult<S> {
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
    
    let c : FutureResult<String> = .Success("5")
    let c2 : FutureResult<[Int]?> =  c.convertOptional()
    assert(c2.result == nil)
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    
    - returns: a new result of type Completion<S?>
    
    */
    @available(*, deprecated=1.1, message="renamed to mapAsOptional()")
    public func convertOptional<S>() -> FutureResult<S?> {
        return mapAsOptional()
    }
    public func mapAsOptional<S>() -> FutureResult<S?> {
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

extension FutureResult : CustomStringConvertible, CustomDebugStringConvertible {
    
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

    public typealias ValueType = T
    public func asCompletion() -> Completion<T> {
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
    public func asResult() -> FutureResult<T> {
        switch self {
        case let .Success(result):
            return .Success(result)
        case let .Fail(error):
            return .Fail(error)
        case .Cancelled:
            return .Cancelled
        case .CompleteUsing:
            let error = FutureKitError(genericError: "can't convert .CompleteUsing to FutureResult<T>")
            assertionFailure("\(error)")
            return .Fail(error)
        }
    }
    
    /**
    make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var value : T! {
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
    @available(*, deprecated=1.1, message="renamed to mapAs()")
    public func As<S>() -> Completion<S> {
        return mapAs()
    }

    
    /**
     convert this completion of type Completion<T> into another type Completion<S>.
     
     may fail to compile if T is not convertable into S using "`as!`"
     
     works iff the following code works:
     
     'let t : T`
     
     'let s = t as! S'
     
     
     - example:
     
     `let c : Complete<Int> = .Success(5)`
     
     `let c2 : Complete<Int32> =  c.mapAs()`
     
     `assert(c2.result == Int32(5))`
     
     you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
     */
    public func map<S>(block:(T) throws -> S) -> Completion<S> {
        switch self {
        case let .Success(t):
            do {
                return .Success(try block(t))
            }
            catch {
                return .Fail(error)
            }
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .CompleteUsing(f):
            return .CompleteUsing(f.map(block:block))
        }
    }
    
    /**
    convert this completion of type Completion<T> into another type Completion<S>.
    
    may fail to compile if T is not convertable into S using "`as!`"
    
    works iff the following code works:
    
    'let t : T`
    
    'let s = t as! S'
    
    
    - example:
    
    `let c : Complete<Int> = .Success(5)`
    
    `let c2 : Complete<Int32> =  c.mapAs()`
    
    `assert(c2.result == Int32(5))`
    
    you will need to formally declare the type of the new variable, in order for Swift to perform the correct conversion.
    */
    public func mapAs<S>() -> Completion<S> {
        switch self {
        case let .Success(t):
            let r = t as! S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .CompleteUsing(f):
            return .CompleteUsing(f.mapAs())
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
    
    - returns: a new result of type Completion<S?>
    
    */
    @available(*, deprecated=1.1, message="renamed to mapAsOptional()")
    public func convertOptional<S>() -> Completion<S?> {
        return mapAsOptional()
    }
    
    public func mapAsOptional<S>() -> Completion<S?> {
        switch self {
        case let .Success(t):
            let r = t as? S
            return .Success(r)
        case let .Fail(f):
            return .Fail(f)
        case .Cancelled:
            return .Cancelled
        case let .CompleteUsing(f):
            return .CompleteUsing(f.mapAs())
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

 