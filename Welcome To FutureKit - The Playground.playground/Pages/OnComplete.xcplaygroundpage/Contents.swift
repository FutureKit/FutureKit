//: [Previous](@previous)

import FutureKit
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # onComplete handler varients
//: There are actually 4 different variants of onComplete() handler.  Each returns a different Type.
//: - 'func onComplete(block:(FutureType<T>) -> Completion<__Type>) -> Future<_Type>'
//: - 'func onComplete(block:(FutureType<T>) -> Void)  -> Future<Void>'
//: - 'func onComplete(block:(FutureType<T>) -> __Type) -> Future<__Type>'
//: - 'func onComplete(block:(FutureType<T>) -> Future<__Type>) -> Future<__Type>'
// we are gonna use this future for the next few examples.
let sampleFuture = Future(success: 5)
//: 'func onComplete(block:(FutureType<T>) -> Completion<__Type>) -> Future<_Type>'

//: The first version we have already seen.  It let's you receive a completion value from a target future, and return any sort of new result it wants (maybe it want's to Fail certain 'Success' results from it's target, or visa-versa).  It is very flexible.  You can compose a new future that returns anything you want.

//:  When you see the type *`__Type`* - this is FutureKit's "hint" that you need to change it to the type of your choice.  if you use a lot of XCode auto-completion, this will help you visibily remember you have to manually change the value.

//: Here we will convert a .Fail into a .Success, but we still want to know if the Future was Cancelled:
let newFuture = sampleFuture.onComplete { (result) -> Completion<String> in
    switch result {
        
    case let .Success(value):
        return .Success(String(value))
        
    case .Fail(_):
        return .Success("Some Default String we send when things Fail")
        
    case .Cancelled:
        return .Cancelled
    }
}


//: 'func onComplete(block:(Completion<T>) -> Void)'

//: We been using this one without me even mentioning it.  This block always returns a type of Future<Void> that always returns success.  So it can be composed and chained if needed.
sampleFuture.onComplete { (c) -> Void in
    if (c.isSuccess) {
        // store this great result in a database or something.
    }
}

//: 'func onComplete(block:(Completion<T>) -> __Type)'

//: This is almost identical to the 'Void' version EXCEPT you want to return a result of a different Type.  This block will compose a new future that returns .Success(result) where result is the value returned from the block.
let futureString  = sampleFuture.onComplete { (result) -> String in
    switch result {
    case let .Success(value):
        return String(value)
    default:
        return "Some Default String we send when things Fail"
    }
}
let string = futureString.result!


//: 'func onComplete(block:(Completion<T>) -> Future<__Type>)'

//: This version is equivilant to returning a COMPLETE_USING(f).
//: It just looks cleaner:
func coolFunctionThatAddsOneInBackground(num : Int) -> Future<Int> {
    // let's dispatch this to the low priority background queue
    return Future(.Background) { () -> Int in
        let ret = num + 1
        return ret
    }
}
func coolFunctionThatAddsOneAtHighPriority(num : Int) -> Future<Int> {
    // let's dispatch this to the high priority UserInteractive queue
    return Future(.UserInteractive) { () -> Int in
        // so much work here to get a 2.
        let ret = num + 1
        return ret
    }
}
let coolFuture = sampleFuture.onComplete { (result) -> Completion<Int> in
    
    switch result {
    case let .Success(value):
        let beforeAdd = value
        let subFuture = coolFunctionThatAddsOneInBackground(value).onComplete { (c2) -> Future<Int> in
                let afterFirstAdd = c2.value
                return coolFunctionThatAddsOneAtHighPriority(c2.value)
        }
        return .CompleteUsing(subFuture)
    default:
        return result.asCompletion()
    }
}
coolFuture.onSuccess { (result) -> Void in
    let x = result
    
}


//: [Next](@next)
