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

import Foundation

// ---------------------------------------------------------------------------------------------------
//
//   CONVERT an Array of Futures into a single Future
//
// ---------------------------------------------------------------------------------------------------

public typealias FutureBatch = FutureBatchOf<Any>

public class FutureBatchOf<T> {
    
    /**
    
    */
    internal(set) var subFutures  = [Future<T>]()
    private var tokens = [CancellationToken]()

    /** 
        `completionsFuture` returns an array of individual Completion<T> values
        - returns: a `Future<[Completion<T>]>` always returns with a Success.  Returns an array of the individual Future.Completion values for each subFuture.
    */
    public internal(set) var resultsFuture : Future<[FutureResult<T>]>
    

    /**
        batchFuture succeeds iff all subFutures succeed. The result is an array `[T]`.  it does not complete until all futures have been completed within the batch (even if some fail or are cancelled).
    */
    public internal(set) lazy var batchFuture : Future<[T]> = FutureBatchOf.futureFromResultsFuture(self.resultsFuture)
    
    /**
        `future` succeeds iff all subfutures succeed.  Will complete with a Fail or Cancel as soon as the first sub future is failed or cancelled.
        `future` may complete, while some subfutures are still running, if one completes with a Fail or Canycel.
    
        If it's important to know that all Futures have completed, you can alertnatively use `batchFuture` and  `cancelRemainingFuturesOnFirstFail()` or `cancelRemainingFuturesOnFirstFailOrCancel()`.  batchFuture will always wait for all subFutures to complete before finishing, but will wait for the cancellations to be processed before exiting.
        this wi
    */
    public internal(set) lazy var future : Future<[T]> = self._onFirstFailOrCancel()

    
    /**
        takes a type-safe list of Futures.
    */
    public init(futures f : [Future<T>]) {
        self.subFutures = f
        for s in self.subFutures {
            self.tokens.append(s.getCancelToken())
        }
        self.resultsFuture = FutureBatchOf.resultsFuture(f)
    }
    
    /**
        takes a list of Futures.  Each future will be converted into a Future that returns T.
    
    */
    public convenience init(_ futures : [FutureProtocol]) {
        let f : [Future<T>] = FutureBatch.convertArray(futures)
        self.init(futures:f)
    }
    
    /**
        will forward a cancel request to each subFuture
        Doesn't guarantee that a particular future gets canceled
    */
    func cancel(option:CancellationOptions = []) {
        for t in self.tokens {
            t.cancel(option)
        }
    }
    
    /**
        will cause any other Futures to automatically be cancelled, if one of the subfutures future fails or is cancelled
    */
    func cancelRemainingFuturesOnFirstFailOrCancel() {
        self.future.onComplete { (completion) -> Void in
            if (!completion.isSuccess) {
                self.cancel()
            }
        }
    }

    /**
        will cause any other subfutures to automatically be cancelled, if one of the subfutures future fails.  Cancellations are ignored.
    */
    func cancelRemainingFuturesOnFirstFail() {
        self.future.onComplete { (completion) -> Void in
            if (completion.isFail) {
                self.cancel()
            }
        }
    }

    /**
        Allows you to define a Block that will execute as soon as each Future completes.
        The biggest difference between using onEachComplete() or just using the `future` var, is that this block will execute as soon as each future completes. 
        The block will be executed repeately, until all sub futures have been completed.
    
        This can also be used to compose a new Future[__Type].  All the values returned from the block will be assembled and returned in a new Future<[__Type]. If needed.
    
        - parameter executor: executor to use to run the block
        :block: block block to execute as soon as each Future completes.
    */
    public final func onEachComplete<__Type>(executor : Executor = .Primary,
        block:(result:FutureResult<T>, future:Future<T>, index:Int)-> __Type) -> Future<[__Type]> {
        
        var futures = [Future<__Type>]()
        
        for (index, future) in self.subFutures.enumerate() {
            
            let f = future.onComplete { result in
                return block(result: result, future:future,index: index)
            }
            futures.append(f)
        }
        return FutureBatchOf<__Type>.futureFromArrayOfFutures(futures)
    }
    
    
    typealias FailOrCancelHandler = (FutureResult<T>, Future<T>, Int) -> Void

    private final func _onFirstFailOrCancel(executor : Executor = .Immediate,
                            ignoreCancel:Bool = false,
                            block:FailOrCancelHandler? = nil) -> Future<[T]> {
        
        
        if let block = block {
            
            // this will complete as soon as ONE Future Fails or is Cancelled.
            let failOrCancelPromise = Promise<(FutureResult<T>, Future<T>, Int)>()
            
            for (index, future) in self.subFutures.enumerate() {
                future.onComplete { value in
                    if (!value.isSuccess) {
                        // fail immediately on the first subFuture failure
                        // which ever future fails first will complete the promises
                        // the others will be ignored
                        if (!value.isCancelled || !ignoreCancel) {
                            failOrCancelPromise.completeWithSuccess((value, future, index))
                        }
                    }
                }
            }
            // We want to 'Cancel' this future if it is successful (so we don't call the block)
            self.batchFuture.onSuccess (.Immediate) { _ in
                failOrCancelPromise.completeWithCancel()
            }
            
            // As soon as the first Future fails, call the block handler.
            failOrCancelPromise.future.onSuccess(executor) { (result,future,index)  in
                block(result, future, index)
            }
        }
        
        // this future will be 'almost' like batchFuture, except it fails immediately without waiting for the other futures to complete.
        let promise = Promise<[T]>()

        for future in self.subFutures {
            future.onComplete { value in
                if (!value.isSuccess) {
                    promise.complete(value.mapAs())
                }
            }
        }
        self.batchFuture.onComplete (.Immediate) { value in
            promise.complete(value)
        }
        return promise.future
    }


