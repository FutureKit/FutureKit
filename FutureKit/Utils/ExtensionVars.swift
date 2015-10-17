//
//  ExtensionVars.swift
//  Shimmer
//
//  Created by Michael Gray on 11/25/14.
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

// this class really SHOULD work, but it sometimes crashes the compiler
// so we mostly use WeakAnyObject and feel angry about it
class Weak<T: AnyObject> : NilLiteralConvertible {
    weak var value : T?
    init (_ value: T?) {
        self.value = value
    }
    required init(nilLiteral: ()) {
        self.value = nil
    }
}

class WeakAnyObject : NilLiteralConvertible {
    weak var value : AnyObject?
    init (_ value: AnyObject?) {
        self.value = value
    }
    required init(nilLiteral: ()) {
        self.value = nil
    }
}

// We use this to convert a Any value into an AnyObject
// so it can be saved via objc_setAssociatedObject
class Strong<T:Any> : NilLiteralConvertible {
    var value : T?
    init (_ value: T?) {
        self.value = value
    }
    required init(nilLiteral: ()) {
        self.value = nil
    }
}


// So... you want to allocate stuff via UnsafeMutablePointer<T>, but don't want to have to remember 
// how to allocate and deallocate etc..
// let's make a utility class that allocates, initializes, and deallocates

class UnSafeMutableContainer<T> {
    var unsafe_pointer : UnsafeMutablePointer<T>
    
    var memory : T {
        get {
            return unsafe_pointer.memory
        }
        set(newValue) {
            unsafe_pointer.destroy()
            unsafe_pointer.initialize(newValue)
        }
    }
    init() {
        unsafe_pointer = UnsafeMutablePointer<T>.alloc(1)
    }
    init(_ initialValue: T) {
        unsafe_pointer = UnsafeMutablePointer<T>.alloc(1)
        unsafe_pointer.initialize(initialValue)
    }
    deinit {
        unsafe_pointer.dealloc(1)
    }
}



// Allocate a single static (module level var) ExtensionVarHandler for EACH extension variable you want to add 
// to a class
public struct ExtensionVarHandlerFor<A : AnyObject> {
    
    private var keyValue = UnSafeMutableContainer<Int8>(0)
    private var key : UnsafeMutablePointer<Int8>  { get { return keyValue.unsafe_pointer } }
    
    
    public init() {
        
    }
    
    // Two STRONG implementations - Any and AnyObject.
    // AnyObject will match NSObject compatible values
    // Any will match any class, using the Strong<T> to wrap the object in a class so it can be set correctly
    // This is the "default set".
    public func setStrongValueOn<T : Any>(object:A, value : T?)
    {
        // so we can't 'test' for AnyObject but we can seem to test for NSObject
        let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        
        if let v = value {
            objc_setAssociatedObject(object, key, Strong<T>(v), policy)
        }
        else {
            objc_setAssociatedObject(object, key, nil, policy)
        }
    }
    public func setStrongValueOn<T : AnyObject>(object:A, value : T?)
    {
        let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        objc_setAssociatedObject(object, key, value, policy)
    }
    
    // Any values cannot be captured weakly.  so we don't supply a Weak setter for Any
    public func setWeakValueOn<T : AnyObject>(object:A, value : T?)
    {
        let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        if let v = value {
            let wp = WeakAnyObject(v)
            objc_setAssociatedObject(object, key, wp, policy)
        }
        else {
            objc_setAssociatedObject(object, key, nil, policy)
        }
    }
    
    public func setCopyValueOn<T : AnyObject>(object:A, value : T?)
    {
        let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_COPY
        objc_setAssociatedObject(object, key, value, policy)
    }
    
    // convience - Set is always Strong by default
    public func setValueOn<T : Any>(object:A, value : T?)
    {
        self.setStrongValueOn(object, value: value)
    }
    
