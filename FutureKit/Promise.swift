//
//  Promise.swift
//  FutureKit
//
//  Created by Michael Gray on 4/13/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

public class Promise<T>  {
    
    public typealias completionErrorHandler = (() -> Void)
    
    public var future =  Future<T>()
    
    public init() {
        
    }
    
    public final func complete(completion : Completion<T>) {
        self.future.completeWith(completion)
    }
    
    public final func completeWithVoidSuccess() {
        assert(toString(T.self) == toString(Void.self),"You must send a result if the type isn't Promise<Void> - USE completeWithSuccess(result : T) instead!")
        self.future.completeWith(.Success(Void()))
    }
    public final func completeWithSuccess(result : T) {
        self.future.completeWith(.Success(result))
    }
    public final func completeWithFail(e : NSError) {
        self.future.completeWith(.Fail(e))
    }
    public final func completeWithException(e : NSException) {
        self.future.completeWith(Completion<T>(exception: e))
    }
    public final func completeWithCancel() {
        self.future.completeWith(.Cancelled)
    }
    public final func continueWithFuture(f : Future<T>) {
        self.future.completeWith(.ContinueWith(f))
    }
    
    
    // can return true if completion was successful.
    // can block the current thread
    public final func syncComplete(completion : Completion<T>) -> Bool {
        return self.future.completeWithSync(completion)
    }
    
    // execute a block if the completion "fails" because the future is already completed.
    public final func complete(completion : Completion<T>,onCompletionError errorBlock: completionErrorHandler) {
        self.future.completeWith(completion,onCompletionError:errorBlock)
    }
    
    // experimental.  Not a good idea really
    func __reset() {
        self.future.__reset()
    }
}
