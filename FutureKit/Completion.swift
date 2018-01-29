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

// swiftlint:disable file_length

import Foundation

// the onSuccess and onComplete handlers will return either a generic type S, or any object confirming to the CompletionConvertable.

//    CompletionConvertable include Completion<T>, Future<T>.Result, Future<T>, Promise<T>...

public protocol AnyFutureConvertable: CustomStringConvertible, CustomDebugStringConvertible {

    var futureAny: Future<Any> { get }

}

public protocol FutureConvertable: AnyFutureConvertable {
    associatedtype T

    var future: Future<T> { get }

}
extension FutureConvertable {
    public var futureAny: Future<Any> {
        return self.future.as(Any.self)
    }

    public func `as`<S>(_ type: S.Type) -> Future<S> {
        return self.future.onComplete(.immediate) { result -> Future<S>.Completion in
            switch result {
            case let .success(t):
                if let r = t as? S {
                    return .success(r)
                } else {
                    assertionFailure("you can't cast \(t) to \(S.self)")
                    return Completion(failWithErrorMessage: "can't cast \(t) to \(S.self)")
                }
            case let .fail(error):
                return .fail(error)
            case .cancelled:
                return .cancelled
            }

        }
    }

    public func `as`<S>(_ type: S.Type) -> Future<S.Wrapped?> where S: OptionalProtocol {
        return self.future.onComplete(.immediate) { result -> Future<S.Wrapped?>.Completion in
            switch result {
            case let .success(t):
                return .success(t as? S.Wrapped)
            case let .fail(error):
                return .fail(error)
            case .cancelled:
                return .cancelled
            }

        }
    }

}

public protocol AnyCompletionConvertable: CustomStringConvertible, CustomDebugStringConvertible {

    var completionAny: Future<Any>.Completion { get }

}

public protocol CompletionConvertable: AnyCompletionConvertable {
    associatedtype T

    var completion: Future<T>.Completion { get }
    var future: Future<T> { get }

}

public typealias CompletionType = CompletionConvertable

extension CompletionConvertable {

    public var asVoid: Future<Void>.Completion {
        return self.as(Void.self)
    }

    public func `as`<S>(_ type: S.Type) -> Future<S>.Completion {
        switch self.completion {
        case let .success(t):
            if let r = t as? S {
                return .success(r)
            } else {
                assertionFailure("you can't cast \(t) to \(S.self)")
                return Completion(failWithErrorMessage: "can't cast \(t) to \(S.self)")
            }
        case let .fail(error):
            return .fail(error)
        case .cancelled:
            return .cancelled
        case let .completeUsing(future):
            return .completeUsing(future.as(S.self))
        }
    }

    public func `as`<S>(_ type: S.Type) -> Future<S.Wrapped?>.Completion where S: OptionalProtocol {
        switch self.completion {
        case let .success(t):
            if let r = t as? S.Wrapped {
                return .success(r)
            } else {
                return .success(nil)
            }
        case let .fail(error):
            return .fail(error)
        case .cancelled:
            return .cancelled
        case let .completeUsing(future):
            return .completeUsing(future.as(S.Wrapped?.self))
        }
    }

    public var completionAny: Future<Any>.Completion {
        return self.completion.as(Any.self)
    }

}

public protocol ResultConvertable {
    associatedtype T

    var result: Future<T>.Result { get }
}

/**
Defines a simple enumeration of the legal Completion states of a Future.

- case Success(T):      the Future has completed Succesfully.
- case Fail(ErrorType): the Future has failed.
- case Cancelled:       the Future was cancelled. This is typically not seen as an error.

*/
extension Future {
}

extension Future.Result {
    public var result: Future<T>.Result {
        return self
    }
}

public typealias FutureResult<T> = Future<T>.Result
public typealias Completion<T> = Future<T>.Completion

/**
Defines a an enumeration that can be used to complete a Promise/Future.

- .success(T): The Future should complete with a `FutureResult.success(T)`

- .fail(ErrorType): The Future should complete with a `FutureResult.fail(ErrorType)`

- ,cancelled:
    The Future should complete with with `FutureResult.cancelled`.

- .completeUsing(Future<T>):
    The Future should be completed with the result of a another dependent Future, when the dependent Future completes.
    
    If The Future receives a cancelation request, than the cancellation request will be forwarded to the depedent future.
*/
extension Future {
}

extension Future {
    public enum AnyResult {

        case success(Any)
        case fail(Error)
        case cancelled
    }
    public enum AnyCompletion {

        case success(Any)
        case fail(Error)
        case cancelled
        case completeUsing(Future<Any>)
    }
}

extension CompletionConvertable where Self: Error {
    public var completion: Future<T>.Completion {
        return .fail(self)
    }

    public var future: Future<T> {
        return Future(fail: self)
    }

}
extension NSError: CompletionConvertable {
    public typealias T = Void
}

extension Future: CompletionConvertable {

    public var completion: Future<T>.Completion {
        return .completeUsing(self)
    }

