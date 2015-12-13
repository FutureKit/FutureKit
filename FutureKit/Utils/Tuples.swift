//
//  Tuples.swift
//  FutureKit
//
//  Created by Michael Gray on 10/21/15.
//  Copyright © 2015 Michael Gray. All rights reserved.
//

import Foundation

private protocol _OptionalType {
    typealias Wrapped
    
    var _optional : Wrapped? { get }
    
}

extension Optional : _OptionalType {
    var _optional : Wrapped? {
        return self
    }
}


// This will extend 'indexable' collections, like Arrays to allow some conviences tuple implementations
public extension SequenceType where Self:Indexable, Self.Index : IntegerLiteralConvertible {
    
    private func _get_element<T>(index : Index) -> T {
        let x = self[index]
        let t = x as? T
        assert(t != nil, "did not find type \(T.self) at index \(index) of \(Self.self)")
        return t!
    }

    public func toTuple<A,B>() -> (A,B) {
        return
            (self._get_element(0),
             self._get_element(1))
    }
    public func toTuple<A, B, C>() -> (A, B, C) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2))
    }
    public func toTuple<A, B, C, D>() -> (A, B, C, D) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3))
    }
    public func toTuple<A, B, C, D, E>() -> (A, B, C, D, E) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4))
    }
    public func toTuple<A, B, C, D, E, F>() -> (A, B, C, D, E, F) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5))
    }
    public func toTuple<A, B, C, D, E, F, G>() -> (A, B, C, D, E, F, G) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5),
            self._get_element(6))
    }
    public func toTuple<A, B, C, D, E, F, G, H>() -> (A, B, C, D, E, F, G, H) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5),
            self._get_element(6),
            self._get_element(7))
    }
    public func toTuple<A, B, C, D, E, F, G, H, I>() -> (A, B, C, D, E, F, G, H, I) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5),
            self._get_element(6),
            self._get_element(7),
            self._get_element(8))
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J>() -> (A, B, C, D, E, F, G, H, I, J) {
        return (self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5),
            self._get_element(6),
            self._get_element(7),
            self._get_element(8),
            self._get_element(9))
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J, K>() -> (A, B, C, D, E, F, G, H, I, J, K) {
        return (
            self._get_element(0),
            self._get_element(1),
            self._get_element(2),
            self._get_element(3),
            self._get_element(4),
            self._get_element(5),
            self._get_element(6),
            self._get_element(7),
            self._get_element(8),
            self._get_element(9),
            self._get_element(10))
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J, K, L>() -> (A, B, C, D, E, F, G, H, I, J, K, L) {
        return (self._get_element(0),
                self._get_element(1),
                self._get_element(2),
                self._get_element(3),
                self._get_element(4),
                self._get_element(5),
                self._get_element(6),
                self._get_element(7),
                self._get_element(8),
                self._get_element(9),
                self._get_element(10),
                self._get_element(11))
    }
}


public extension SequenceType  { // Some sequences don't have integer indexes, so we will use generators.
    
    private func _get_element<T>(inout generator : Generator) -> T {
        let x = generator.next()
        assert(x != nil, "toTuple() did not find enough values inside \(Self.self)")
        let t = x! as? T
        assert(t != nil, "toTuple() did not find type \(T.self) inside \(Self.self)")
        return t!
    }