    public func setValueOn<T : AnyObject>(object:A, value : T?)
    {
        self.setStrongValueOn(object, value: value)
    }
    
    public func getValueFrom<T : Any>(object:A) -> T?
    {
        let v: AnyObject? = objc_getAssociatedObject(object,key)
        switch v {
        case nil:
            return nil
        case let t as T:
            return t
        case let s as Strong<T>:
            return s.value
        case let w as WeakAnyObject:
            return w.value as? T
        default:
            assertionFailure("found unknown value \(v) in getExtensionVar")
            return nil
        }
    }
    
    public func getValueFrom<T : Any>(object:A, defaultvalue : T) -> T
    {
        let value: T? = getValueFrom(object)
        if let v = value {
            return v
        }
        else {
            self.setStrongValueOn(object,value: defaultvalue)
            return defaultvalue
        }
    }
    
    public func getValueFrom<T : Any>(object:A, defaultvalueblock : () -> T) -> T
    {
        let value: T? = getValueFrom(object)
        if let v = value {
            return v
        }
        else {
            let defaultvalue = defaultvalueblock()
            self.setStrongValueOn(object,value: defaultvalue)
            return defaultvalue
        }
    }
    
    public func clear(object:A)
    {
        let policy = objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC
        objc_setAssociatedObject(object, key, nil, policy)
    }

}

public typealias ExtensionVarHandler = ExtensionVarHandlerFor<AnyObject>




/// EXAMPLE FOLLOWS :

class __ExampleClass : NSObject {
    var regularVar : Int = 99
    
}
private var exampleIntOptionalHandler = ExtensionVarHandler()
private var exampleIntHandler = ExtensionVarHandler()
private var exampleDelegateHandler = ExtensionVarHandler()
private var exampleAnyObjectHandler = ExtensionVarHandler()
private var exampleDictionaryHandler = ExtensionVarHandler()

extension __ExampleClass {
    var intOptional : Int? {
        get { return exampleIntOptionalHandler.getValueFrom(self) }
        set(newValue) {
            exampleIntOptionalHandler.setValueOn(self, value: newValue)
        }
    }
    var intWithDefaultValue : Int {
        get {
            return exampleIntHandler.getValueFrom(self,defaultvalue: 55)
        }
        set(newValue) {
            exampleIntHandler.setValueOn(self, value: newValue)
        }
    }
    var weakDelegatePtr : NSObject? {
        get {
            return exampleDelegateHandler.getValueFrom(self)
        }
        set(newDelegate) {
            // note the use of WEAK!  This will be a safe weak (zeroing weak ptr).  Not an unsafe assign!
            exampleDelegateHandler.setWeakValueOn(self, value: newDelegate)
        }
    }
    var anyObjectOptional : AnyObject? {
        get {
            return exampleAnyObjectHandler.getValueFrom(self)
        }
        set(newValue) {
            exampleAnyObjectHandler.setValueOn(self, value: newValue)
        }
    }
    var dictionaryWithDefaultValues : [String : Int] {
        get {
            return exampleDictionaryHandler.getValueFrom(self,defaultvalue: ["Default" : 99, "Values" : 1])
        }
        set(newValue) {
            exampleDictionaryHandler.setValueOn(self, value: newValue)
        }
    }
}


func _someExampleStuffs() {
    
    let e = __ExampleClass()
    e.regularVar = 22   // this isn't an extension var, but defined in the original class
    
    assert(e.intWithDefaultValue == 55, "default values should work!")

    e.intOptional = 5
    e.intOptional = nil
    let value = e.dictionaryWithDefaultValues["Default"]!
    assert(value == 99, "default values should work!")
    
    e.weakDelegatePtr = e    // won't cause a RETAIN LOOP! cause it's a weak ptr
    
    e.anyObjectOptional = e  // this will cause a RETAIN LOOP!  (bad idea, but legal)
    e.anyObjectOptional = nil  // let's not leave that retain loop alive
    
}




