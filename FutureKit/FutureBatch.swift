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
    
    public var subFutures  = [Future<T>]()

    /** 
        `completionsFuture` returns an array of individual Completion<T> values
        :returns: a `Future<[Completion<T>]>` always returns with a Success.  Returns an array of the individual Future.Completion values for each subFuture.
    */
    public var completionsFuture : Future<[Completion<T>]>
    

    /**
        batchFuture succeeds iff all subFutures succeed.  it does not complete until all futures have been completed within the batch (even if some fail or are cancelled).
    */
    public lazy var batchFuture : Future<[T]> = FutureBatchOf.futureFromCompletionsFuture(self.completionsFuture)
    
    /**
        future succeeds iff all subFutures succeed.  returns Fail/Cancel as soon as the first subFuture is failed or cancelled.
        future may complete, while some subFutures are still running, if a Future Fails or is Cancelled.
    
        if you have 'cancellable' Futures, you can instead use `batchFuture` and  `cancelRemainingFuturesOnFirstFail()` or `cancelRemainingFuturesOnFirstFailOrCancel()`.  batchFuture will always wait for all subFutures to complete before finishing.
        this wi
    */
    public lazy var future : Future<[T]> = self._onFirstFailOrCancel()

    typealias onEachCompleteBlock = (completion:Completion<T>, index:Int)-> Void

    
    private typealias _onEachTuple = (completion:Completion<T>, index:Int)

    public init(f : [Future<T>]) {
        self.subFutures = f
        self.completionsFuture = FutureBatchOf.completionsFuture(f)
    }
    
    public convenience init(futures : [AnyObject]) {
        let f : [Future<T>] = FutureBatch.convertArray(futures)
        self.init(f:f)
    }
    
    public convenience init(array : NSArray) {
        let f : [Future<T>] = FutureBatch.convertArray(array as [AnyObject])
        self.init(f:f)
    }
    
    /**
        will forward a cancel request to each subFuture
        Doesn't guarantee that a particular future gets canceled
    */
    func cancel() {
        for f in self.subFutures {
            f.cancel()
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

    func cancelRemainingFuturesOnFirstFail() {
        self.future.onComplete { (completion) -> Void in
            if (completion.isFail) {
                self.cancel()
            }
        }
    }

    
    /**
        this can add a new future to existing FutureBatch.
        this is useful if you want to add a Future after already initializing a Batch.
        
        Note - this function modifies the vars 'future' and 'completionsFuture'.  If you have already applied handlers to those var's they will not include the results of this future.
    
        example:
            
            let batch = FutureBatch([future1,future2])
            batch.future.onComplete((array) -> Void in {
               //  array.count == 2
            }
            batch.append([future3,future4])

        In the previous example, the onComplete handler will still only return an array of 2 results.
    
            let batch = FutureBatch([future1,future2])
            batch.append([future3,future4])
            batch.future.onComplete((array) -> Void in {
                //  array.count == 4
            }
    
        :returns: the new value of the var 'future'
    
    */
    public func append(futures : [Future<T>]) -> Future<[T]> {
        for f in futures {
            self.subFutures.append(f)
            self.completionsFuture = self.completionsFuture.onSuccess { (var completions) -> Future<[Completion<T>]> in
                return f.onComplete { (c) -> [Completion<T>] in
                    completions.append(c)
                    return completions
                }
            }
            self.batchFuture = self.batchFuture.onSuccess({ (var results) -> Future<[T]> in
                return f.onSuccess { (result) -> [T] in
                    results.append(result)
                    return results
                }
            })
        }
        self.future = self._onFirstFailOrCancel()
        return self.future
    }
    
    public final func append(futures : [AnyObject]) -> Future<[T]> {
        let _futures : [Future<T>] = FutureBatch.convertArray(futures)
        return self.append(_futures)
    }

    public final  func append(f : Future<T>) -> Future<[T]> {
        return self.append([f])
    }
    
    public final  func append(f : AnyObject) -> Future<[T]> {
        let future : Future<[T]> = (f as! FutureProtocol).convert()
        return self.append(future)
    }

    
    
    public final func onEachComplete<__Type>(executor : Executor,block:(completion:Completion<T>, future:Future<T>, index:Int)-> __Type) -> Future<[__Type]> {
        
        var futures = [Future<__Type>]()
        
        for (index, future) in enumerate(self.subFutures) {
            
            let f = future.onComplete({ (completion) -> __Type in
                return block(completion: completion, future:future,index: index)
            })
            futures.append(f)
        }
        return FutureBatchOf<__Type>.futureFromArrayOfFutures(futures)
    }
    
    public final func onEachComplete<__Type>(block:(completion:Completion<T>, future:Future<T>,index:Int)-> __Type)  -> Future<[__Type]> {
        return self.onEachComplete(.Primary, block: block)
    }

    private final func _onFirstFailOrCancel(executor : Executor = .Immediate,block:((error:NSError, future:Future<T>, index:Int)-> Void)? = nil) -> Future<[T]> {
        
        let promise = Promise<[T]>()

        // we are gonna make a Future that succeeds when it finds a failure or cancel
        typealias firstFailOrACancelTuple = (completion:Completion<T>,future:Future<T>,index:Int)
        let failOrCancelPromise = Promise<firstFailOrACancelTuple>()
        
        for (index, future) in enumerate(self.subFutures) {
            future.onComplete({ (completion) -> Void in
                if (completion.state != .Success) {
                    failOrCancelPromise.completeWithSuccess((completion, future, index))
                }
            })
        }
        self.batchFuture.onComplete { (completion) -> Void in
            if (completion.state == .Success) {
                failOrCancelPromise.completeWithCancel()
            }
        }
        let failureFuture = failOrCancelPromise.future
        // a success is a fail or cancel!
        failureFuture.onSuccess (executor) { (result) -> Void in
            if (result.completion.isFail) {
                block?(error: result.completion.error, future: result.future, index: result.index)
            }
            promise.complete(result.completion.convert())
        }
        self.batchFuture.onComplete (.Immediate) { (completion) -> Void in
            promise.complete(completion)
        }
        return promise.future
    }


    /* 
        adds a handler that executes on the first Future that fails.
        :params: block a block that will execute 
    **/
    public final func onFirstFail(executor : Executor,block:(error:NSError, future:Future<T>, index:Int)-> Void) -> Future<[T]> {
        return _onFirstFailOrCancel(executor: executor, block: block)
    }
    
    public final func onFirstFail(block:(error:NSError, future:Future<T>, index:Int)-> Void)  -> Future<[T]> {
        return _onFirstFailOrCancel(executor: .Primary, block: block)
    }

    public class func convertArray<S>(array:[Future<T>]) -> [Future<S>] {
        var futures = [Future<S>]()
        for a in array {
            futures.append(a.convert())
        }
        return futures
        
    }
    public class func convertArray<S>(array:[AnyObject]) -> [Future<S>] {
        
        var futures = [Future<S>]()
        for a in array {
            let f = a as! FutureProtocol
            futures.append(f.convert())
        }
        return futures
        
    }
    
    // this always 'succeeds' once all Futures have finished
    // each individual future in the array may succeed or fail
    // you have to check the result of the array individually if you care

    // Types are perserved, but all elements must be of the same type
    public class func completionsFuture(array : [Future<T>]) -> Future<[Completion<T>]> {
        if (array.count == 0) {
            let result = [Completion<T>]()
            return Future<[Completion<T>]>(success: result)
        }
        else if (array.count == 1) {
            let f = array.first!
            return f.onComplete({ (c: Completion<T>) -> [Completion<T>] in
                return [c]
            })
        }
        else {
            let promise = Promise<[Completion<T>]>()
            var total = array.count

            var result = [Completion<T>](count:array.count,repeatedValue:.Cancelled)
            
            for (index, future) in enumerate(array) {
                future.onComplete(.Immediate) { (completion: Completion<T>) -> Void in
                    promise.synchObject.modifyAsync({ () -> Int in
                        result[index] = completion
                        total--
                        return total
                    }, done: { (t) -> Void in
                        if (t == 0) {
                            promise.completeWithSuccess(result)
                        }
                    })
                }
            }
            return promise.future
        }
    }
   
    public class func futureFromCompletionsFuture<T>(f : Future<[Completion<T>]>) -> Future<[T]> {
        
        return f.onSuccess { (completions:[Completion<T>]) -> Completion<[T]> in
            var results = [T]()
            var errors = [NSError]()
            var cancellations = 0
            
            for completion in completions {
                switch completion.state {
                case let .Success:
                    let r = completion.result
                    results.append(r)
                case let .Fail:
                    errors.append(completion.error)
                case let .Cancelled:
                    cancellations++
                }
            }
            if (errors.count > 0) {
                if (errors.count == 1) {
                    return FAIL(errors.first!)
                }
                else  {
                    return FAIL(FutureNSError(error: .ErrorForMultipleErrors, userInfo:["errors" : errors]))
                }
            }
            if (cancellations > 0) {
                return CANCELLED()
            }
            return SUCCESS(results)
        }
    }
    public final class func futureFromArrayOfFutures(array : [Future<T>]) -> Future<[T]> {
        return futureFromCompletionsFuture(completionsFuture(array))
    }
    

/*    class func toTask<T : AnyObject>(future : Future<T>) -> Task {
return future.onSuccess({ (success) -> AnyObject? in
return success
})
} */

}



