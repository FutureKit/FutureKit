//
//  OSAtomicInt.swift
//  Shimmer
//
//  Created by Michael Gray on 12/15/14.
//  Copyright (c) 2014 FlybyMedia. All rights reserved.
//

import UIKit




class OSAtomicInt32  {
    
    var __value : UnSafeMutableContainer<Int32>
    
    var memory : Int32 {
        get {
            return __value.memory
        }
    }
    init(_ initialValue: Int32 = 0) {
        __value = UnSafeMutableContainer<Int32>(initialValue)
    }

    func increment() -> Int32 {
        return OSAtomicIncrement32(__value.unsafe_pointer)
    }
    func decrement() -> Int32 {
        return OSAtomicDecrement32(__value.unsafe_pointer)
    }
    func incrementBarrier() -> Int32 {
        return OSAtomicIncrement32Barrier(__value.unsafe_pointer)
    }
    func decrementBarrier() -> Int32 {
        return OSAtomicDecrement32Barrier(__value.unsafe_pointer)
    }
    func add(theAmount: Int32) -> Int32 {
        return OSAtomicAdd32(theAmount,__value.unsafe_pointer)
    }
    func addBarrier(theAmount: Int32) -> Int32 {
        return OSAtomicAdd32Barrier(theAmount,__value.unsafe_pointer)
    }
    func ifEqualTo(value : Int32, thenReplaceWith : Int32) -> Bool {
        return OSAtomicCompareAndSwap32(value,thenReplaceWith,__value.unsafe_pointer)
    }
    func ifEqualToBarrier(value : Int32, thenReplaceWith : Int32) -> Bool {
        return OSAtomicCompareAndSwap32Barrier(value,thenReplaceWith,__value.unsafe_pointer)
    }
    
}
class OSAtomicInt64 {
    
    var __value : UnSafeMutableContainer<Int64>
    
    var memory : Int64 {
        get {
            return __value.memory
        }
    }
    init(_ initialValue: Int64 = 0) {
        __value = UnSafeMutableContainer<Int64>(initialValue)
    }
    
    func increment() -> Int64 {
        return OSAtomicIncrement64(__value.unsafe_pointer)
    }
    func decrement() -> Int64 {
        return OSAtomicDecrement64(__value.unsafe_pointer)
    }
    func incrementBarrier() -> Int64 {
        return OSAtomicIncrement64Barrier(__value.unsafe_pointer)
    }
    func decrementBarrier() -> Int64 {
        return OSAtomicDecrement64Barrier(__value.unsafe_pointer)
    }
    func add(theAmount: Int64) -> Int64 {
        return OSAtomicAdd64(theAmount,__value.unsafe_pointer)
    }
    func addBarrier(theAmount: Int64) -> Int64 {
        return OSAtomicAdd64Barrier(theAmount,__value.unsafe_pointer)
    }
    func ifEqualTo(value : Int64, thenReplaceWith : Int64) -> Bool {
        return OSAtomicCompareAndSwap64(value,thenReplaceWith,__value.unsafe_pointer)
    }
    func ifEqualToBarrier(value : Int64, thenReplaceWith : Int64) -> Bool {
        return OSAtomicCompareAndSwap64Barrier(value,thenReplaceWith,__value.unsafe_pointer)
    }
}
