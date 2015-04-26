//
//  OSAtomicInt.swift
//  Shimmer
//
//  Created by Michael Gray on 12/15/14.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation




public class OSAtomicInt32  {
    
    var __value : UnSafeMutableContainer<Int32>
    
    public var memory : Int32 {
        get {
            return __value.memory
        }
    }
    public init(_ initialValue: Int32 = 0) {
        __value = UnSafeMutableContainer<Int32>(initialValue)
    }

    public func increment() -> Int32 {
        return OSAtomicIncrement32(__value.unsafe_pointer)
    }
    public func decrement() -> Int32 {
        return OSAtomicDecrement32(__value.unsafe_pointer)
    }
    public func incrementBarrier() -> Int32 {
        return OSAtomicIncrement32Barrier(__value.unsafe_pointer)
    }
    public func decrementBarrier() -> Int32 {
        return OSAtomicDecrement32Barrier(__value.unsafe_pointer)
    }
    public func add(theAmount: Int32) -> Int32 {
        return OSAtomicAdd32(theAmount,__value.unsafe_pointer)
    }
    public func addBarrier(theAmount: Int32) -> Int32 {
        return OSAtomicAdd32Barrier(theAmount,__value.unsafe_pointer)
    }
    public func ifEqualTo(value : Int32, thenReplaceWith : Int32) -> Bool {
        return OSAtomicCompareAndSwap32(value,thenReplaceWith,__value.unsafe_pointer)
    }
    public func ifEqualToBarrier(value : Int32, thenReplaceWith : Int32) -> Bool {
        return OSAtomicCompareAndSwap32Barrier(value,thenReplaceWith,__value.unsafe_pointer)
    }
    
}
public class OSAtomicInt64 {
    
    var __value : UnSafeMutableContainer<Int64>
    
    public var memory : Int64 {
        get {
            return __value.memory
        }
    }
    public init(_ initialValue: Int64 = 0) {
        __value = UnSafeMutableContainer<Int64>(initialValue)
    }
    
    public func increment() -> Int64 {
        return OSAtomicIncrement64(__value.unsafe_pointer)
    }
    public func decrement() -> Int64 {
        return OSAtomicDecrement64(__value.unsafe_pointer)
    }
    public func incrementBarrier() -> Int64 {
        return OSAtomicIncrement64Barrier(__value.unsafe_pointer)
    }
    public func decrementBarrier() -> Int64 {
        return OSAtomicDecrement64Barrier(__value.unsafe_pointer)
    }
    public func add(theAmount: Int64) -> Int64 {
        return OSAtomicAdd64(theAmount,__value.unsafe_pointer)
    }
    public func addBarrier(theAmount: Int64) -> Int64 {
        return OSAtomicAdd64Barrier(theAmount,__value.unsafe_pointer)
    }
    public func ifEqualTo(value : Int64, thenReplaceWith : Int64) -> Bool {
        return OSAtomicCompareAndSwap64(value,thenReplaceWith,__value.unsafe_pointer)
    }
    public func ifEqualToBarrier(value : Int64, thenReplaceWith : Int64) -> Bool {
        return OSAtomicCompareAndSwap64Barrier(value,thenReplaceWith,__value.unsafe_pointer)
    }
}
