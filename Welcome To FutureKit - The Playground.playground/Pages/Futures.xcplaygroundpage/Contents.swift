//: # Welcome to FutureKit!
//: Make sure you opened this inside the FutureKit workspace.  Opening the playground file directly, usually means it can't import FutureKit module correctly.  If import FutureKit is failing, make sure you build the OSX Framework in the workspace!
import FutureKit
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # Let's get started!

//: This is a Future:
let future5Int : Future<Int>
//: It's not a regular Int.  It's a "Future" Int.
//: At some point in the future, this object will "generate" an Int. Or maybe it will fail.
//: I called the variable "future5Int" because it will eventualy at some point in the future it will return a Int value of 5.  Very useful if you need a 5 at somepoint in the future.
future5Int = Future(success: 5)
//: Ok.  I told a small lie. Cause now the value 5 is already there.  This was a Future that was created in a "completed" state.  It has a result.  The Future was successful, and it has a result of 5.  Very good.
let resultOfFuture5 = future5Int.result!
//: Sometimes a Future will fail. Maybe the database is all out if 5's.  So instead of 5, we are gonna return a failure.  No number 5 for you.
let futureFail = Future<Int>(failWithErrorMessage:"I have no 5's for you today.")
let failed5result = futureFail.result
let e = futureFail.error
//: Sometimes your request is cancelled. It's not usually because of a failure, and usually means we just wanted to halt an async process before it was done.  Optionally you can send a reason, but it's not required.  In FutureKit a Fail means that something went wrong, and you should cope with that.  a Cancel is usually considered "legal", like canceling active API requests when a window is closed.
let cancelledFuture = Future<Int>(cancelled: ())
let cancelledResult = cancelledFuture.result
//: These aren't very interesting Futures. Let's make something a bit more interesting:
let asyncFuture5 = Future(.Background) { () -> Int in
    return 5
}
//: This is also a Future<Int>. The swift compiler figured it out, because I added a block that returns an Int.
//: But what is that (.Default) thing?  What does that mean?  Let's check the results:
let firstAttempt = asyncFuture5.result
// usually this is nil. Try "Editor"..."Execute Playground" to see if value changes at all.
//: **WTF!?**  why is the result nil?  should it be? Sometimes when you run the playground, you will get a 5.  Sometimes a nil.
//: That's because the block that returns the 5 may not have finished running yet.
//: Let's wait and then try again looking at the result AGAIN:
NSThread.sleepForTimeInterval(0.1)
let secondAttempt = asyncFuture5.result
//: that's because we created a Future and told it to "run" inside the .Default Executor. Which is a shortcut way of saying "dispatch this block to the built in iOS queue "QOS_CLASS_DEFAULT" and then return the results back to the Future".
//: We will talk more about Executors and how they can encapulate dispatch_queue, NSOperationQueue, and some other interesting execution issues, in a different playground.
//: But how are we supposed to get a result?

let f = asyncFuture5.onSuccess(.Main) { (value) -> Int in
    let five = value
    return five
}
//: Now we have a result! We got our 5.
//: If you are running XCode, hold down the option button and click on (result) in the block above.  It should show something like `let result: (Int)`
//: The Swift compiler automatically knows that result is an Int, because asyncFuture5 is defined as a Future<Int>.

//: Future's are type safe.  You can't add an onSuccess handler block that wants a String to a Future<Int>.
//: if you uncomment the next line, watch how compile complains (check the Console Output on the Timeline if you don't see an error in the editor)


// asyncFuture5.onSuccess { (value: String) -> Void in  }

//: changing `(result:String)` to `(result:Int)` fixes the bug.  (Or just remove the type definition and let Swift infer the type needed)


//: We can also add handlers for Fail and Cancel:

futureFail.onFail { (error) -> Void in
    print(error)
}

cancelledFuture.onCancel { () -> Void in
    let e = "cancelled!"
    print("cancelled")
}

//: But if you don't want to add 3 handlers, it's more common to just add a single onComplete handler

asyncFuture5.onComplete { (result : FutureResult<Int>) -> Void in
    switch result {
    case let .Success(value):
        let five = value
    case let .Fail(error):
        let e = error
    case .Cancelled:
        break
    }
}
//: What's Completion<Int>? A Completion is an enumeration that represents the "completion" of a future.  When returned to an OnComplete handler, it will always be one of three values .Success, .Fail, or .Cancelled.

let completionOfAsyncFuture5 = asyncFuture5.result!
// ".Success(5)"

//: Seems easy?  Let's make them more fun.. 
//: [Next](@next)
