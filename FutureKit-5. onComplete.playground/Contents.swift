//: # Welcome to FutureKit!
//: Make sure you opened this inside the FutureKit workspace.  Opening the playground file directly, usually means it can't import FutureKit module correctly.
import FutureKit
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # onComplete handler varients
//: There are actually 4 different variants of onComplete() handler.  Each returns a different Type.
//: - 'func onComplete(block:(Completion<T>) -> Completion<__Type>)'
//: - 'func onComplete(block:(Completion<T>) -> Void)'
//: - 'func onComplete(block:(Completion<T>) -> __Type)'
//: - 'func onComplete(block:(Completion<T>) -> Future<S>)'
// we are gonna use this future for the next few examples.
let sampleFuture = Future(success: 5)
//: 'func onComplete(block:(Completion<T>) -> Completion<__Type>)'

//: The first version we have already seen.  It let's you receive a completion value from a target future, and return any sort of new result it wants (maybe it want's to Fail certain 'Success' results from it's target, or visa-versa).  It is very flexible.  You can compose a new future that returns anything you want.

//:  When you see the type *`__Type`* - this is FutureKit's "hint" that you need to change it to the type of your choice.  if you use a lot of XCode auto-completion, this will help you visibily remember you have to manually change the value.

//: Here we will convert a .Fail into a .Success, but we still want to know if the Future was Cancelled:
sampleFuture.onComplete { (c) -> Completion<String> in
    switch c.state {
    
    case .Success:
        return SUCCESS(String(c.result))
        
    case .Fail:
        return SUCCESS("Some Default String we send when things Fail")
        
    case let .Cancelled(token):
        return CANCELLED()
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
let futureString  = sampleFuture.onComplete { (c) -> String in
    switch c.state {
    case .Success:
        return String(c.result)
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
let coolFuture = sampleFuture.onComplete { (c1) -> Future<Int> in
    
    let beforeAdd = c1.result
    return coolFunctionThatAddsOneInBackground(c1.result)
            .onComplete { (c2) -> Future<Int> in
                let afterFirstAdd = c2.result
                return coolFunctionThatAddsOneAtHighPriority(c2.result)
            }
}
coolFuture.onSuccess { (result) -> Void in
    let x = result
    
}

