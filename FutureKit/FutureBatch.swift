//
//  Future-Sequences.swift
//  FutureKit
//
//  Created by Michael Gray on 4/13/15.
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

// swiftlint:disable large_tuple function_parameter_count file_length
import Foundation

// ---------------------------------------------------------------------------------------------------
//
//   CONVERT an Array of Futures into a single Future
//
// ---------------------------------------------------------------------------------------------------

public struct FutureBatchOf<T> {

    /**
    
    */
    private let subFutures: [Future<T>]

    /**
        `completionsFuture` returns an array of individual Completion<T> values
        - returns: a `Future<[Completion<T>]>` always returns with a Success.  Returns an array of the individual Future.Completion values for each subFuture.
    */
    public var resultsFuture: Future<[Future<T>.Result]> {
        return subFutures.async.resultsFuture
    }

    /**
        batchFuture succeeds iff all subFutures succeed. The result is an array `[T]`.  it does not complete until all futures have been completed within the batch (even if some fail or are cancelled).
    */
    public var batchFuture: Future<[T]> {
        return FutureBatchOf.futureFromResultsFuture(self.resultsFuture)
    }

    /**
        `future` succeeds iff all subfutures succeed.  Will complete with a Fail or Cancel as soon as the first sub future is failed or cancelled.
        `future` may complete, while some subfutures are still running, if one completes with a Fail or Canycel.
    
        If it's important to know that all Futures have completed, you can alertnatively use `batchFuture` and  `cancelRemainingFuturesOnFirstFail()` or `cancelRemainingFuturesOnFirstFailOrCancel()`.  batchFuture will always wait for all subFutures to complete before finishing, but will wait for the cancellations to be processed before exiting.
        this wi
    */
    public var future: Future<[T]> {
        return self.subFutures.async.flatten
    }

    /**
        takes a type-safe list of Futures.
    */
    public init(futures f: [Future<T>]) {
        self.subFutures = f
    }

    public init<C: CompletionConvertable>(_ futures: [C]) where C.T == T {
        self.subFutures = futures.map { $0.future }
    }

    /**
        Allows you to define a Block that will execute as soon as each Future completes.
        The biggest difference between using onEachComplete() or just using the `future` var, is that this block will execute as soon as each future completes.
        The block will be executed repeately, until all sub futures have been completed.
    
        This can also be used to compose a new Future[S].  All the values returned from the block will be assembled and returned in a new Future<[S]. If needed.
    
        - parameter executor: executor to use to run the block
        :block: block block to execute as soon as each Future completes.
    */
    public func onEachComplete<S>(_ executor: Executor = .primary,
                                  block:@escaping (Int, Future<T>.Result) -> S) -> Future<[S]> {

        return self.subFutures
            .async
            .mapResults { (index, result) -> (Completion<S>, Bool) in
                return (.success(block(index, result)), false)
            }
            .onSuccess { $0.async.flattenResults }
    }

    /*
        adds a handler that executes on the first Future that fails.
        :params: block a block that will execute
    **/
    public func onFirstFail<C: CompletionConvertable>(_ executor: Executor = .primary,
                                                      block: @escaping (Int, Error) -> C) -> Future<C.T> {

        return self.subFutures.async.firstFail.onSuccess(block: block)

    }

    /**
        takes an array of futures of type `[Future<T>]` and returns a single future of type Future<[Completion<T>]
        So you can now just add a single onSuccess/onFail/onCancel handler that will be executed once all of the sub-futures in the array have completed.
        This future always returns .Success, with a result individual completions.
        This future will never complete, if one of it's sub futures doesn't complete.
        you have to check the result of the array individually if you care about the specific outcome of a subfuture
    
        - parameter array: an array of Futures of type `[T]`.
        - returns: a single future that returns an array of `Completion<T>` values.
    */
    public static func resultsFuture<S: Sequence>(_ sequence: S) -> Future<[Future<S.Element.T>.Result]> where S.Element: CompletionConvertable {

        return sequence.async.resultsFuture

     }

    public func firstSuccess() -> Future<T> {

        return self.subFutures.async.firstSuccess.map { $0.1 }
     }

    /**
    takes a future of type `Future<[Completion<T>]` (usually returned from `completionFutures()`) and
    returns a single future of type `Future<[T]>`.   It checks all the completion values and will return .Fail if one of the Futures Failed.
    will return .Cancelled if there were no .Fail completions, but at least one subfuture was cancelled.
    returns .Success iff all the subfutures completed.
    
    - parameter a: completions future of type  `Future<[Completion<T>]>`
    - returns: a single future that returns an array an array of `[T]`.
    */
    public static func futureFromResultsFuture<T>(_ f: Future<[Future<T>.Result]>) -> Future<[T]> {
        return f.onSuccess { $0.async.flattenResults}
    }

