//: # Welcome to FutureKit!
//: Make sure you opened this inside the FutureKit workspace.  Opening the playground file directly, usually means it can't import FutureKit module correctly.
//: # Welcome to FutureKit!
//: Make sure you opened this inside the FutureKit workspace.  Opening the play//: # Futures are composable.
g//: adding a block handler to a Future via onComplete/onSuccess doesn't just give you a way to get a result from a future.  It's also a way to create a new Future.
round file directly, usually means it can't import FutureKit module correctly.
import FutureKit
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # Futures are composable.

//: adding a block handler to a Future via onComplete/onSuccess doesn't just give y//: Knowing this we can "chain" futures together to make a complex set of dependencies...
ou a way to get a result from a future.  It's also a way to create a new Future.

let stringFuture = Future<String>(success: "5")

let intOptFuture : Future<Int?>
intOptFuture  = stringFuture.onSuccess { (stringResult) -> Int? in
    let s = Int(stringResult)
    return s
}

intOptFuture.onSuccess { (intResult ://: You can see how we can use the result of the first future, to generate the result of the second, etc.
//: This is such a common and powerful feature of futures there is an alternate version of the same command called 'map'.  The generic signature of map looks like:
//: 'func map<S>((T) -> S) -> Future<S>'
 Int?) -> Void in
    let i = intResult
}

//: Knowing this we can "chain" futures together to make a complex set o//: `futureInt` is automatically be inferred as Future<Int>.
//:  when "chaining" futures together via onSuccess (or map), Failures and Cancellations will automatically be 'forwarded' to any dependent tasks.   So if the first future returns Fail, than all of the dependent futures will automatically fail.
//: this can make error handling for a list of actions very easy.
f dependencies...


stringFuture.onSuccess { (stringResult:String) -> Int in
        let i = Int(stringResult)!
        return i
    }
    .onSuccess { (intResult:Int) -> [Int] in
        let array = [intResult]
        return array
    }
    .onSuccess { (arrayResult : [Int]) -> Void in
        let a = arrayResult.first!
    }

//: You can see how we can use the result of the first future, to generate the result of the second, etc.
//: This is such a common and powerful feature of futures there is an alternate version of the same command called 'map'.  The generic signature of map looks like:
//: 'func map<S>((T) -> S) -> Future<S>'

let futureInt = stringFuture.map { (stringResult) -> Int in
             //: None of the blocks inside of onSuccess/map methods executed. since the first Future failed.  A good way to think about it is, that the "last" future failed because the future it depended upon for an input value, also failed.
   //: # Completion
//: Sometimes you want to create a dependent Future but conditionally decide inside the block whether the dependent block should Succeed or Fail, etc.   For this we have use a handler block with a different generic signature:
 //: 'func onComplete<S>((Completion<T>) -> Completion<S>) -> Future<S>'
 //:  Don't worry if that seems hard to understand.  It's actually pretty straightforward.
//: A Completion is a enumeration that is used to 'complete' a future.  A Future has a var
//: `var completion : Completion<T>?`
//: this var stores the completion value of the Future.  Note that it's optional.  That's because a Future may not be 'completed' yet.  When it's in an uncompleted state, it's completion var will be nil.  
 //: If you examine the contents of a completed Future<T>, you will find a Completion<T> enumeration that must be one of the 3 possible values: `.Success(Result<T>)`, `.Fail(NSError)`, `.Cancel(Any?)`
 Int(stringResult)! }
    
    
//: `futureInt` is automatically be inferred as Future<Int>.
//:  when "chaining" futures together via onSuccess (or map), Fail//: .Success uses an associated type of `Result<T>` is just a generic payload wrapper.  Swift currently has a restriction on using generic associated values ( http://stackoverflow.com/questions/27257522/whats-the-exact-limitation-on-generic-associated-values-in-swift-enums).  So we wrap the generic type T in a Generic 'box' called Result<T>.  The plan will be to remove this in a future version of swift (that no longer has the limitation).
u//: To get around some of the pain of instanciating the enumerations, FutureKit defines a set of global functions that are easier to read.
r//:     public func SUCCESS(t) -> Completion<T>
e//:     public func FAIL(e) -> Completion<T>
s//:     public func CANCELLED(canceltoken) -> Completion<T>
 //:     public func CANCELLED(canceltoken) -> Completion<T>