    public var future: Future<T> {
        return self
    }

    public static func success(_ value: T) -> Future<T> {
        return Future<T>(success: value)
    }

    public static func fail(_ error: Error) -> Future<T> {
        return Future<T>(fail: error)
    }
    public static var cancelled: Future<T> {
        return Future<T>(cancelled: ())
    }
    public static func completeUsing(_ future: Future<T>) -> Future<T> {
        return future
    }
}
extension FutureConvertable {
    public static func success(_ value: T) -> Future<T> {
        return Future<T>(success: value)
    }

    public static func fail(_ error: Error) -> Future<T> {
        return Future<T>(fail: error)
    }
    public static var cancelled: Future<T> {
        return Future<T>(cancelled: ())
    }
    public static func completeUsing<F: FutureConvertable>(_ future: F) -> Future<T> where F.T == T {
        return future.future
    }
    public static func completeUsing(_ future: Future<T>) -> Future<T> {
        return future
    }
}

extension Promise: CompletionConvertable {

    public var completion: Completion<T> {
        return .completeUsing(self.future)
    }

}

extension Completion { // properties

    public var completion: Completion<T> {
        return self
    }
    public var future: Future<T> {
        switch self {
        case let .success(result):
            return Future(success: result)
        case let .fail(error):
            return Future(fail: error)
        case .cancelled:
            return Future(cancelled: ())
        case let .completeUsing(future):
            return future
        }
    }

}

extension Future.Result: CompletionConvertable {

    public var completion: Completion<T> {
        switch self {
        case let .success(result):
            return .success(result)
        case let .fail(error):
            return error.toCompletion()
        case .cancelled:
            return .cancelled
        }
    }

    public var future: Future<T> {
        switch self {
        case let .success(result):
            return Future<T>(success: result)
        case let .fail(error):
            return Future<T>(fail: error)
        case .cancelled:
            return Future<T>(cancelled: ())
        }
    }

}

extension CompletionConvertable {

    public static func SUCCESS(_ value: T) -> Completion<T> {
        return Completion<T>(success: value)
    }

    public static func FAIL(_ fail: Error) -> Completion<T> {
        return Completion<T>(fail: fail)
    }

    public static func FAIL(_ failWithErrorMessage: String) -> Completion<T> {
        return Completion<T>(failWithErrorMessage: failWithErrorMessage)
    }

    public static func CANCELLED<T>(_ cancelled:()) -> Completion<T> {
        return Completion<T>(cancelled: cancelled)
    }

    public static func COMPLETE_USING<T>(_ completeUsing: Future<T>) -> Completion<T> {
        return Completion<T>(completeUsing: completeUsing)
    }

}

public func SUCCESS<T>(_ value: T) -> Completion<T> {
    return Completion<T>(success: value)
}

public func FAIL<T>(_ fail: Error) -> Completion<T> {
    return Completion<T>(fail: fail)
}

public func CANCELLED<T>(_ cancelled:()) -> Completion<T> {
    return Completion<T>(cancelled: cancelled)
}

public func COMPLETE_USING<T>(_ completeUsing: Future<T>) -> Completion<T> {
    return Completion<T>(completeUsing: completeUsing)
}

public extension Future.Result { // initializers

    /**
    returns a .Fail(FutureNSError) with a simple error string message.
    */
    public init(failWithErrorMessage: String) {
        self = .fail(FutureKitError(genericError: failWithErrorMessage))
    }
    /**
    converts an NSException into an NSError.
    useful for generic Objective-C excecptions into a Future
    */
    public init(exception ex: NSException) {
        self = .fail(FutureKitError(exception: ex))
    }

    public init(success: T) {
        self = .success(success)
    }

    public init(fail: Error) {
        self = .fail(fail)
    }
    public init(cancelled: ()) {
        self = .cancelled
    }

}

