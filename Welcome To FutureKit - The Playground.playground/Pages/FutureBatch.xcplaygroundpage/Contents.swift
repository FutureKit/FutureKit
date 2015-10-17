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
//: Seting XCPSetExecutionShouldContinueIndefinitely so we can run multi-threaded things.
XCPSetExecutionShouldContinueIndefinitely(true)
//: # FutureBatch

//: Sometimes you want to launch multiple Async commands and wait for them all to complete.
let futureOne = Future (.Default) { () -> Int in
    return 1
}

let futureTwo = Future (.Default) { () -> Int in
    return 2
}

let futureThree = Future (.Default) { () -> Int in
    return 3
}
let arrayOfFutures = [futureOne,futureTwo,futureThree]

//: in FutureKit,you use a class called FutureBatch.


let batch = FutureBatchOf<Int>(f: arrayOfFutures)


let f = batch.future.onSuccess { (results: [Int]) -> Void in
    let x = results
    
}
//: [Next](@next)
