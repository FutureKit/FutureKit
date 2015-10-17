//: [Previous](@previous)

import FutureKit
#if os(iOS)
    import UIKit
    #else
    import Cocoa
    typealias UIImage = NSImage
#endif
import XCPlayground
XCPSetExecutionShouldContinueIndefinitely(true)
//: # Promises.
//: Promises are used to create your own Futures.
//: When you want to write a function or method that returns a Future, you will most likely want to create a Promise.

//:This is a **promise**.   It helps you return Futures when you need to.  When you create a Promise object, you are also creating a "promise" to complete a Future.   It's contract.  Don't break your promises, or you will have code that hangs.

let namesPromise = Promise<[String]>()

//: the promise has a var `future`.  we can now return this future to others.
let namesFuture :Future<[String]> = namesPromise.future

var timeCounter = 0
namesFuture.onSuccess(.Main) { (names : [String]) -> Void in
    for name in names {
        let timeCount = timeCounter++
        let greeting = "Happy Future Day \(name)!"
        print(greeting)
    }
}
//: so we have a nice routine that wants to greet all the names, but someone has to actually SUPPLY the  names.  Where are they?
let names = ["Skyer","David","Jess"]
let t = timeCounter++
namesPromise.completeWithSuccess(names)
//: Notice how the timeCounter shows us that the logic inside onSuccess() is executing after we execute completeWithSuccess().

//: A more typical case if you need to perform something inside a background queue.
//: I need a cat Picture.  I want to see my cats!  So go get me some!
//: Let's write a function that returns an Image.  But since I might have to go to the internet to retrieve it, we will define a function that returns Future instead
func getCoolCatPic(url: NSURL) -> Future<UIImage> {
    
    // We will use a promise, so we can return a Future<Image>
    let catPicturePromise = Promise<UIImage>()
    
    // go get data from this URL.
    let task = NSURLSession.sharedSession().dataTaskWithURL(url, completionHandler: { (data, response, error) -> Void in
        if let e = error {
            // if this is failing, make sure you aren't running this as an iOS Playground. It works when running as an OSX Playground.
            catPicturePromise.completeWithFail(e)
        }
        else {
            // parsing the data from the server into an Image.
            if let d = data,
                let image = UIImage(data: d) {
                    let i = image
                    catPicturePromise.completeWithSuccess(i)
            }
            else {
                catPicturePromise.completeWithErrorMessage("couldn't understand the data returned from the server \(url) - \(response)")
            }
        }
        // make sure to keep your promises!
        // promises are promises!
        assert(catPicturePromise.isCompleted)
    })
    
    // add a cancellation Request handler.  If someone wants to cancel the Future, what should we do?
    catPicturePromise.onRequestCancel { (options) -> CancelRequestResponse<UIImage> in
        task.cancel()
        return .Complete(.Cancelled)
    }
    
    // start downloading.
    task.resume()
    
    // return the promise's future.
    return catPicturePromise.future
}




let catUrlIFoundOnTumblr = NSURL(string: "http://25.media.tumblr.com/tumblr_m7zll2bkVC1rcyf04o1_500.gif")!

let imageFuture = getCoolCatPic(catUrlIFoundOnTumblr)
    
imageFuture.onComplete { (result) -> Void in
    switch result {
    case let .Success(value):
        let i = value
    case let .Fail(error):
        let e = error
    case .Cancelled:
        break
    }
}


//: [Next](@next)
