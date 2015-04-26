# FutureKit for Swift
A Swift based Future/Promises Library for IOS and OS X.   


FutureKit is a Swift implementation of Futures and Promises, but modified specifically for iOS/OSX programmers.
You can ready the wikipedia article here:
http://en.wikipedia.org/wiki/Futures_and_promises  

FutureKit sues Swift generic classes, to allow you to easily deal with asynchronous/multi-threaded issues when coding for iOS or OSX.

FutureKit is ALMOST ready to be used.  This is the "eval" version.  Please look around and tell us what you think.  A lot of work went into it so far, but we are ready to start showing it off.  We are STILL making changes, (changes in nomenclature, logic, etc.).  And trying to get all the code documented (using XCode 6.3 built in markdown).  This is a really good version, and feel free to play around.  But there is a good chance we are make some source-code-breaking changes in the next few weeks.  So don't say I didn't warn you.  This file will officially tell you when we think we have hit "1.0".   

The goal is to have a working version out before the end of May, with the official 1.0 release ready for WWDC 2015. (no.. I didn't get a ticket either)

All of the primary Swift code is written. (And works!)  But we are still tweaking things and trying to get to tests written that cover all the critical versions.

- is 100% Swift.  It ONLY currently supports Swift 1.2 and XCode 6.3.  No Swift 1.1 support.  I have currently only been testing using iOS 8.0+.  The plan will be to fix compatibility issues with iOS 7.0.  But I wouldn’t be surprised if things break every know and then.  If you find a problem - submit an issue please!

- is type safe.  It uses Swift Generics classes that can automatically infer the type you wish to return from asynchronous logic.  And supports all Swift types (Both 'Any' types, and 'AnyObject/NSObject' types!)

- uses simple to understand methods (onComplete/onSuccess/onFail etc) that let's you simplify complex asynchronous operations into clear and simple to understand logic.

- is highly composable, since any existing Future can be used to generate a new Future.  And Errors and Cancelations can be automatically passed through, simplifying error handling logic.  

- works well editing code within XCode 6.3 auto-completion.  The combination of type-inference and code-completion makes FutureKit coding fast and easy.

- simplifies the use of Apple GCD by using Executors - a simple Swift enumeration that attracts the most common iOS/OSX Dispatch Queues (Main,Default,Background, etc).  Allowing you to guarantee that logic will always be executed in the context you want.  (You never have to worry about having to call the correct dispatch_async() function again).  
- is highly tunable, allowing you to configure how the primary Executors (Immediate vs Async) execute, and what sort Thread Synchronization FutureKit will use (Barriers - Locks, etc).  Allowing you to tune FutureKit's logic to match what you need.  

# What the Heck is a Future?

So the simple answer is that Future is an object that represents that you will get something in the future.  Usually from another place.

    let imageView : UIImageView =  // some view on my view controller.
    let imageFuture : Future<UIImage> = MyApiClass().getAnImageFromServer()

There are few things that are interesting.  This object represents both that an image will arrive, and it will give me universal way to handle failures and cancellation.    It could be that MyApiClass() is using NSURLSessions, or AlamoFire, combined with some kinda cool image cache based on SDWebImage.  But this viewController doesn't care.  Just give me a `Future<UIImage>`.  Somehow.

now I can do this:

    imageFuture.onSuccess(.Main) { (image) -> Void in
        imageView.image = image
    }

This is a quick way of saying "when it's done, on the MainQ, set the image to an ImageView.

Let's make things more interesting.   Now your designer tell you he wants you to add a weird Blur effect to the image.   Which means you have to add an UIImage effect.  Which you better not do compute in the MainQ cause it's mildly expensive.   


So know you have two asynchronous dependencies, one async call for the network, and another for the blur effect.   In traditional iOS that would involve a lot of custom block handlers for different API, and handling dispatch_async calls.

Instead we are gonna do this.

    let imageFuture : Future<UIImage> = MyApiClass().getAnImageFromServer()
    let blurrImageFuture =  imageFuture.onSuccess(.UserInitiated) { (image) -> UIImage in {
         let burredImage = doBlurrEffect(image)
         return burredImage 
    }

blurrImageFuture is now a NEW Future<Image>.  That I have created from imageFuture.  I also defined I want that block to run in the .UserInitiated dispatch queue.  (Cause I need it fast!).

    blurrImageFuture.onSuccess(.Main) { (blurredImage) -> Void in
         imageView.image = blurredImage;
    }


Or i could rewite it all in one line:

    MyApiClass().getAnImageFromServer()
             .onSuccess(.UserInitiated) { (image) -> UIImage in {
                             let burredImage = doBlurrEffect(image)
                            return burredImage 
             }.onSuccess(.Main) { (blurredImage) -> Void in
                             imageView.image = blurredImage;
             }.onError { (error:NSError) -> Void in 
                         // deal with any error that happened along the way 
             }

That's the QUICK 1 minute answer of what this can do.  It let's you take any asynchronous operation and "map" it into a new one.   So you can take all your APIs and background logic and get them to easily conform to a universal way of interacting.    Which can let you get away with a LOT of crazy asynchronous execution, without giving up stability and ease of understanding.

Plus it's all type safe.    You could use handler to convert say, an `Future<NSData>` from your API server into a `Future<[NSObject:AnyObject]>` holding the JSON.   And than map that to a `Future<MyDatabaseEntity>` after it's written to a database.  

It's a neat way to stitch all your Asynchronous issues around a small set of classes.  

# Then what is a Promise?

A promise is a way for you write functions that returns Futures.  

    func getAnImageFromServer(url : NSURL) -> Future<UIImage> {
        let p = Promise<UIImage>()
        
        dispatch_async(...) {
             // do some crazy logic, or go to the internet and get a UIImageView.  Check some Image Caches. 
             let i = UIImage()
             p.completeWithSuccess(i)
        }
        return p.future
    }

A Promise<T> is a promise to send something back a value (of type T) in the future.  When it's ready..  A Promise has to be completed with either Success/Fail or Cancelled.  Don't break your promises!  Always complete them.  And everyone will be happy.  Especially your code that is waiting for things.

But it also means the API doesn't really need to bake a hole bunch of custom callback block handlers that return results.   And worry about what dispatch_queue those callback handlers have to running in.   Do you dispatch to mainQ before you call your callback handlers?  Or after?  Nobody seems to agree. 

But the Future object already offers a lot of cool built ways to get told when data is ready and when it fails.  And can handle which GCD queue is required for this reply.     

The api just has to emit what he promised.  The Future will take care of getting it to the consumer.

And since Futures can be composed from Futures, and Futures can be used to complete Promises, it's easy to integrate a number of complex Async services into a single reliable Future.  Mixing things like network calls, NSCache checks, database calls.   

It also "inverts" the existing dispatch_async() logic.  Where first you call dispatch_async(some_custom_queue) and THEN you call some api call to start it working.   

    func oldwayToGetStuff(callback:(NSData) -> Void) {
        dispatch_async(StuffMaker().custom_queue_for_stuff)  {
    
            // do stuff to make your NSData
            let d = StuffMaker().iBuildStuff()
        
            dispatch_async(dispatch_get_main()) {
                callback(d)
            }
        }
    }
notice how I forgot to add error handling in that callback.  What if iBuildStuff() times out?  do I add more properties to the callback block?  add more blocks?  Every API wants to do it different and every choice makes my code less and less flexible.
    
    class StuffMaker {
        func iBuildStuffWithFutures() -> Future<NSData> {
            let p = promise<NSData>()
            dispatch_async(self.mycustomqueue)  {
                 // do stuff to make your NSData
                if (SUCCEESS) {
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