an//: But completion has a fourth enumeration case `.CompleteUsing(Future<T>)`.   This is very useful when you have a handler that wants to use some other Future to complete itself.   This completion value is only used as a return value from a handler method.
//: First let's create an unreliable Future, that fails most of the time (80%)
d Cancellations will automatically be 'forwarded' to any dependent tasks.   So if the first future returns Fail, than all of the dependent futures will automatically fail.
//: this can make error handling for a list of actions very easy.

let gonnaTryHardAndNotFail = Promise<String>()
let futureThatHopefullyWontFail = gonnaTryHardAndNotFail.future

futureThatHopefullyWontFail
        .onSuccess { (s:String) -> Int in
                return Int(s)!
         //: Here is a function that will call itself recurisvely until it finally succeeds.
   }
        .map { (intResult:Int) -> [Int] in     // 'map' is same as 'onSuccess'. 
                                               //  Use whichever you like.
                let i = intResult
                return [i]
            }
        .map {
            (arrayResult : [Int]) -> Void in
            let a = arrayResult.first
            }
        .onFail { (error) -> Void in
            let e = error
            }

gonnaTryHardAndNotFail.completeWithFail("Sorry. Maybe Next time.")
//: None of the blocks inside of onSuccess/map methods executed. since the first Future failed.  A good way to think about it is, that the "last" future failed because the future it depended upon for an input value,//: If you select "Editor -> Execute Playground" you can see this number change.
 //: ## CompletionState
//: since onComplete will get a Completion<Int>, the natural idea would be to use switch (completion)
also failed.



//: # Completion
//: Sometimes you want to create a dependent Future but conditionally decide inside the block whether the dependent block should Succeed or Fail, etc.   For this we have use a handler block with a different generic signature:

//: 'func onComplete<S>((Completion<T>) -> Completion<S>) -> Future<S>'

//:  Don't worry if that seems hard to understand. //: But it's annoying for a few reasons.
//: 1. You have to add either `case .CompleteUsing`:, or a `default:`, because Swift requires switch to be complete.  But it's illegal to receive that completion value, in this function.  That case won't happen.
//: 2. .Success currently uses an associated type of 'Result<T>'.  Which has more to do with a bug/limitation in Swift Generic enumerations (that we expect will get fixed in the future).
//: So the simpler and alternate is to look at the var 'state' on the completion value.  It uses the related enumeration CompletionState.  Which is a simpler enumeration.
 //: Let's rewrite the same handler using the var `state`.
It's actually pretty straightforward.
//: A Completion is a enumeration that is used to 'complete' a future.  A Future has a var
//: `var completion : Completion<T>?`
//: this var stores the completion value of the Future.  Note that it's optio//: If all you care about is success or fail, you can use the isSuccess var
nal.  That's because a Future may not be 'completed' yet.  When it's in an uncompleted state, it's completion var will be nil.  

//: If you examine the contents of a completed Future<T>, you will find a //: # onComplete handler varients
//: There are actually 4 different variants of onComplete() handler
//: - 'func onComplete(block:(Completion<T>) -> Completion<__Type>)'
//: - 'func onComplete(block:(Completion<T>) -> Void)'
//: - 'func onComplete(block:(Completion<T>) -> __Type)'
//: - 'func onComplete(block:(Completion<T>) -> Future<S>)'
Completion<T> enumeration that must be one of the 3 possible values: `.Success(Result<T>)`, `.Fai//: 'func onComplete(block:(Completion<T>) -> Completion<__Type>)'
l//: The first version we have already seen.  It let's you receive a completion value from a target future, and return any sort of new result it wants (maybe it want's to Fail certain 'Success' results from it's target, or visa-versa).  It is very flexible.  You can compose a new future that returns anything you want.
(//: Here we will convert a .Fail into a .Success, but we still want to know if the Future was Cancelled:
NSError)`, `.Cancel(Any?)`