    public func toTuple<A,B>() -> (A,B) {
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        return (a,b)
    }
    public func toTuple<A, B, C>() -> (A, B, C) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        return (a,b,c)
    }
    public func toTuple<A, B, C, D>() -> (A, B, C, D) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        return (a,b,c,d)
    }
    public func toTuple<A, B, C, D, E>() -> (A, B, C, D, E) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        return (a,b,c,d,e)
    }
    public func toTuple<A, B, C, D, E, F>() -> (A, B, C, D, E, F) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        return (a,b,c,d,e,f)
    }
    public func toTuple<A, B, C, D, E, F, G>() -> (A, B, C, D, E, F, G) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        return (a,b,c,d,e,f,g)
    }
    public func toTuple<A, B, C, D, E, F, G, H>() -> (A, B, C, D, E, F, G, H) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        let h: H = self._get_element(&generator)
        return (a,b,c,d,e,f,g,h)
    }
    public func toTuple<A, B, C, D, E, F, G, H, I>() -> (A, B, C, D, E, F, G, H, I) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        let h: H = self._get_element(&generator)
        let i: I = self._get_element(&generator)
        return (a,b,c,d,e,f,g,h,i)
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J>() -> (A, B, C, D, E, F, G, H, I, J) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        let h: H = self._get_element(&generator)
        let i: I = self._get_element(&generator)
        let j: J = self._get_element(&generator)
        return (a,b,c,d,e,f,g,h,i,j)
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J, K>() -> (A, B, C, D, E, F, G, H, I, J, K) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        let h: H = self._get_element(&generator)
        let i: I = self._get_element(&generator)
        let j: J = self._get_element(&generator)
        let k: K = self._get_element(&generator)
        return (a,b,c,d,e,f,g,h,i,j,k)
    }
    public func toTuple<A, B, C, D, E, F, G, H, I, J, K, L>() -> (A, B, C, D, E, F, G, H, I, J, K, L) {
        
        var generator = self.generate()
        let a: A = self._get_element(&generator)
        let b: B = self._get_element(&generator)
        let c: C = self._get_element(&generator)
        let d: D = self._get_element(&generator)
        let e: E = self._get_element(&generator)
        let f: F = self._get_element(&generator)
        let g: G = self._get_element(&generator)
        let h: H = self._get_element(&generator)
        let i: I = self._get_element(&generator)
        let j: J = self._get_element(&generator)
        let k: K = self._get_element(&generator)
        let l: L = self._get_element(&generator)
        return (a,b,c,d,e,f,g,h,i,j,k,l)
    }
}


public func tupleToArray<T : ArrayLiteralConvertible, A>(tuple:(A)) -> T {
    return [tuple as! T.Element]
}

public func tupleToArray<T : ArrayLiteralConvertible,A,B>(tuple:(A,B)) -> T {
    return [tuple.0 as! T.Element,
           tuple.1 as! T.Element]
}

public func tupleToArray<T : ArrayLiteralConvertible,A, B, C>(tuple:(A, B, C)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element]
}

public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D>(tuple:(A, B, C, D)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E>(tuple:(A, B, C, D, E)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F>(tuple:(A, B, C, D, E, F)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G>(tuple:(A, B, C, D, E, F, G)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G, H>(tuple:(A, B, C, D, E, F, G, H)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element,
            tuple.7 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G, H, I>(tuple:(A, B, C, D, E, F, G, H, I)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element,
            tuple.7 as! T.Element,
            tuple.8 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G, H, I, J>(tuple:(A, B, C, D, E, F, G, H, I, J)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element,
            tuple.7 as! T.Element,
            tuple.8 as! T.Element,
            tuple.9 as! T.Element]
}
public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G, H, I, J, K>(tuple:(A, B, C, D, E, F, G, H, I, J, K)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element,
            tuple.7 as! T.Element,
            tuple.8 as! T.Element,
            tuple.9 as! T.Element,
            tuple.10 as! T.Element]
}

public func tupleToArray<T : ArrayLiteralConvertible,A, B, C, D, E, F, G, H, I, J, K, L>(tuple:(A, B, C, D, E, F, G, H, I, J, K, L)) -> T {
    return
        [tuple.0 as! T.Element,
            tuple.1 as! T.Element,
            tuple.2 as! T.Element,
            tuple.3 as! T.Element,
            tuple.4 as! T.Element,
            tuple.5 as! T.Element,
            tuple.6 as! T.Element,
            tuple.7 as! T.Element,
            tuple.8 as! T.Element,
            tuple.9 as! T.Element,
            tuple.10 as! T.Element,
            tuple.11 as! T.Element]
}