    /**
    takes an array of futures of type `[Future<T>]` and returns a single future of type Future<[T]>
    So you can now just add a single onSuccess/onFail/onCancel handler that will be executed once all of the sub-futures in the array have completed.
    It checks all the completion values and will return .Fail if one of the Futures Failed.
    will return .Cancelled if there were no .Fail completions, but at least one subfuture was cancelled.
    returns .Success iff all the subfutures completed.
    
    this Future will not complete until ALL subfutures have finished. If you need a Future that completes as soon as single Fail or Cancel is seen, use a `FutureBatch` object and use the var `future` or the method `onFirstFail()`
    
    
    - parameter array: an array of Futures of type `[T]`.
    - returns: a single future that returns an array of `[T]`, or a .Fail or .Cancel if a single sub-future fails or is canceled.
    */
    public static func futureFromArrayOfFutures(_ array: [Future<T>]) -> Future<[T]> {
        return array.async.flatten
    }

}

// public typealias FutureBatch = FutureBatchOf<Any>

public func FutureBatch(_ futures: [BaseFutureProtocol]) -> FutureBatchOf<Any> {

    return FutureBatchOf<Any>(futures: futures.map { $0.futureAny })

}

public func FutureBatch<F: FutureConvertable>(_ futures: [F]) -> FutureBatchOf<F.T> {
    return FutureBatchOf<F.T>(futures: futures.map { $0.future })
}

extension FutureBatchOf where T == Any {
    /**
     takes a list of Futures.  Each future will be converted into a Future that returns T.
     
     */
    public init(_ futures: [BaseFutureProtocol]) {

        self.init(futures: futures.map { $0.futureAny })
    }

}

extension Async where Base: Sequence, Base.Element: ResultConvertable {

    public var findFirstError: Future<Base.Element.T>.Result? {
        let results = self.base.map { $0.result }

        return results.first { $0.isFail }
    }
    public var findFirstCancelled: Future<Base.Element.T>.Result? {
        let results = self.base.map { $0.result }

        return results.first { $0.isCancelled }
    }
    public var findFirstSuccess: Future<Base.Element.T>.Result? {
        let results = self.base.map { $0.result }

        return results.first { $0.isSuccess }
    }

    public var flattenResults: Future<[Base.Element.T]>.Result {
        let results = self.base.map { $0.result }

        if let error = self.findFirstError?.error {
            return .fail(error)
        }
        if self.findFirstCancelled != nil {
            return .cancelled
        }
        let values = results.map { $0.value! }
        return .success(values)
    }

}

extension Async where Base: Sequence, Base.Element == BaseFutureProtocol {

    public var flattenAny: Future<[Any]> {
        return self.base.map { $0.futureAny }.async.flatten
    }
}

extension Async where Base: Sequence, Base.Element: CompletionConvertable {

    public typealias FutureType = Future<Base.Element.T>

    public typealias Value = FutureType.T
    public typealias Result = FutureType.Result

    public var batch: FutureBatchOf<Value> {
        return FutureBatchOf<Value>(Array(self.base))
    }

    public var resultsFuture: Future<[Result]> {

        return self.mapResults(.immediate) { (_, result) -> (Future<Value>.Result, Bool) in
            return (result, false)
        }

    }

    public var flatten: Future<[Value]> {

        return self.mapResults(.immediate) { (_, result) -> (Future<Value>.Result, Bool) in
                return (result, !result.isSuccess)
            }
            .onSuccess { $0.async.flattenResults }

    }

    public var firstSuccess: Future<(Int, Value)> {
        let p = Promise<(Int, Value)>()
        self
            .mapResults(.immediate) { (index, result) -> (Future<Value>.Result, Bool) in
                if let value = result.value {
                    p.completeWithSuccess((index, value))
                }
                return (result, false)
            }
            .onComplete { _ -> Void in
                p.completeWithCancel()
            }
        return p.future
    }

    public var firstFail: Future<(Int, Error)> {
        let p = Promise<(Int, Error)>()
        self
            .mapResults(.immediate) { (index, result) -> (Future<Value>.Result, Bool) in
                if let error = result.error {
                    p.completeWithSuccess((index, error))
                }
                return (result, false)
            }
            .onComplete { _ -> Void in
                p.completeWithCancel()
        }
        return p.future
    }

    public var batchFuture: Future<[Value]> {

        return self.mapResults(.immediate) { (_, result) -> (Future<Value>.Result, Bool) in
            return (result, false)
        }
        .onSuccess { $0.async.flattenResults }

    }

