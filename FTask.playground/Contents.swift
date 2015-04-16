//: Playground - noun: a place where people can play

import UIKit
import FutureKit

var str = "Hello, playground"



let p2 = FTaskPromise()


let f = p2.ftask

f.onSuccessResult { (result) -> AnyObject? in
    print("\(result!)")
    return nil
}


p2.completeWithSuccess("hi")
