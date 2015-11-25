//: [Previous](@previous)

import Foundation
import FutureKit




func iReturnAFuture() -> Future<Int> {
    let p = Promise<Int>()
    
    /// do something async
    
    Executor.Async.execute { () -> Void in
        p.completeWithSuccess(5)
    }
    
    return p.future
    
}


iReturnAFuture().onComplete { result -> Completion<String> in
    
    switch result {
        case let .Success(x):
            return .Success("\(x+5)")
    case let .Fail(e):
        return .Fail(e)
    case .Cancelled:
        return .Cancelled
    }
}



iReturnAFuture().onComplete { (result :FutureResult<Int>) -> Completion<Int> in
    
    switch result {
    case let .Success(x):
        return .Success(x+5)
    case let .Fail(e):
        return .CompleteUsing(iReturnAFuture())
    case .Cancelled:
        return .Cancelled
    }
}



// this can only return .Success
iReturnAFuture().onComplete { (result :FutureResult<Int>) -> Int in
    
    switch result {
    case let .Success(x):
        return x+5
    case let .Fail(e):
        return -1  // we have to return success!
    case .Cancelled:
        return -2 // we have to return success
    }
}


let f = iReturnAFuture().onSuccess { value -> Int in
    
    return value+5
}


let x = Future(success: 10)

x.onComplete { (result) -> Completion<Int> in
    return .CompleteUsing(iReturnAFuture())
}

// identical to above!
let token = x.onComplete { (result) -> Future<Int> in
    return iReturnAFuture()
}
.onSuccess { (_) -> String in
    "blah"
}
.onSuccess { _ -> Int in
    0
}.getCancelToken()

let y = iReturnAFuture()

y.onComplete { result -> String in
    print(result)
    // what happens here?
    return "hi"
}

let t = y.onComplete { _ in
    return "bob"
}.getCancelToken()

t.cancel()