public extension CompletionConvertable {
    /**
    make sure this enum is a .Success before calling `result`. Do a check 'completion.state {}` or .isFail() first.
    */
    public var value: T! {
        switch self.completion {
        case let .success(t):
            return t
        case let .completeUsing(f):
            if let v = f.value {
                return v
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    /**
    make sure this enum is a .Fail before calling `result`. Use a switch or check .isError() first.
    */
    public var error: Error! {
        switch self.completion {
        case let .fail(e):
            return e.testForCancellation ? nil : e
        default:
            return nil
        }
    }

    public var isSuccess: Bool {
        switch self.completion {
        case .success:
            return true
        default:
            return false
        }
    }
    public var isFail: Bool {
        switch self.completion {
        case let .fail(e):
            return !e.testForCancellation
        default:
            return false
        }
    }
    public var isCancelled: Bool {
        switch self.completion {
        case .cancelled:
            return true
        case let .fail(e):
            return e.testForCancellation
        default:
            return false
        }
    }

    public var isCompleteUsing: Bool {
        switch self.completion {
        case .completeUsing:
            return true
        default:
            return false
        }
    }

    internal var completeUsingFuture: Future<T>! {
        switch self.completion {
        case let .completeUsing(f):
            return f
        default:
            return nil
        }
    }

    var result: Future<T>.Result! {

        switch self.completion {
        case .completeUsing:
            return nil
        case let .success(value):
            return .success(value)
        case let .fail(error):
            return error.toResult() // check for possible cancellation errors
        case .cancelled:
            return .cancelled
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
        switch self.completion {
        case let .success(value):
            return value
        case let .fail(error):
            throw error
        case .cancelled:
            throw FutureKitError(genericError: "Future was canceled.")
        case let .completeUsing(f):
            if let v = f.value {
                return v
            }
            throw FutureKitError(genericError: "Future was not completed.")
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
        switch self.completion {
        case let .fail(error):
            if !error.testForCancellation {
                throw error
            }
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
        switch self.completion {
        case let .fail(error):
            throw error
        case .cancelled:
            throw FutureKitError(genericError: "Future was canceled.")
        default:
            break
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

    public func map<S>(_ block: @escaping (T) throws -> S) -> Completion<S> {

        switch self.completion {
        case let .success(t):
            do {
                return .success(try block(t))
            } catch {
                return .fail(error)
            }
        case let .fail(f):
            return .fail(f)
        case .cancelled:
            return .cancelled
        case let .completeUsing(f):

            let mapf: Future<S> = f.map(.primary, block: block)
            return .completeUsing(mapf)
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
    public func mapAsOptional<O: OptionalProtocol>(type: O.Type) -> Completion<O.Wrapped?> {

        return self.map { v -> O.Wrapped? in
            return v as? O.Wrapped
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
        switch self.completion {
        case let .success(t):
            assert(t is S, "you can't cast \(type(of: t)) to \(S.self)")
            if t is S {
                let r = t as! S // swiftlint:disable:this force_cast
                return .success(r)
            } else {
                return Completion<S>(failWithErrorMessage: "can't cast  \(type(of: t)) to \(S.self)")
            }
        case let .fail(f):
            return .fail(f)
        case .cancelled:
            return .cancelled
        case let .completeUsing(f):
            return .completeUsing(f.mapAs())
        }
    }

    public func mapAs() -> Completion<T> {
        return self.completion
    }

    public func mapAs() -> Completion<Void> {
        switch self.completion {
        case .success:
            return .success(())
        case let .fail(f):
            return .fail(f)
        case .cancelled:
            return .cancelled
        case let .completeUsing(f):
            return .completeUsing(f.mapAs())
        }
    }

    public func As() -> Completion<T> {
        return self.completion
    }

    @available(*, deprecated: 1.1, message: "renamed to mapAs()")
    public func As<S>() -> Completion<S> {
        return self.mapAs()
    }

}

extension Future.Result: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        switch self {
        case let .success(result):
            return ".Success<\(T.self)>(\(result))"
        case let .fail(error):
            return ".Fail<\(T.self)>(\(error))"
        case .cancelled:
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
        return self.debugDescription as AnyObject?
    }
}

public extension Completion { // initializers

    /**
    returns a .Fail(FutureNSError) with a simple error string message.
    */
    public init(failWithErrorMessage: String) {
        self = .fail(FutureKitError(genericError: failWithErrorMessage))
    }
    /**
    converts an NSException into an NSError.
    useful for generic Objective-C excecptions into a Future
    */
    public init(exception ex: NSException) {
        self = .fail(FutureKitError(exception: ex))
    }

    public init(success: T) {
        self = .success(success)
    }

    public init(fail: Error) {
        self = fail.toCompletion() // make sure it's not really a cancellation
    }
    public init(cancelled: ()) {
        self = .cancelled
    }
    public init(completeUsing: Future<T>) {
        self = .completeUsing(completeUsing)
    }

}

extension CompletionConvertable {

    @available(*, deprecated: 1.1, message: "depricated use completion", renamed: "completion")
    func asCompletion() -> Completion<T> {
        return self.completion
    }

    @available(*, deprecated: 1.1, message: "depricated use result", renamed: "result")
    func asResult() -> Future<T>.Result {
        return self.result
    }

}

extension CompletionConvertable {

    public var future: Future<T> {
        switch self.completion {
        case let .success(result):
            return Future(success: result)
        case let .fail(error):
            return Future(fail: error)
        case .cancelled:
            return Future(cancelled: ())
        case let .completeUsing(future):
            return future
        }
    }

    public var description: String {
        switch self.completion {
        case let .success(t):
            return "\(Self.self).CompletionConvertable.Success<\(T.self)>(\(t))"
        case let .fail(f):
            return "\(Self.self).CompletionConvertable.Fail<\(T.self)>(\(f))"
        case .cancelled:
            return "\(Self.self).CompletionConvertable.Cancelled<\(T.self)>)"
        case let .completeUsing(f):
            return "\(Self.self).CompletionConvertable.CompleteUsing<\(T.self)>(\(f.description))"
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
        return self.debugDescription as AnyObject?
    }
}
