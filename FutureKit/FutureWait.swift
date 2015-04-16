//
//  SyncFuture.swift
//  FutureKit
//
//  Created by Michael Gray on 4/12/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

public func warnOperationOnMainThread() {
    NSLog("Warning: A long-running Future wait operation is being executed on the main thread. \n Break on logOperationOnMainThread() to debug.")
}

class FutureWaitHandler<T>  {
    
    private var condition : NSCondition = NSCondition()
    
    private var completion : Completion<T>?
    
    init (waitingOnFuture f: Future<T>) {
        f.onComplete { (c) -> Void in
            self.condition.lock()
            self.completion = c
            self.condition.broadcast()
            self.condition.unlock()
        }
    }
    
    final func waitUntilCompleted(doMainQWarning : Bool = true) -> Completion<T> {
        self.condition.lock()
        if (doMainQWarning && NSThread.isMainThread()) {
            if (self.completion == nil) {
                warnOperationOnMainThread()
            }
        }
        while (self.completion == nil) {
            self.condition.wait()
        }
        self.condition.unlock()
        
        return self.completion!
    }
    
}

/* extension Future {
    
    public func waitUntilCompleted() -> Completion<T> {
        let s = FutureWaitHandler<T>(waitingOnFuture: self)
        return s.waitUntilCompleted()
    }
    
    public func waitForResult() -> T? {
        return self.waitUntilCompleted().result
    }
} */