    /* 
        adds a handler that executes on the first Future that fails.
        :params: block a block that will execute 
    **/
    public final func onFirstFail(executor : Executor = .Primary,block:(value:FutureResult<T>, future:Future<T>, index:Int)-> Void) -> Future<[T]> {
        
        return _onFirstFailOrCancel(executor, ignoreCancel:true, block: block)
    }
    
    /**
        takes an array of futures returns a new array of futures converted to the desired Type `<__Type>`
        `Any` is the only type that is guaranteed to always work.
        Useful if you have a bunch of mixed type Futures, and convert them into a list of Future types.
    
        WARNING: if `T as! __Type` isn't legal, than your code may generate an exception.
        
        works iff the following code works:
        
        let t : T
        let s = t as! __Type
        
        example:

    
        - parameter array: array of Futures
        - returns: an array of Futures converted to return type <S>
    */
    public class func convertArray<__Type>(array:[Future<T>]) -> [Future<__Type>] {
        var futures = [Future<__Type>]()
        for a in array {
            futures.append(a.mapAs())
        }
        return futures
        
    }
    
    /**
        takes an array of futures returns a new array of futures converted to the desired Type <S>
        'Any' is the only type that is guaranteed to always work.
        Useful if you have a bunch of mixed type Futures, and convert them into a list of Future types.
    
        - parameter array: array of Futures
        - returns: an array of Futures converted to return type <S>
    */
    public class func convertArray<__Type>(array:[FutureProtocol]) -> [Future<__Type>] {
        
        return array.map { $0.mapAs() }
        
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
    public class func resultsFuture(array : [Future<T>]) -> Future<[FutureResult<T>]> {
        if (array.count == 0) {
            return Future<[FutureResult<T>]>(success: [])
        }
        else if (array.count == 1) {
            let f = array.first!
            
            return f.onComplete { (c) -> [FutureResult<T>] in
                return [c]
            }
        }
        else {
            let promise = Promise<[FutureResult<T>]>()
            var total = array.count

            var result = [FutureResult<T>](count:array.count,repeatedValue:.Cancelled)
            
            for (index, future) in array.enumerate() {
                future.onComplete(.Immediate) { (value) -> Void in
                    promise.synchObject.lockAndModifyAsync({ () -> Int in
                        result[index] = value
                        total--
                        return total
                    }, then: { (currentTotal) -> Void in
                        if (currentTotal == 0) {
                            promise.completeWithSuccess(result)
                        }
                    })
                }
            }
            return promise.future
        }
    }
   
    /**
    takes a future of type `Future<[Completion<T>]` (usually returned from `completionFutures()`) and
    returns a single future of type `Future<[T]>`.   It checks all the completion values and will return .Fail if one of the Futures Failed.
    will return .Cancelled if there were no .Fail completions, but at least one subfuture was cancelled.
    returns .Success iff all the subfutures completed.
    
    - parameter a: completions future of type  `Future<[Completion<T>]>`
    - returns: a single future that returns an array an array of `[T]`.
    */
    public class func futureFromResultsFuture<T>(f : Future<[FutureResult<T>]>) -> Future<[T]> {
        
        return f.onSuccess { (values) -> Completion<[T]> in
            var results = [T]()
            var errors = [ErrorType]()
            var cancellations = 0
            
            for value in values {
                switch value {
                case let .Success(r):
                    results.append(r)
                case let .Fail(error):
                    errors.append(error)
                case .Cancelled:
                    cancellations++
                }
            }
            if (errors.count > 0) {
                if (errors.count == 1) {
                    return .Fail(errors.first!)
                }
                else  {
                    return .Fail(FutureKitError.ErrorForMultipleErrors("FutureBatch.futureFromCompletionsFuture", errors))
                }
            }
            if (cancellations > 0) {
                return .Cancelled
            }
            return .Success(results)
        }
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
    public final class func futureFromArrayOfFutures(array : [Future<T>]) -> Future<[T]> {
        return futureFromResultsFuture(resultsFuture(array))
    }
    

}

extension Future {
    public func combineWith<S>(s:Future<S>) -> Future<(T,S)> {
        return FutureBatch([self,s]).future.map { $0.toTuple() }
    }
}

public func combineFutures<A, B>(a: Future<A>, _ b: Future<B>) -> Future<(A, B)> {
    return FutureBatch([a,b]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C>(a: Future<A>, _ b: Future<B>, _ c: Future<C>) -> Future<(A, B, C)> {
    return FutureBatch([a,b,c]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>) -> Future<(A, B, C, D)> {
    return FutureBatch([a,b,c,d]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>) -> Future<(A, B, C, D, E)> {
    return FutureBatch([a,b,c,d,e]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>) -> Future<(A, B, C, D, E, F)> {
    return FutureBatch([a,b,c,d,e,f]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>) -> Future<(A, B, C, D, E, F, G)> {
    return FutureBatch([a,b,c,d,e,f,g]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>) -> Future<(A, B, C, D, E, F, G, H)> {
    return FutureBatch([a,b,c,d,e,f,g,h]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H, I>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>) -> Future<(A, B, C, D, E, F, G, H, I)> {
    return FutureBatch([a,b,c,d,e,f,g,h,i]).future.map { $0.toTuple() }
}

public func combineFutures<A, B, C, D, E, F, G, H, I, J>(a: Future<A>, _ b: Future<B>, _ c: Future<C>, _ d: Future<D>, _ e: Future<E>, _ f: Future<F>, _ g: Future<G>, _ h: Future<H>, _ i: Future<I>, _ j: Future<J>) -> Future<(A, B, C, D, E, F, G, H, I, J)> {
    return FutureBatch([a,b,c,d,e,f,g,h,i,j]).future.map { $0.toTuple() }
}


