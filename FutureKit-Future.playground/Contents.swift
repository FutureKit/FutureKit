//: # Welcome to FutureKit!

import Foundation
import FutureKit
#if os(iOS)
    import UIKit
#else
    typealias UIImage = NSImage
    typealias UIImageView = NSImageView
    import Cocoa
#endif
import XCPlayground

//: Just utility stuff here.
XCPSetExecutionShouldContinueIndefinitely(continueIndefinitely: true)
func showInTimeLine<T>(identifier: String, value: T, line : Int32 = __LINE__) {
    let s = "line:\(line):(\"\(identifier)\",\(value))\n"
    println(s)
}

// ENABLE MARKEUP (if This is hard to read)
// in select Editor -> Show Rendered Markup
//: Turn on the Timeline! select View -> Assistant Editor -> Show Assistant Editor (keyboard shortcut: Option + Command + Return).

//: # Let's get started!
//: This is a Future:

let future5 : Future<Int>

//: It's not a regular Int.  It's a "Future" Int.
//: At some point in the future, this object will "generate" an Int. Or maybe it will fail.
//: I called the variable "future5" because it will eventualy at some point in the future it will return a Int value of 5.  Very useful if you need a 5 at somepoint in the future.

future5 = Future(success: 5)
//: Ok.  I told a small lie. Cause now the value 5 is already there.  This was a Future that was created in a "completed" state.  It has a result.  The Future was successful, and it has a result of 5.  Very good.



let resultOfFuture5 = future5.result!
// resultOfFuture5 is 5
showInTimeLine("resultOfFuture5",resultOfFuture5)

//: showInTimeLine will output things to the console output. So you can see how things are running. Make sure to turn on the Assistant Editor (View..Assistant Editor...Show Assistant Editor) if you don't see console output.
//: Sometimes a Future will fail. Maybe the database is all out if 5's.  So instead of 5, we are gonna return a failure.  No number 5 for you.

let futureFail = Future<Int>(failWithErrorMessage:"I have no 5's for you today.")
let failed5result = futureFail.result
// nil
showInTimeLine("failed5result",failed5result)
let e = futureFail.error
// NSError
showInTimeLine("futureFail.error",e)


//: Sometimes your request is cancelled. It's not usually because of a failure, and usually means we just wanted to halt an async process before it was done.  Optionally you can send a reason, but it's not required.  In FutureKit a Fail means that something went wrong, and you should cope with that.  a Cancel is usually considered "legal", like canceling active API requests when a window is closed.
let cancelledFuture = Future<Int>(cancelled: "token!")
let cancelledResult = cancelledFuture.result
// nil
let cancelationToken = cancelledFuture.cancelToken
// "token!"
showInTimeLine("cancelledFuture",cancelledFuture)


//: These aren't very interesting Futures. Let's make them more fun.

let asyncFuture5 = Future(.Default) { () -> Int in
    showInTimeLine("asyncFuture5 is returning",5)
    return 5
}
//: This is also a Future<Int>. The swift compiler figured it out, because I added a block that returns an Int.
//: But what is that (.Default) thing?

let firstAttempt = asyncFuture5.result
// nil.  (usually)
showInTimeLine("answerAsync",firstAttempt)

//: **wtf!?**  why is the result nil?  should it be? Sometimes when you run the playground, you will get a 5.  Sometimes a nil.
//: That's because the block that returns the 5 may not have finished running yet.
//: Let's try again looking at the result AGAIN:

let secondAttempt = asyncFuture5.result
//  5  (usually)
showInTimeLine("answerAsync2",secondAttempt)
//: that's because we created a Future and told it to "run" inside the .Default Executor. It executes it's blocks inside the dispatch_queue QOS_CLASS_DEFAULT.   So the block { return 5 } was dispatched to a queue, and than returned.   We will talk more about Executors and how they can encapulate dispatch_queue, NSOperationQueue, and some other interesting execution issues, in a different playground.
//: But how are we supposed to get a result?

