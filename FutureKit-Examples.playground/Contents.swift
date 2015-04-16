//: FutureKit playground

import Foundation
#if os(iOS)
    import FutureKit
#else
    import FutureKitOsx
#endif
import XCPlayground

// Some stuff to make this playground work better in XCode:
// Cause we are doing lots of Async code, we need this:
var count = 0
//: Turn on the Timeline! select View -> Assistant Editor -> Show Assistant Editor (keyboard shortcut: Option + Command + Return).
func showInTimeLine<T>(identifier: String, value: T, line : Int32 = __LINE__) {
    Executor.Main.execute {
        let s = "\(count++):-\(identifier) - lineNo:\(line)"
        println(s)
        XCPCaptureValue(s,value)
    }
}


// ENABLE MARkEUP (if This is hard to read)
// in XCode, select "Editor"..."Show Rendered Markup"

//: This is a future.
let future5 : Future<Int>
//:  At some point, it will return an Int.
//:  I called it "future5" because it will eventualy at some point in the future it will return a Int value of 5
future5 = Future(success: 5)
//: I lied.  Cause actually the value 5 is already there.  This was a Future that was created in a completed state.  It has a result.  The Future was successful, and it has a result of 5.

let answer = future5.result!
// answer is 5

showInTimeLine("answer",answer)
//:Gonna add these XCPCaptureValue lines so you can see the order of exeuction.  Make sure to turn on the execution timeline.  In XCode Turn on the Assistant Editor (View..Assistant Editor...Show Assistant Editor).

//: Sometimes you can't get an answer.  So instead of 5, we are gonna return a failure.  No number 5 for you.
let futureFail = Future<Int>(failWithErrorMessage:"I am a failure.  No 5 for you.")
let failed5result = futureFail.result
// nil
let e = futureFail.error
// NSError
showInTimeLine("futureFail.error",e)


//: Sometimes your request is cancelled. It's not usually because of a failure, and usually means we just wanted to halt an async process before it was done.  Optionally you can send a reason, but it's not required.
let cancelledFuture = Future<Int>(cancelled: "token!")
let cancelledResult = cancelledFuture.result
// nil
let cancelationToken = cancelledFuture.cancelToken
// "token!"
showInTimeLine("cancelledFuture",cancelledFuture)



//: These aren't very interesting Futures. Let's make them more fun.
let asyncFuture5 = Future(.Default) {
    return 5
}
//: what is that?  This is also a Future<Int>, but I didn't even need to declare it.   The swift compiler figured it out, because I put "return 5" in the block.    
//: But what is that (.Default) thing?

let answerAsync = asyncFuture5.result
// nil.  (or maybe 5)
//: **wtf!?**  why is the result nil?  should it be? SOMETIMES it isn't.  Sometimes when you run the playground it is.
//: This is good.  The reason is that the block that returns the 5 didn't run yet.  It actually is running AFTER we call "let answerAsync = asyncFuture5.result"
let answerAsync2 = asyncFuture5.result
//  5  (or maybe nil still)
//: that's because we created a Future and told it to "run" inside the .Default Executor.  Which is maps to the built in iOS dispatch_queue QOS_CLASS_DEFAULT.   So the block { return 5 } was dispatched to a background queue, and than returned.   We will talk more about Executors and how they can encapulate dispatch_queue, NSOperationQueue, and some other interesting execution issues.
//: But how are we supposed to get a result?

asyncFuture5.onSuccess { (result) -> Void in
    let five = result
//    println(result)
}
//: Now we have a result!
//: We can also add handlers for Fail and Cancel:
futureFail.onFail { (error) -> Void in
    let e = error
//    println(e)
}
cancelledFuture.onCancel { (token) -> Void in
    let t = token as! String
//    println(t)
}

//: But if you don't want to add 3 handlers, it's more common to just add a single onComplete handler

asyncFuture5.onComplete { (completion : Completion<Int>) -> Void in
    switch completion.state {
    case .Success:
        let five = completion.result
        println(five)
    case .Fail:
        let e = completion.error
        println(e)
    case .Cancelled:
        let c = completion.cancelToken
        println(c)
    }
}



//: Seems easy?  Let's make them more fun:

//: # Promises.
//: Most of the time, you can't create a future by just calling Future (.Default) { .... }.   You have more complex execution problems.  You are using a library and it's using it's OWN dispatch queues.  Futures alone are kind of limited.

let namesPromise = Promise<[String]>()
//:This is a **promise**.   It helps you return Futures when you need to.  When you create a Promise object, you are also creating a "promise" to complete a Future.   It's contract.  Don't break your promises, or you will have code that hangs. 

let namesFuture :Future<[String]> = namesPromise.future
//: the promise has a var that is a future.  we can now return this future to others.

namesFuture.onSuccess { (names : [String]) -> Void in
    for name in names {
        let greeting = "Happy Future Day \(name)!\n"
        print(greeting)
    }
}
//: so we have a nice routine that wants to greet all the names, but someone has to actually SUPPLY the names.  Where are they?
namesPromise.completeWithSuccess(["Mike","David","Skyler"]) // <-- the handler can run now!


//: A more typical case if you need to perform something inside a background queue.  

#if os(OSX)
typealias UIImage = NSImage
#endif

let catPicturePromise = Promise<UIImage>()

let catPictureFuture = catPicturePromise.future


//: I need a cat Picture.  I want to see my cats!  So go get me some!  But don't run in the mainQ, cause I'm busy scrolling things and looking at other cats.
//: Warning - the cat picture never loads when running this as an IOS Playground

dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {

    let url = NSURL(string: "https://pbs.twimg.com/media/CBI25rjUQAADgBK.jpg")!


    let task = NSURLSession.sharedSession().downloadTaskWithURL(url, completionHandler: { (url, response, error) -> Void in

        let r = response
        
        if let e = error {
            let e2 = e
            catPicturePromise.completeWithFail(e)
        }
        else {
            if let d = NSData(contentsOfURL: url) {
                if let image = UIImage(data: d) {
                    let i = image
                    catPicturePromise.completeWithSuccess(i)
                }
            }
        }
        if !catPicturePromise.isCompleted {
            catPicturePromise.completeWithFail("bad stuff happened")
        }
    })

    task.resume()

}

catPictureFuture.onComplete { (completion) -> Void in
    switch completion.state {
    case .Success:
        let i = completion.result
        showInTimeLine("catPictureFuture:image",i)
    case .Fail:
        let e = completion.error
        showInTimeLine("catPictureFuture:image_error",e)
    case .Cancelled:
        showInTimeLine("catPictureFuture:cancelled",completion.cancelToken)
    }
}


catPictureFuture.onSuccess { (result : UIImage) -> Void in
    let i = result
    showInTimeLine("image",i)
}







// Cleaning up the Playground to let it exit gracefully
// this lets me NOT have to use XCPSetExecutionShouldContinueIndefinitely.
// If you much
var allTheAsyncFuturesInThisPlayGround : [FutureProtocol] =
        [asyncFuture5,namesFuture,catPictureFuture]


sequence(allTheAsyncFuturesInThisPlayGround)._waitUntilCompletedOnMainQueue()

/*
future5.onSuccessResult { (result:Int) -> Void in
    let x = result
    print(result)
}

let futureString : Future<String> = future5.onSuccessResult { (result:Int) -> String in
    print(result)
    return String(result)
}
    
futureString.onSuccessResult { (result:String) -> Void in
        print(result)
}


func iReturnFromBackgroundQueueUsingAutoClosureTrick() -> Future<Int> {
    //
    return Future(.Default) { 50 }
}

let autoclosurefuture = iReturnFromBackgroundQueueUsingAutoClosureTrick()
autoclosurefuture.onSuccessResult { (result:Int) -> Void in
    print(result)
}

    let pX : Promise<Int> = Promise()
    
    // let's do some async dispatching of things here:
    Executor.Default.execute {
        let answer = 5
        pX.completeWithSuccess(answer)
    }
    
   // return
    pX.future.onSuccessResult({ (result:Int) -> Void in
        print(result)
    })
// }



func iMayFailRandomly() -> Future<[String:Int]>  {
    let p = Promise<[String:Int]>()
    
    Executor.Default.execute {
        let s = arc4random_uniform(3)
        switch s {
        case 0:
            p.completeWithFail(FutureNSError(error: .GenericException, userInfo: nil))
        case 1:
            p.completeWithCancel()
        default:
            p.completeWithSuccess(["Hi" : 5])
        }
    }
    
    return p.future
    
}

func iMayFailRandomlyAlso() -> Future<[String:Int]>  {
    return Future(.Default) { () -> Completion<[String:Int]> in
        let s = arc4random_uniform(3)
        switch s {
        case 0:
            return .Fail(FutureNSError(error: .GenericException, userInfo: nil))
        case 1:
            return .Cancelled
        default:
            return .Success(["Hi" : 5])
        }
    }
}

func iCopeWithWhatever()  {
    
    
    // ALL 3 OF THESE FUNCTIONS BEHAVE THE SAME
    
    iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
        switch completion {
        case let .Success(r):
            let x = r
            NSLog("\(x)")
            return .Success(Void())
        case let .Fail(e):
            return .Fail(e)
        case .Cancelled:
            return .Cancelled
        default:
            assertionFailure("This shouldn't happen!")
            return Completion<Void>(failWithGenericError: "something bad happened")
        }
    }
    
    iMayFailRandomly().onComplete { (completion) -> Completion<Void> in
        switch completion.state {
        case let .Success:
            return .Success(Void())
        case let .Fail:
            return .Fail(completion.error)
        case .Cancelled:
            return .Cancelled
        }
    }
    
    
    iMayFailRandomly().onSuccess { () -> Completion<Int> in
        return .Success(5)
    }
    
    
    iMayFailRandomly().onSuccessResult { (x) -> Void in
        NSLog("\(x)")
    }
    
}

func iDontReturnValues() -> Future<Void> {
    let f = Future(.Primary) { () -> Int in
        return 5
    }
    
    let p = Promise<Void>()
    
    f.onSuccessResult { (result) -> Void in
        Executor.Default.execute {
            p.completeWithSuccess()
        }
    }
    // let's do some async dispatching of things here:
    return p.future
}

func imGonnaMapAVoidToAnInt() -> Future<Int> {
    
    
    let f = iDontReturnValues().onSuccess { () -> Int in
        return 5
    }
    
    
    let g : Future<Int> = f.onSuccessResult({(fffive : Int) -> Float in
        Float(fffive + 10)
    }).onSuccess { (floatFifteen) ->  Int in
        Int(floatFifteen) + 5
    }
    return g
}

func adding5To5Makes10() -> Future<Int> {
    return imGonnaMapAVoidToAnInt().onSuccessResult { (value) -> Int in
        return value + 5
    }
}

func convertNumbersToString() -> Future<String> {
    return imGonnaMapAVoidToAnInt().onSuccessResult { (value) -> String in
        return "\(value)"
    }
}

func convertingAFuture() -> Future<NSString> {
    let f = convertNumbersToString()
    return f.convert()
}


func testing() {
    let x = Future<Optional<Int>>(success: 5)
    
//    let y : Future<Int64?> = convertOptionalFutures(x)
    
    
}
*/





