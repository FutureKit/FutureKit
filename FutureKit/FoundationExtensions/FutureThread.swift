//
//  FKThread.swift
//  FutureKit
//
//  Created by Michael Gray on 6/19/15.
//  Copyright (c) 2015 Michael Gray. All rights reserved.
//

import Foundation

open class FutureThread {
    
    public typealias __Type = Any
    
    var block: () -> Completion<__Type>
    
    fileprivate var promise = Promise<__Type>()
    
    open var future: Future<__Type> {
        return promise.future
    }
    
    fileprivate var thread : Thread!
    
    public init(block b: @escaping () -> __Type) {
        self.block = { () -> Completion<__Type> in
            return .success(b())
        }
        self.thread = Thread(target: self, selector: #selector(FutureThread.thread_func), object: nil)
    }
    public init(block b: @escaping () -> Completion<__Type>) {
        self.block = b
        self.thread = Thread(target: self, selector: #selector(FutureThread.thread_func), object: nil)
    }
    
    public init(block b: @escaping () -> Future<__Type>) {
        self.block = { () -> Completion<__Type> in
            return .completeUsing(b())
        }
        self.thread = Thread(target: self, selector: #selector(FutureThread.thread_func), object: nil)
    }
    
    @objc open func thread_func() {
        self.promise.complete(self.block())
    }
    
    open func start() {
        self.thread.start()
    }
   
}
