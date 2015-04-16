//
//  Future-Sequences.swift
//  FutureKit
//
//  Created by Michael Gray on 4/13/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

// ---------------------------------------------------------------------------------------------------
//
//   CONVERT an Array of Futures into a single Future
//
// ---------------------------------------------------------------------------------------------------

public class FutureBatch<T> {
    
    var subFutures  = [Future<T>]()
    var completions = [Completion<T>]()
    var future : Future<[Completion<T>]>
    
    private final let synchObject : SynchronizationProtocol = FUTUREKIT_GLOBAL_PARMS.LOCKING_STRATEGY.lockObject()

    init(f : [Future<T>]) {
        self.subFutures = f
        self.future = FutureBatch.sequenceCompletions(f)
        
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

            var result = [Completion<T>](count:array.count,repeatedValue:.Cancelled(()))
            
            for (index, future) in enumerate(array) {
                future.onCompleteWith(.Immediate) { (completion: Completion<T>) -> Void in
                    
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

    // should we use locks or recursion?
    // After a lot of thinking, I think it's probably identical performance
    public class func sequenceCompletions<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
        if (FUTUREKIT_GLOBAL_PARMS.BATCH_FUTURES_WITH_CHAINING) {
            return sequenceCompletionsByChaining(array)
        }
        else {
            return sequenceCompletionsWithSyncObject(array)
        }
    }


    // this is the same as above, but is less type safe (everything is converted to Any)
    // this is useful if you have an array of Futures with mixed types
    public class func sequenceCompletionsOfAny(array : [FutureProtocol]) -> Future<[Completion<Any>]> {
        
        var futures = [Future<Any>]()
        for a in array {
            futures.append(a.asFutureAny())
        }
        return sequenceCompletions(futures)
    }



    // will fail if any Future in the array fails.
    // .Success means they all succeeded.
    // the result is an array of each Future's result
    public class func sequenceFutures<T>(array : [Future<T>]) -> Future<[T]> {
        
        let f = sequenceCompletions(array)
        
        return f.onSuccess { (completions:[Completion<T>]) -> Completion<[T]> in
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

/*    class func toTask<T : AnyObject>(future : Future<T>) -> Task {
return future.onSuccess({ (success) -> AnyObject? in
return success
})
} */


    // this is the same as above, but is less type safe (everything is converted to Any)
    // this is useful if you have an array of Futures with mixed types
    public class func sequenceAnyFutures(array : [FutureProtocol]) -> Future<[Any]> {
        
        var futures = [Future<Any>]()
        for a in array {
            futures.append(a.asFutureAny())
        }
        return sequenceFutures(futures)
    }
    // Takes a sequence of Futures and turns them into a single future
    public class func sequence(array : [FutureProtocol]) -> Future<Void> {
        
        return sequenceAnyFutures(array).convert()
    }
    public class func sequenceOptionals(array : [FutureProtocol?]) -> Future<Void> {
        
        return sequence(unwindArrayOfOptionals(array))
    }

    public class func sequenceTask(array : [FutureProtocol]) -> Future<AnyObject?> {
        
        return sequenceAnyFutures(array).onSuccess { (success) -> AnyObject? in
            return nil
        }
    }
}



