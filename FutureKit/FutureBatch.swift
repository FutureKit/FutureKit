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

    // this future always succeeds.  Returns an array of the individual Future.Completion values
    // for each subFuture.  use future to access
    public var completionsFuture : Future<[Completion<T>]>
    
    // this future succeeds iff all subFutues succeed.
    public lazy var future : Future<[T]> = FutureBatchOf.checkAllCompletionsSucceeded(self.completionsFuture)
    
//    internal final let synchObject : SynchronizationProtocol = GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()

    public init(f : [Future<T>]) {
        self.subFutures = f
        self.completionsFuture = FutureBatchOf.futureWithSubFutures(f)
    }
    
    public convenience init(futures : [AnyObject]) {
        let f : [Future<T>] = FutureBatch.convertArray(futures)
        self.init(f:f)
    }
    
    public convenience init(array : NSArray) {
        let f : [Future<T>] = FutureBatch.convertArray(array as [AnyObject])
        self.init(f:f)
    }
    
    func cancel() {
        for f in self.subFutures {
            f.cancel()
        }
    }
    
    func append(f : Future<T>) -> Future<[T]> {
        self.subFutures.append(f)
        self.completionsFuture = self.completionsFuture.onSuccess { (var completions) -> Future<[Completion<T>]> in
            return f.onComplete { (c) -> [Completion<T>] in
                completions.append(c)
                return completions
            }
        }
        self.future = self.future.onSuccess({ (var results) -> Future<[T]> in
            return f.onSuccess { (result) -> [T] in
                results.append(result)
                return results
            }
        })
        return self.future
    }
    
    func append(f : AnyObject) -> Future<[T]> {
        let future : Future<[T]> = (f as! FutureProtocol).convert()
        return self.append(future)
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
    public class func sequenceCompletionsWithSyncObject<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
        if (array.count < 2) {
            return sequenceCompletionsByChaining(array)
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

    public class func sequenceCompletionsByChaining<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
        
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
            var lastFuture = array.last!
            var firstFutures = array
            firstFutures.removeLast()
            
            return sequenceCompletionsByChaining(firstFutures).onSuccess({ (resultsFromFirstFutures : [Completion<T>]) -> Future<[Completion<T>]> in
                return lastFuture.onComplete { (lastCompletionValue : Completion<T>) -> [Completion<T>] in
                    var allTheResults = resultsFromFirstFutures
                    allTheResults.append(lastCompletionValue)
                    
                    return allTheResults
                }
            })
        }
    }

    public class func futureWithSubFuturesAndSuccessChecks<T>(array : [Future<T>]) -> Future<[T]> {
        return checkAllCompletionsSucceeded(futureWithSubFutures(array))
    }

    // should we use locks or recursion?
    // After a lot of thinking, I think it's probably identical performance
    public class func futureWithSubFutures<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
        if (GLOBAL_PARMS.BATCH_FUTURES_WITH_CHAINING) {
            return sequenceCompletionsByChaining(array)
        }
        else {
            return sequenceCompletionsWithSyncObject(array)
        }
    }

    // will fail if any Future in the array fails.
    // .Success means they all succeeded.
    // the result is an array of each Future's result
    

/*    public class func checkRollup<T>(f:Future<([T],[NSError],[Any?])>) -> Future<[T]> {
        
        let ret = f.onSuccess { (rollup) -> Completion<[T]> in
            
            let (results,errors,cancellations) = rollup

            if (errors.count > 0) {
                if (errors.count == 1) {
                    return .Fail(errors.first!)
                }
                else  {
                    return .Fail(FutureNSError(error: .ErrorForMultipleErrors, userInfo:["errors" : errors]))
                }
            }
            if (cancellations.count > 0) {
                return .Cancelled(cancellations)
            }
            return .Success(results)
        }
        
    }

    
    public class func rollupCompletions<T>(f : Future<[Completion<T>]>) -> Future<([T],[NSError],[Any?])> {
        
        return f.map { (completions:[Completion<T>]) -> ([T],[NSError],[Any?]) in
            var results = [T]()
            var errors = [NSError]()
            var cancellations = [Any?]()
            
            for completion in completions {
                switch completion.state {
                case let .Success:
                    results.append(completion.result)
                case let .Fail:
                    errors.append(completion.error)
                case let .Cancelled(token):
                    cancellations.append(token)
                }
            }
            return (results,errors,cancellations)
        }
    } */

    
    public class func checkAllCompletionsSucceeded<T>(f : Future<[Completion<T>]>) -> Future<[T]> {
        
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
    

/*    class func toTask<T : AnyObject>(future : Future<T>) -> Task {
return future.onSuccess({ (success) -> AnyObject? in
return success
})
} */

}



