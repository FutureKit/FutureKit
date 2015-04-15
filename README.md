# FutureKit
A Swift based Future/Promises Library for IOS and OS X.   


FutureKit is a iOS implementation of Futures and Promises, but modified specifically for iOS/OSX programmers.


# Some background - 

There are number of different Future/Promise varients for different langauages.
You can read about some here:
http://en.wikipedia.org/wiki/Futures_and_promises

I discovered them when doing backend programming using Scala. And once you master them, they solve all sorts of issues.

For iOS/OSX, your "closest" existing Future/Promises implementation is currently Bolts.
https://github.com/BoltsFramework/Bolts-iOS

And I LOVE Bolts!  And wrote a bunch of Bolts.

But then Swift came out.   And we started using Bolts with Swift, but it didn't feel right.  

I immediately ported Bolts to a native Swift version.  (You can find a version of that here:https://github.com/mishagray/SwiftTask).  
But my coworkers still had issues with Bolts (and also with my Swift Port).   

All this "dependentTask" etc.  I started writing methods that returned "Tasks" and my fellow programmer asked me "how do I start this Task?".  "Why do I have to keep returning 'nil'".    And eventually they figured it out, but I think they still look at me funny when I'm not looking

So While the BFTask IMPLEMENTATION is pretty spot on (you can still shadows of its implementation here).  The nomenclature was strange to understand.   And it wasn't swift!  



# FutureKit is TYPE SAFE

FutureKit is 100% Swift and uses Swift Generics heavily to ensure you methods are type safe

FutureKit uses simpler handler methods (onComplete/onSuccess/onFail etc). 
FutureKit is still highly composable, since any existing Future<T> can be 'mapped' to a new Future<S>.

#Executors
Executors are simpler.  And use a Swift enumeration for the most common Executors.  Most Executors will map to the built in iOS dispatch_queues  (.Main, .Default, .Utility, .Background).  You can also create Executors from existing dispatch_queue_t and NSOperationQueue types.   And if you have something terribly unexpected, there is a .Custom() type that lets you define your own "dispatch" block to define execution.



#TBD
Need to spend a day writing better docs.
Here are some examples!

```swift

    func iReturnAnInt() -> Future<Int> {
        return Future  { () -> Int in
            return 5
        }
    }


    func iReturnAnInt() -> Future<Int> {
        return Future  { () -> Int in
            return 5
        }
    }
    
    func iReturnFive() -> Int {
        return 5
    }
    func iReturnFromBackgroundQueueUsingAutoClosureTrick() -> Future<Int> {
        //
        return Future(.Default) { self.iReturnFive() }
    }
    
    func iWillUseAPromise() -> Future<Int> {
        let p : Promise<Int> = Promise()
        
        // let's do some async dispatching of things here:
        dispatch_main_async {
            p.completeWithSuccess(5)
        }
        
        return p.future
        
    }
    
    func iMayFailRandomly() -> Future<[String:Int]>  {
        let p = Promise<[String:Int]>()
        
        dispatch_main_async {
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
        return Future(.Main) { () -> Completion<[String:Int]> in
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
    
    func imGonnaMapAVoidToAnInt() -> Future<Int> {
        
        let f = self.iDontReturnValues().onSuccess { () -> Int in
            return 5
        }
            
        
        let g : Future<Int> = f.onSuccessResult({(fffive : Int) -> Float in
            Float(fffive + 10)
        }).onSuccess { (floatFifteen) ->  Int in
            Int(floatFifteen) + 5
        }
        return g
    }


```











