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

// this always 'succeeds' once all Futures have finished
// each individual future in the array may succeed or fail
// you have to check the result of the array individually if you care

// Types are perserved, but all elements must be of the same type
private func sequenceCompletionsWithLocks<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
    
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
        
        var total = OSAtomicInt32(Int32(array.count))
        let lock = NSObject()
        
        var result = [Completion<T>](count:array.count,repeatedValue:.Cancelled)
        
        for (index, future) in enumerate(array) {
            future.onComplete({ (completion: Completion<T>) -> Void in
                
                lock.THREAD_SAFE_SYNC {
                    result[index] = completion
                }
                if (total.decrement() == 0) {
                    promise.completeWithSuccess(result)
                }
            })
        }
        return promise.future
    }
}

private func sequenceCompletionsWithRecursion<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
    
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
        
        return FutureKit.sequenceCompletionsWithRecursion(firstFutures).onSuccessResult({ (resultsFromFirstFutures : [Completion<T>]) -> Future<[Completion<T>]> in
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
public func sequenceCompletions<T>(array : [Future<T>]) -> Future<[Completion<T>]> {
    return FutureKit.sequenceCompletionsWithLocks(array)
}


// this is the same as above, but is less type safe (everything is converted to Any)
// this is useful if you have an array of Futures with mixed types
public func sequenceCompletionsOfAny(array : [FutureProtocol]) -> Future<[Completion<Any>]> {
    
    var futures = [Future<Any>]()
    for a in array {
        futures.append(a.asFutureAny())
    }
    return sequenceCompletions(futures)
}



// will fail if any Future in the array fails.
// .Success means they all succeeded.
// the result is an array of each Future's result
public func sequenceFutures<T>(array : [Future<T>]) -> Future<[T]> {
    
    let f = sequenceCompletions(array)
    
    return f.onSuccessResult { (completions:[Completion<T>]) -> Completion<[T]> in
        var results = [T]()
        var errors = [NSError]()
        var cancellations = 0
        
        for completion in completions {
            switch completion.state {
            case let .Success:
                results.append(completion.result)
            case let .Fail:
                errors.append(completion.error)
            case .Cancelled:
                cancellations++
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
        if (cancellations > 0) {
            return .Cancelled
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
public func sequenceAnyFutures(array : [FutureProtocol]) -> Future<[Any]> {
    
    var futures = [Future<Any>]()
    for a in array {
        futures.append(a.asFutureAny())
    }
    return sequenceFutures(futures)
}

public func sequence(array : [FutureProtocol]) -> Future<Void> {
    
    return sequenceAnyFutures(array).convert()
}
public func sequenceOptionals(array : [FutureProtocol?]) -> Future<Void> {
    
    return sequence(unwindArrayOfOptionals(array))
}

public func sequenceTask(array : [FutureProtocol]) -> Future<AnyObject?> {
    
    return sequenceAnyFutures(array).onSuccess { (success) -> AnyObject? in
        return nil
    }
}


public func toFutureAnyObjectXXX<T : AnyObject>(f : Future<T>) -> Future<AnyObject> {
    return f.onSuccessResult { tval -> AnyObject in
        return tval
    }
}