asyncFuture5.onSuccess { (result) -> Void in
    let five = result
    showInTimeLine("asyncFuture5.onSuccess",five)
}

//: Now we have a result! We got our 5.
//: If you are running XCode, hold down the option button and click on (result) in the block above.  It should show something like `let result: (Int)`
//: The Swift compiler automatically knows that result is an Int, because asyncFuture5 is defined as a Future<Int>.

//: Future's are type safe.  You can't add an onSuccess handler block that wants a String to a Future<Int>.
//: if you uncomment the next line, watch how compile complains (check the Console Output on the Timeline if you don't see an error in the editor)


// asyncFuture5.onSuccess { (result: String) -> Void in  }

//: changing `(result:String)` to `(result:Int)` fixes the bug.  (Or just remove the type definition and let Swift infer the type needed)


//: We can also add handlers for Fail and Cancel:

futureFail.onFail { (error) -> Void in
    showInTimeLine("futureFail.onFail",error)
}
cancelledFuture.onCancel { (token) -> Void in
    showInTimeLine("cancelledFuture.onCancel",token)
}

//: But if you don't want to add 3 handlers, it's more common to just add a single onComplete handler

asyncFuture5.onComplete { (completion : Completion<Int>) -> Void in
    switch completion.state {
    case .Success:
        let five = completion.result
        showInTimeLine(".Success", five)
    case .Fail:
        let e = completion.error
        showInTimeLine(".Fail", e)
    case .Cancelled:
        let c = completion.cancelToken
        showInTimeLine(".Cancelled", c)
    }
}
//: What's Completion<Int>? A Completion is an enumeration that represents the "completion" of a future.  When returned to an OnComplete handler, it will always be one of three values .Success, .Fail, or .Cancelled.

let completionOfAsyncFuture5 = asyncFuture5.completion!
// ".Success(5)"
showInTimeLine("completionOfAsncFuture5", completionOfAsyncFuture5)

//: Seems easy?  Let's make them more fun:

//: # Promises.
//: Most of the time, you can't create a future by just calling Future (.Default) { .... }.   You have more complex execution problems.  You are using a library and it's using it's OWN dispatch queues.  Futures alone are kind of limited.
//: So the most flexible way of creating a Future is to create a Promise

//:This is a **promise**.   It helps you return Futures when you need to.  When you create a Promise object, you are also creating a "promise" to complete a Future.   It's contract.  Don't break your promises, or you will have code that hangs.

let namesPromise = Promise<[String]>()


//: the promise has a var `future`.  we can now return this future to others.
let namesFuture :Future<[String]> = namesPromise.future

namesFuture.onSuccess { (names : [String]) -> Void in
    for name in names {
        let greeting = "Happy Future Day \(name)!"
        showInTimeLine("greeting", greeting)
    }
}

//: so we have a nice routine that wants to greet all the names, but someone has to actually SUPPLY the  names.  Where are they?

let names = ["Mike","David","Skyler"]
showInTimeLine("This is gonna appear in the console log BEFORE any greetings do!","")
namesPromise.completeWithSuccess(names)

//: If you check the Console Output, you can see how the "Happy Future Day" greetings, appear AFTER we call completeWithSuccess()  (the line numbers are out of order!)



//: A more typical case if you need to perform something inside a background queue.
//: I need a cat Picture.  I want to see my cats!  So go get me some!  But don't run in the mainQ, cause I'm busy scrolling things and looking at other cats.

//: Let's write a function that returns an Image.  But since I might have to go to the internet to retrieve it, we will define a function that returns Future instead
//: `func getCoolCatPic(url: NSURL) -> Future<NSImage>`
//: Warning - the cat picture never loads when running this as an IOS Playground. (As of XCode 6.2).