    public func mapResults<C: CompletionConvertable>(
        _ executor: Executor = .primary,
        _ transform: @escaping ((Int, Result) -> (C, Bool))) -> Future<[Future<C.T>.Result]> {

        let futures = self.base.map { $0.future }
        guard futures.count > 0 else {
            return Future<[Future<C.T>.Result]>(success: [])
        }

        let promise = Promise<[Future<C.T>.Result]>()
        var total = futures.count
        var tokens = futures.map { Optional($0.getCancelToken()) }
        promise.onRequestCancel { _ -> CancelRequestResponse<[Future<C.T>.Result]> in
            for token in tokens {
                token?.cancel()
            }
            return .completeWithCancel
        }

        var resultsArray = [Future<C.T>.Result](repeating: .cancelled, count: futures.count)
        for (index, future) in futures.enumerated() {
            future.onComplete(executor) { result -> Void in
                guard !promise.isCompleted else {
                    return
                }
                tokens[index] = nil
                let (completion, doCancel) = transform(index, result)
                completion.future.onComplete { innerResult in
                    promise.synchObject.lockAndModifyAsync(modifyBlock: { () -> Int in
                        resultsArray[index] = innerResult
                        total -= 1
                        return total
                    }, then: { currentTotal -> Void in
                        if currentTotal == 0 {
                            promise.completeWithSuccess(resultsArray)
                        }
                    })
                }
                if doCancel {
                    promise.completeWithSuccess(resultsArray)
                    for token in tokens {
                        token?.cancel()
                    }
                }
            }
                .ignoreFailures()
        }
        return promise.future
    }

    public func mapResults<C: CompletionConvertable>(
        _ executor: Executor = .primary,
        _ transform: @escaping ((Result) throws -> C)) -> Future<[Future<C.T>.Result]> {

        return self.mapResults(executor) { (_, result) -> (Future<C.T>.Completion, Bool) in
            do {
                let c = try transform(result).completion
                return (c, !c.isSuccess)
            } catch {
                return (.fail(error), true)
            }
        }

    }

}

extension Async where Base: Sequence {

    public func map<C: CompletionConvertable>(_ transform: (Base.Element) -> C) -> Future<[C.T]> {
        return self.base.map(transform).async.flatten
   }

}

extension Sequence {

    public func mapFuture<C: CompletionConvertable>(_ transform: (Element) -> C) -> Future<[C.T]> {
        return self.map(transform).async.flatten
    }

    public var async: Async<Self> {
        return Async(self)
    }

    /// A proxy which hosts static reactive extensions for the type of `self`.
    public static var async: Async<Self>.Type {
        return Async<Self>.self
    }

}

extension Future {
    public func combineWith<S>(_ s: Future<S>) -> Future<(T, S)> {
        return [self, s].async.flattenAny.map { $0.toTuple() }
    }
}

public func combineFutures<A, B>(_ a: Future<A>, _ b: Future<B>) -> Future<(A, B)> {
    return [a, b].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>) -> Future<(A, B, C)> {
    return [a, b, c].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>) -> Future<(A, B, C, D)> {
    return [a, b, c, d].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>) -> Future<(A, B, C, D, E)> {
    return [a, b, c, d, e].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>) -> Future<(A, B, C, D, E, F)> {
    return [a, b, c, d, e, f].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>) -> Future<(A, B, C, D, E, F, G)> {
    return [a, b, c, d, e, f, g].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>) -> Future<(A, B, C, D, E, F, G, H)> {
    return [a, b, c, d, e, f, g, h].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H, I>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>) -> Future<(A, B, C, D, E, F, G, H, I)> {
    return [a, b, c, d, e, f, g, h, i].async.flattenAny.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H, I, J>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>, _ j: Future<J>) -> Future<(A, B, C, D, E, F, G, H, I, J)> {
    return [a, b, c, d, e, f, g, h, i, j].async.flattenAny.map { $0.toTuple() }
}

extension Future {
    public static func combine<A, B>(_ a: Future<A>, _ b: Future<B>) -> Future<(A, B)> {
        return [a, b].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>) -> Future<(A, B, C)> {
        return [a, b, c].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>) -> Future<(A, B, C, D)> {
        return [a, b, c, d].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>) -> Future<(A, B, C, D, E)> {
        return [a, b, c, d, e].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E, F>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>) -> Future<(A, B, C, D, E, F)> {
        return [a, b, c, d, e, f].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E, F, G>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>) -> Future<(A, B, C, D, E, F, G)> {
        return [a, b, c, d, e, f, g].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E, F, G, H>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>) -> Future<(A, B, C, D, E, F, G, H)> {
        return [a, b, c, d, e, f, g, h].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E, F, G, H, I>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>) -> Future<(A, B, C, D, E, F, G, H, I)> {
        return [a, b, c, d, e, f, g, h, i].async.flattenAny.map { $0.toTuple() }
    }

    public static func combine<A, B, C, D, E, F, G, H, I, J>(_ a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>, _ j: Future<J>) -> Future<(A, B, C, D, E, F, G, H, I, J)> {
        return [a, b, c, d, e, f, g, h, i, j].async.flattenAny.map { $0.toTuple() }
    }

}
