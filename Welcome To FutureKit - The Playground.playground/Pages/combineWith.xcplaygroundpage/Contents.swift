//: [Previous](@previous)
//: Make sure you opened this inside the FutureKit workspace.  Opening the playground file directly, usually means it can't import FutureKit module correctly.
import Foundation
import FutureKit
#if os(iOS)
    import UIKit
    #else
    import Cocoa
#endif
import XCPlayground
XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

//: # FutureBatch

//: Sometimes you want to launch multiple Async commands and wait for them all to complete.
let futureOne = Future (.Async) { () -> Int in
    return 1
}

let futureTwo = Future (.Async) { () -> Int in
    return 2
}

let futureThree = Future (.Async) { () -> Int in
    return 3
}

//: in FutureKit,you make a call to `combineFutures`


let x = combineFutures(futureOne, futureTwo, futureThree).onSuccess { (one, two, three) -> Int in
    return (one+two+three)
}

//: By default, combineFutures will send the first failure or cancellation as a failure.
//: If you need finer control over the execution of sub-futures, you can use FutureBatch


let arrayOfFutures = [futureOne,futureTwo,futureThree]
let batch = FutureBatchOf<Int>(futures: arrayOfFutures)

// future behaves exactly like combineWith
let f = batch.future.onSuccess { (results: [Int]) -> Void in
    let x = results
    
}

//: if you want to see the individual result for each future you can also use the var 'resultsFuture'

batch.resultsFuture.onSuccess { (results:[FutureResult<Int>]) -> Void in
    for i in results {
        print(i)
    }
}

// there are also ways to get a realtime ballback as each completes

batch.onEachComplete { (result, future, index) -> Void in
    print ("\(result) for index \(index)")
}


//: [Next](@next)
