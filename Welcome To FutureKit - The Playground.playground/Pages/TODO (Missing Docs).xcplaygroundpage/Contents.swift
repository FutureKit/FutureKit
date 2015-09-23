//: [Previous](@previous)

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

//: # Eventually
//:     cause I have so much free time to write more things
//: Advanced topics like:
//: - Get to 100% test coverage please.
//: - Configuring the Primary Executors (and the endless debate between Immediate vs Async execution)..
//: - how to tune synchronization.  (NSLock vs dispatch barrier queues).
//: - add a real var to a swift extension in a few lines.
//: - write code that can switch at runtime between Locks/Barriers and any other snychronization strategy you can bake up.

//: [Next](@next)
