# FutureKit for Swift

[![Cocoapods Compatible](https://img.shields.io/cocoapods/v/FutureKit.svg)](https://img.shields.io/cocoapods/v/FutureKit.svg)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/FutureKit.svg?style=flat&color=gray)](http://cocoadocs.org/docsets/FutureKit)
[![Platform](https://img.shields.io/cocoapods/p/FutureKit.svg?style=flat)](http://cocoadocs.org/docsets/FutureKit)
[![Twitter](https://img.shields.io/badge/twitter-@SwiftFutureKit-blue.svg?style=flat)](http://twitter.com/SwiftFutureKit)

A Swift based Future/Promises Library for IOS and OS X.   

Note - FutureKit is now exclusivly Swift 2.0 only.

FutureKit is a Swift implementation of Futures and Promises, but modified specifically for iOS/OSX programmers.
You can ready the wikipedia article here:
http://en.wikipedia.org/wiki/Futures_and_promises  

FutureKit uses Swift generic classes, to allow you to easily deal with asynchronous/multi-threaded issues when coding for iOS or OSX.

- is 100% Swift.  It ONLY currently supports Swift 2.0 and XCode 7+.  Swift 1.2 branch wont be supported anymore. (Too many issues with generics made swift 1.2 less than perfect)  We are also only supporting swift 2.0+ compatble SDKs (iOS 8.0+, OSX 10.x.)

- is type safe.  It uses Swift Generics classes that can automatically infer the type you wish to return from asynchronous logic.  And supports both value and reference Swift types (Both 'Any' types, and 'AnyObject/NSObject' types.)

- Is Swift 2.0 error handling friendly.  All FutureKit handler methods can already catch and complete a Future using any ErrorType.  So you don't need to wrap your code with 'do/try/catch'.

- FutureKit in Swift 2.0 is designed to simplify error handling, allowing you to attach a single error handler that can catch any error that may occur.  This can make dealing with composing async operations much easier and more reliable.

- uses simple to understand methods (onComplete/onSuccess/onFail etc) that let's you simplify complex asynchronous operations into clear and simple to understand logic.

- is highly composable, since any existing Future can be used to generate a new Future.  And Errors and Cancelations can be automatically passed through, simplifying error handling logic.
- 
- Super easy cancelation composition (which is a fancy way to say cancel works when you want it to automatically).  Future's are designed so there is never any confusion about whether an asynchronous operation completed, failed, or was canceled.  And the consumer has full control over whether he needs to be notified that the operation was canceled or not.   (0% confusion about whether your completion blocks will get called when the operation is cancelled).

- works well editing code within XCode auto-completion.  The combination of type-inference and code-completion makes FutureKit coding fast and easy.

- simplifies the use of Apple GCD by using Executors - a simple Swift enumeration that simplifies the most common iOS/OSX Dispatch Queues (Main,Default,Background, etc).  Allowing you to guarantee that logic will always be executed in the context you want.  (You never have to worry about having to call the correct dispatch_async() function again).  

- is highly tunable, allowing you to configure how the primary Executors (Immediate vs Async) execute, and what sort Thread Synchronization FutureKit will use (Barriers - Locks, etc).  Allowing you to tune FutureKit's logic to match what you need.  

# What the Heck is a Future?

So the simple answer is that Future is an object that represents that you will get something in the future.  Usually from another process possible running in another thread.  Or maybe a resource that needs to loaded from an external server.  

```swift
let imageView : UIImageView =  // some view on my view controller.
let imageFuture : Future<UIImage> = MyApiClass().getAnImageFromServer()
```

There are few things that are interesting.  This object represents both that an image will arrive, and it will give me universal way to handle failures and cancellation.    It could be that MyApiClass() is using NSURLSessions, or AlamoFire, combined with some kinda cool image cache based on SDWebImage.  But this viewController doesn't care.  Just give me a `Future<UIImage>`.  Somehow.

now I can do this:

```swift
imageFuture.onSuccess(.Main) {  image  in
    imageView.image = image
}
```

This is a quick way of saying "when it's done, on the MainQ, set the image to an ImageView.

Let's make things more interesting.   Now your designer tell you he wants you to add a weird Blur effect to the image.   Which means you have to add an UIImage effect.  Which you better not do compute in the MainQ cause it's mildly expensive.   


So know you have two asynchronous dependencies, one async call for the network, and another for the blur effect.   In traditional iOS that would involve a lot of custom block handlers for different API, and handling dispatch_async calls.

Instead we are gonna do this.

```swift
let imageFuture : Future<UIImage> = MyApiClass().getAnImageFromServer()
let blurImageFuture =  imageFuture.onSuccess(.UserInitiated) { (image) -> UIImage in
     let blurredImage = doBlurEffect(image)
     return blurredImage 
}
```

blurrImageFuture is now a NEW Future<Image>.  That I have created from imageFuture.  I also defined I want that block to run in the .UserInitiated dispatch queue.  (Cause I need it fast!).

```swift
blurImageFuture.onSuccess(.Main) { (blurredImage) -> Void in
     imageView.image = blurredImage;
}
```


Or I could rewite it all in one line:

```swift
MyApiClass().getAnImageFromServer()
     .onSuccess(.UserInitiated) { (image) -> UIImage in {
                    let blurredImage = doBlurEffect(image)
                    return blurredImage 
     }.onSuccess(.Main) { (blurredImage) -> Void in
                     imageView.image = blurredImage;
     }.onError { error in
                 // deal with any error that happened along the way
     }
```

That's the QUICK 1 minute answer of what this can do.  It let's you take any asynchronous operation and "map" it into a new one.   So you can take all your APIs and background logic and get them to easily conform to a universal way of interacting.    Which can let you get away with a LOT of crazy asynchronous execution, without giving up stability and ease of understanding.

Plus it's all type safe.    You could use handler to convert say, an `Future<NSData>` from your API server into a `Future<[NSObject:AnyObject]>` holding the JSON.   And than map that to a `Future<MyDatabaseEntity>` after it's written to a database.  

It's a neat way to stitch all your Asynchronous issues around a small set of classes.  

# Then what is a Promise?

A promise is a way for you write functions that returns Futures.  

```swift
func getAnImageFromServer(url : NSURL) -> Future<UIImage> {
    let p = Promise<UIImage>()

    dispatch_async(...) {
         // do some crazy logic, or go to the internet and get a UIImageView.  Check some Image Caches.
         let i = UIImage()
         p.completeWithSuccess(i)
    }
    return p.future
}
```

A Promise<T> is a promise to send something back a value (of type T) in the future.  When it's ready..  A Promise has to be completed with either Success/Fail or Cancelled.  Don't break your promises!  Always complete them.  And everyone will be happy.  Especially your code that is waiting for things.

But it also means the API doesn't really need to bake a whole bunch of custom callback block handlers that return results.   And worry about what dispatch_queue those callback handlers have to running in.   Do you dispatch to mainQ before you call your callback handlers?  Or after?  Nobody seems to agree. 

But the Future object already offers a lot of cool built ways to get told when data is ready and when it fails.  And can handle which GCD queue is required for this reply.     

The api just has to emit what he promised.  The Future will take care of getting it to the consumer.

And since Futures can be composed from Futures, and Futures can be used to complete Promises, it's easy to integrate a number of complex Async services into a single reliable Future.  Mixing things like network calls, NSCache checks, database calls.   

It also "inverts" the existing dispatch_async() logic.  Where first you call dispatch_async(some_custom_queue) and THEN you call some api call to start it working.   

```swift
func oldwayToGetStuff(callback:(NSData) -> Void) {
    dispatch_async(StuffMaker().custom_queue_for_stuff)  {

        // do stuff to make your NSData
        let d = StuffMaker().iBuildStuff()

        dispatch_async(dispatch_get_main()) {
            callback(d)
        }
    }
}
```

notice how I forgot to add error handling in that callback.  What if iBuildStuff() times out?  do I add more properties to the callback block?  add more blocks?  Every API wants to do it different and every choice makes my code less and less flexible.

```swift
class StuffMaker {
    func iBuildStuffWithFutures() -> Future<NSData> {
        let p = Promise<NSData>()
        dispatch_async(self.mycustomqueue)  {
             // do stuff to make your NSData
            if (SUCCESS) {
                let goodStuff = NSData()
                p.completeWithSuccess(goodStuff)
            }
            else {
                p.completeWithFail(NSError())
            }
        }
        return p.future()
    }
}
```

Notice we are now calling StuffMaker() directly, without having to dispatch first.  And I'm not calling dispatch_async() AGAIN before I call the callback block.   I will let the consumer of the Future decide where he wants his handlers to run.

Now you 100% guarantee that the code you want will ALWAYS run in the dispatch_queue you want.  It just returns a Future object.

# Documentation

FutureKit documentation is being written as XCode Playgrounds.  The best way to start is to open the FutureKit.workspace and then opening the Playground inside.  (If you open the Playgrounds outside of the workspace, then FutureKit module may not import correctly).
The XCode Playgrounds probably require XCode 6.3 (in order to see the Markup correctly)

If you are impatient, or not near your copy of XCode, you can try to read the first intro "raw" playground here:
https://github.com/FutureKit/FutureKit/blob/master/FutureKit-Future.playground/Contents.swift

There is also docs directory, that is generated using jazzy. https://github.com/realm/jazzy.  The plan is to get as close to 100% as possible (We are at 25%!).  So currently there is a lot of missing documentation.

# Help out!  

I would love it to get feedback!  Tell me what you think is wrong.  You can follow @swiftfuturekit to get announcements (when we make them).

- michael@futurekit.org
- [@swiftfuturekit] (http://twitter.com/swiftfuturekit)