func getCoolCatPic(url: NSURL) -> Future<UIImage> {
    
    // We will use a promise, so we can return a Future<Image>
    let catPicturePromise = Promise<UIImage>()
    
    let task = NSURLSession.sharedSession().downloadTaskWithURL(url, completionHandler: { (url, response, error) -> Void in
        let r = response
        if let e = error {
            showInTimeLine("catPicturePromise.failed",e)
            catPicturePromise.completeWithFail(e)
        }
        else {
            if let d = NSData(contentsOfURL: url) {
                if let image = NSImage(data: d) {
                    let i = image
                    showInTimeLine("catPicturePromise.Success",i)
                    catPicturePromise.completeWithSuccess(i)
                }
            }
        }
        if !catPicturePromise.isCompleted {
            catPicturePromise.completeWithFail("bad stuff happened")
        }
    })
    task.resume()
    
    // return the promise's future.
    return catPicturePromise.future
}

let catUrl = NSURL(string: "http://25.media.tumblr.com/tumblr_m7zll2bkVC1rcyf04o1_500.gif")!

getCoolCatPic(catUrl).onComplete(.Main) { (completion) -> Void in
    switch completion.state {
    case .Success:
        let i = completion.result
        let view = NSImageView(frame: NSRect(x: 0, y: 0, width: i.size.width, height: i.size.height))
        view.image = i
        XCPShowView("cat pic",view)
        showInTimeLine("catPictureFuture:image",i)
    case .Fail:
        let e = completion.error
        showInTimeLine("catPictureFuture:image_error",e)
    case .Cancelled:
        showInTimeLine("catPictureFuture:cancelled",completion.cancelToken)
    }
}
//: what is onCompleteWith(.Main)?  This means we want to run this completion block inside the Main queue.  We have to do that, cause we are gonna mess with views (XCPShowView must run the main queue).


//: # Futures are composable.

//: adding a block handler to a Future via onComplete/onSuccess doesn't just give you a way to get a result from a future.  It's also a way to create a new Future.

let stringFuture = Future<String>(success: "5")

let intOptFuture : Future<Int?>
intOptFuture  = stringFuture.onSuccess { (stringResult) -> Int? in
    return stringResult.toInt()
}
intOptFuture.onSuccess { (intResult : Int?) -> Void in
    let i = intResult
    print("\(i!)")
}

//: Knowing this we can "chain" futures together to make a complex set of dependencies...


stringFuture.onSuccess { (stringResult:String) -> Int in
        return stringResult.toInt()!
    }.onSuccess { (intResult:Int) -> [Int] in
        let i = intResult
        return [i]
    }
    .onSuccess { (arrayResult : [Int]) -> Void in
        let a = arrayResult
        print("got an array: \(arrayResult)")
    }

//: You can see how we can use the result of the first future, to generate the result of the second, etc.
//: This is such a common and powerful feature of futures there is an alternate version of the same command called 'map'.  The generic signature of map looks like:
//: 'func map<S>((T) -> S) -> Future<S>'

let futureInt = stringFuture.map { (stringResult) -> Int in
                    stringResult.toInt()! }
    
    
//: `futureInt` is automatically be inferred as Future<Int>.
//:  when "chaining" futures together via onSuccess (or map), Failures and Cancellations will automatically be 'forwarded' to any dependent tasks.   So if the first future returns Fail, than all of the dependent futures will automatically fail.

//: # Completion
//: Sometimes you want to create a dependent Future but conditionally decide inside the block whether the dependent block should Succeed or Fail, etc.   For this we have use a handler block with a different generic signature:
//: 'func onComplete<S>((Completion<T>) -> Completion<S>) -> Future<S>'

//:  Don't worry if that seems hard to understand.  It's actually pretty straightforward.
//: A Completion is a enumeration that is used to 'complete' a future.  A Future has a var
//: `var completion : Completion<T>?`
//: this var stores the completion value of the Future.  Note that it's optional.  That's because a Future may not be 'completed' yet.  When it's in an uncompleted state, it's completion var will be nil.  
//: If you examine the contents of a completed Future<T>, you will find a Completion<T> enumeration that must be one of the 3 possible values: .Success(Any), .Fail(NSError), .Cancel(Any?)

let anotherFuture5 = Future(success: 5)
    
switch anotherFuture5.completion! {
    case let .Success(result):
        let x = result
    default:
        break
    }
