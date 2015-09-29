//
//  FKThread.swift
//  FutureKit
//
//  Created by Michael Gray on 6/19/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

public class FutureThread {
    
    public typealias __Type = Any
    
    var block: () -> Completion<__Type>
    
    private var promise = Promise<__Type>()
    
    public var future: Future<__Type> {
        return promise.future
    }
    
    private var thread : NSThread!
    
    public init(block b: () -> __Type) {
        self.block = { () -> Completion<__Type> in
            return .Success(b())
        }
        self.thread = NSThread(target: self, selector: "thread_func", object: nil)
    }
    public init(block b: () -> Completion<__Type>) {
        self.block = b
        self.thread = NSThread(target: self, selector: "thread_func", object: nil)
    }
    
    public init(block b: () -> Future<__Type>) {
        self.block = { () -> Completion<__Type> in
            return .CompleteUsing(b())
        }
        self.thread = NSThread(target: self, selector: "thread_func", object: nil)
    }
    
    public func thread_func() {
        self.promise.complete(self.block())
    }
    
    public func start() {
        self.thread.start()
    }
   
}