let anotherFuture5 = Future(success: 5)
switch anotherFuture5.completion! {
    case let .Success(s):
        let x = s.result
    default:
        break
    }

//: .Success uses an associated type of `Result<T>` is just a generic payload wrapper.  Swift currently has a restriction on u//: 'func onComplete(block:(Completion<T>) -> Void)'
s//: We been using this one without me even mentioning it.  This block always returns a type of Future<Void> that always returns success.  So it can be composed and chained if needed.
ing generic associated values ( http://stackoverflow.com/questions/27257522/whats-the-exact-limitation-on-generic-associated-values-in-s//: 'func onComplete(block:(Completion<T>) -> __Type)'
w//: This is almost identical to the 'Void' version EXCEPT you want to return a result of a different Type.  This block will compose a new future that returns .Success(result) where result is the value returned from the block.
ift-enums).  So we wrap the generic type T in a Generic 'box' called Result<T>.  The plan will be to remove this in a future version of swift (that no longer has the limitation).

//: To get around some of the pain of instanciating the enumerations, Futu//: 'func onComplete(block:(Completion<T>) -> Future<__Type>)'
r//: This version is equivilant to returning a Completion<__Type>.ContinueUsing(f) (using the first varient on onComplete).  It just looks cleaner:
eKit defines a set of global functions that are easier to read.

//:     public func SUCCESS(t) -> Completion<T>

//:     public func FAIL(e) -> Completion<T>

//:     public func CANCELLED(canceltoken) -> Completion<T>

//:     public func CANCELLED(canceltoken) -> Completion<T>


//: But completion has a fourth enumeration case `.CompleteUsing(Future<T>)`.   This is very useful when you have a handler that wants to use some other Future to complete itself.   This completion value is only used as a return value from a handler method.
//: First let's create an unreliable Future, that fails most of the time (80%)
func iMayFailRandomly() -> Future<String>  {
    let p = Promise<String>()
    
    Executor.Default.execute { () -> Void in

        // This is a random number from 0..4.
        // So we only have a 20% of success!
        let randomNumber = arc4random_uniform(5)
        if (randomNumber == 0) {
            //: # Documentation TODO: 
//:     (..Before we ship 1.0 pretty please..)
//: - onSuccess Handlers (it's pretty much just like onComplete handlers, but easier).
//: - onFail/onCancel and how they DON'T return a new future! (They aren't as composable as onComplete/onSuccess for some very good reasons).
//: - Executors - and how to dispatch your code quickly and easy in any queue or thread you want.  And how to guarantee that your code always executes in the dispatch queue you require, 
//: - Cancel  -  How to write a Future that supports cancel().  And how cancel() can chain through composed futures.
//: FutureBatch - how to get your Futures to run in parallel and wait for them all to complete.
//: As() - what Future.As() does and how to use it, and how doing it wrong will crash your code (and that's a good thing).  (Hint: it just calls `as!`)
//: - How to give your Objective-C code a Future it can use (cause it doesn't like swift generic classes!) (Hint: FTask).
//: - CoacoPods and Carthage support.
//: - How to play super friendly integrate with the Bolt Framework (BFTask <--> Future conversion in a few easy lines!).
p//: # Eventually
//:     cause I have so much free time to write more things
//: Advanced topics like:
//: - Get to 100% test coverage please.
//: - Configuring the Primary Executors (and the endless debate between Immediate vs Async execution)..
//: - how to tune synchronization.  (NSLock vs dispatch barrier queues).
//: - add a real var to a swift extension in a few lines.
//: - write code that can switch at runtime between Locks/Barriers and any other snychronization strategy you can bake up.
.c