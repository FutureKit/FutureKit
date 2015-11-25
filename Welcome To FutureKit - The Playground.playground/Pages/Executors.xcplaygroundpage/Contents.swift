//: [Previous](@previous)

import Foundation
import FutureKit
import CoreData

var str = "Hello, playground"


//: One of the powers of a Future based async model vs the call-back model is that it allows the consumer of a function to decide what context the callback block will run in.


//: When using IOS or OSX Apis, there are plenty of new api calls that use a callback, but there is no predictable consistancy about what thread the block will be executed it.

//: KVO commands, allow for a dispatch_queue, or by default are sent in the queue/context of the code making the change.  Other callbacks are on the mainQ, and others may always be on some OS controlled queue.   Likewise many open-source projects have strugged with bugs and other issues related to mixing background dispatch_queues with the main queue.  There is no consistancy.



//: In FutureKit, we allow the consomer of a Future to decide where his completion blocks will execute.  And in a manner that is easy but also safe.

//: We use the Executor enumeration  (originally inspired by the BFTaskExecutor). 
//: an Executor can be optionally included along with most FutureKit methods.

//: The first and simpliest use is to allow us to quickly create a Future that will perform some work in the background and return a String

let hello = Future (.Utility) {
    //...
    // do some work back in the built in QOS_CLASS_UTILITY queue.
    return "Hello"
}

// .Utility is an Executor that uses the built in dispatch_queue QOS_CLASS_UTILITY.
// we can also make sure that when we add a completion handler, that the results are consumed in a block running in the mainq.


hello.onSuccess (.Main) { h -> Void in
    let s = h
}

// Now it's easy to compose futures that quickly move between background and main queue contexts.


hello.onSuccess (.Async) { h -> String in
    return h.stringByAppendingString(" World")
}
.onSuccess (.Background) { hw -> String in
    return hw.stringByAppendingString("!")
}
.onSuccess (.Main) { h in
    let s = h
}

//:  Executor has a number of built in values that map to the GCD queues.


var executor : Executor

executor = .MainAsync              // the Main Queue
executor = .UserInteractive        // QOS_CLASS_USER_INTERACTIVE
executor = .UserInitiated          // QOS_CLASS_USER_INITIATED
executor = .Default                // QOS_CLASS_DEFAULT
executor = .Utility                // QOS_CLASS_UTILITY
executor = .Background             // QOS_CLASS_BACKGROUND


//: You can also use a custom dispatch_queue_t

let q = dispatch_queue_create("custom_queue", DISPATCH_QUEUE_SERIAL)

executor = .Queue(q)

//:  Or an NSOperationQueue

let opq = NSOperationQueue()

executor = .OperationQueue(opq)


//: There are also a Executor that can abstract NSManagedObjectContext 'performBlock'

let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
executor = .ManagedObjectContext(context)  // automatically wraps blocks inside a performBlock 


//:  Lastly there are few 'special' Executors.

executor = .Immediate
//:  The Immediate executor will not cause the block to change context.  It will be run 'immediately' in the same thread that calls the assocaited Promise 'complete' command.

executor = .MainImmediate   //  Will run 'immediately' if the promise was completed inside the MainQ, otherwise it will dispatch to the Mainq
executor = .MainAsync       //  Will ALWAYS dispatch to the MainQ, even if the code is already on the mainq when the block is executed.



//:  There are also a few 'smart' Executors, that will dynamically map to different Exectors based on configuration

executor = .Primary     // This is the executor that will be used IF NO EXECUTOR is defined.   By default, this is set to .Current

executor = .Main        // this can be configured to be .MainImmediate (the default) or .MainAsync based on the static var `MainExecutor`

executor = .Async      // this is the default configured 'non-main queue', and is used to define the default queue that is NOT the main queue.
                // can be configured using the static var 'AsyncExecutor'.


executor = .Current    // Current will 'try' to determine what the current running executor already is, and re-use it.  If the current executor can't be determined or the code isn't already running 'inside' an Executor, than it will use .Main (if the current thread is MainQ) or .Async if the current thread is NOT MainQ.

executor = .CurrentAsync   // beheaves the same as Current, but will never map to MainImmediate, and instead always cause the block to be re-dispatched.




//:  But what about my crazy custom execution need?   You can bake your own.
//:  The .Custom enumeration can be used to define your own execution context that isn't defined here.

let example_of_a_Custom_Executor_That_Is_The_Same_As_MainAsync = Executor.Custom { (callback) -> Void in
    dispatch_async(dispatch_get_main_queue()) {
        callback()
    }
}

let example_Of_a_Custom_Executor_That_Is_The_Same_As_Immediate = Executor.Custom { (callback) -> Void in
    callback()
}

let example_Of_A_Custom_Executor_That_has_unneeded_dispatches = Executor.Custom { (callback) -> Void in
    
    Executor.Background.execute {
        Executor.Main.execute {
            callback()
        }
    }
}

let example_Of_A_Custom_Executor_Where_everthing_takes_5_seconds = Executor.Custom { (callback) -> Void in
    
    Executor.Primary.executeAfterDelay(5.0) { () -> Void in
        callback()
    }
    
}


//: # execute

let f : Future<String> = executor.execute { () -> String in
    return "hi"
}

// this the same as above
let f2 = Future(executor) { () -> String in
    return "hi"
}


let f2 : Future<String> = executor.execute { () -> Future<String> in
    return Future(executor) { () -> String in
        return "hi"
    }
}

//: Executors also have a nice convenient function `execute()` that can be used to 

//: [Next](@next)


