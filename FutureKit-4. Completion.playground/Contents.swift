//: # Welcome to FutureKit!
//: Make sure you opened this inside the FutureKit workspace.  Opening the playground file directly, usually means it can't import FutureKit module correctly.
import FutureKit
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # Completion
//: Sometimes you want to create a dependent Future but conditionally decide inside the block whether the dependent block should Succeed or Fail, etc.   For this we have use a handler block with a different generic signature:

//: 'func onComplete<S>((Completion<T>) -> Completion<S>) -> Future<S>'

//:  Don't worry if that seems hard to understand.  It's actually pretty straightforward.
//: A Completion is a enumeration that is used to 'complete' a future.  A Future has a var
//: `completion : Completion<T>?`
//: this var stores the completion value of the Future.  Note that it's optional.  That's because a Future may not be 'completed' yet.  When it's in an uncompleted state, it's completion var will be nil.  

//: If you examine the contents of a completed Future<T>, you will find a Completion<T> enumeration that must be one of the 3 possible values: `.Success(Result<T>)`, `.Fail(NSError)`, `.Cancel(Any?)`

let futureInt = Future(success: 5)
switch futureInt.completion! {
    case let .Success(s):
        let x = s
    default:
        break
    }

//: .Success uses an associated type of `Result<T>` is just a generic payload wrapper.  Swift currently has a restriction on using generic associated values ( http://stackoverflow.com/questions/27257522/whats-the-exact-limitation-on-generic-associated-values-in-swift-enums).  So we wrap the generic type T in a Generic 'box' called Result<T>.  The plan will be to remove this in a future version of swift (that no longer has the limitation).

//: To get around some of the pain of instanciating the enumerations, FutureKit defines a set of global functions that are easier to read.

//:     public func SUCCESS(t) -> Completion<T>

//:     public func FAIL(e) -> Completion<T>

//:     public func CANCELLED() -> Completion<T>

//: But completion has a fourth enumeration case `.CompleteUsing(Future<T>)`.   This is very useful when you have a handler that wants to use some other Future to complete itself.   This completion value is only used as a return value from a handler method.

//:    public func COMPLETE_USING(Future<T>) 

//: First let's create an unreliable Future, that fails most of the time (80%)
func iMayFailRandomly() -> Future<String>  {
    let p = Promise<String>()
    
    Executor.Default.execute { () -> Void in

        // This is a random number from 0..4.
        // So we only have a 20% of success!
        let randomNumber = arc4random_uniform(5)
        if (randomNumber == 0) {
            p.completeWithSuccess("Yay")
        }
        else {
            p.completeWithFail("Not lucky Enough this time")
        }
    }
    return p.future
}
//: Here is a function that will call itself recurisvely until it finally succeeds.
func iWillKeepTryingTillItWorks(attemptNo: Int) -> Future<Int> {
    
    let numberOfAttempts = attemptNo + 1
    return iMayFailRandomly().onComplete { (completion) -> Completion<Int> in
        switch completion.state {
            
        case .Success:
            let s = completion.result
            return SUCCESS(numberOfAttempts)
            
        default: // we didn't succeed!
            let nextFuture = iWillKeepTryingTillItWorks(numberOfAttempts)
            return COMPLETE_USING(nextFuture)
        }
    }
}
let keepTrying = iWillKeepTryingTillItWorks(0)
keepTrying.onSuccess { (tries) -> Void in
    let howManyTries = tries
}
//: If you select "Editor -> Execute Playground" you can see this number change.

//: ## CompletionState
//: since onComplete will get a Completion<Int>, the natural idea would be to use switch (completion)
futureInt.onComplete { (completion : Completion<Int>) -> Void in
    switch completion {
        
    case let .Success(r):
        let five = r
    
    case let .Fail(error):
        let e = error
    
    case .Cancelled:
        break
        
    case let .CompleteUsing(f):
        assertionFailure("hey! FutureKit promised this wouldn't happen!")
        break;
    }
}
//: But it's annoying for a few reasons.
//: 1. You have to add either `case .CompleteUsing`:, or a `default:`, because Swift requires switch to be complete.  But it's illegal to receive that completion value, in this function.  That case won't happen.
//: 2. .Success currently uses an associated type of 'Result<T>'.  Which has more to do with a bug/limitation in Swift Generic enumerations (that we expect will get fixed in the future).
//: So the simpler and alternate is to look at the var 'state' on the completion value.  It uses the related enumeration CompletionState.  Which is a simpler enumeration.

//: Let's rewrite the same handler using the var `state`.
futureInt.onComplete { (completion : Completion<Int>) -> Void in
    switch completion.state {
    case .Success:
        let five = completion.result
    case .Fail:
        let e = completion.error
    case .Cancelled:
        break
    }
}

//: If all you care about is success or fail, you can use the isSuccess var
futureInt.onComplete { (completion : Completion<Int>) -> Void in
    if completion.isSuccess {
        let five = completion.result
    }
    else {
        // must have failed or was cancelled
    }
}
