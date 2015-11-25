//
//  FutureKit+RAC.swift
//  CoverPages
//
//  Created by Michael Gray on 9/10/15.
//  Copyright © 2015 Squarespace. All rights reserved.
//

import Foundation
import ReactiveCocoa
import FutureKit


public extension SignalProducerType {
    
    /**
        Start a SignalProducer and bind a Future<T> to it's signal.
        Signals that complete without a sending a .Next(T) first, will assert on Debug builds, and return .Fail on release builds.
        Signals that send .Error will return .Fail
        Signals that send .Interrupted will return .Cancelled
    */
    public final func startWithFuture() -> Future<Value> {
        let p = Promise<Value>()
        
        self.startWithSignal { (signal, disposable) -> () in
            signal.completePromise(p)
            
            p.onRequestCancel { _ in
                disposable.dispose()
                return CancelRequestResponse<Value>.Continue
            }
        }
        return p.future
    }
    
    /// Forwards all events onto the given scheduler, instead of whichever
    /// scheduler they originally arrived upon.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func observeOn(executor: Executor) -> SignalProducer<Value, Error> {
        return lift { $0.observeOn(executor) }
    }

    /// Forwards all events onto the given scheduler, instead of whichever
    /// scheduler they originally arrived upon.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func lazy() -> SignalProducer<Value, Error> {
        return lift { $0.lazy() }
    }
    
    public func flatMap<U>(strategy: ReactiveCocoa.FlattenStrategy, ftransform: Self.Value -> Future<U>) -> SignalProducer<U, Error> {
        
        return self.flatMap(strategy) { value in
            
            return SignalProducer<U,Error> {
                return ftransform(value)
            }
        }
        
    }

}

public extension SignalProducer {
    
    
    /**
        create a SignalProducer, using any block that returns a Future<T>.
        The block will be called everytime 'start' is called on the SignalProducer.
    
        example:
            SignalProducer<Int,NSError> { () -> Future<Int> in
                return functionThatReturnsFutureInt()
            }
    
        FutureResult maps to Event<T,E> as follows:
            .Success(T)         -> .Next(T)/.Completed
            .Fail(errorType)    -> .Error(errorType as! E) 
            .Cancelled          -> .Interrupted
    
        Warning: .Fail(errorType) payloads will be converted to E using as!.   
            This may cause exceptions if the Future returns an illegal errorType.
           alternatively use `init(_ futureProducer: () -> Future<T>, mapError : (ErrorType) -> E)`
    
        If SignalProducer defines the .NoError type, than an assertion will fail (in Debug Builds) if the Future returns an Error.
    */
    public init(_ futureProducer: () -> Future<Value>) {
        
        
        self.init { observer, disposable in

            let f = futureProducer()
            disposable += f.getDisposable()
            f.completeSignal(observer)
       }
        
    }
    
    /**
    create a SignalProducer, using any block that returns a Future<T>.
    The block will be called everytime 'start' is called on the SignalProducer.
    
    FutureResult maps to Event<T,E> as follows:
        .Success(T)         -> .Next(T)/.Completed
        .Fail(errorType)    -> .Error(mapError(errorType))
        .Cancelled          -> .Interrupted
    

    If SignalProducer defines the .NoError type E, than an assertion will fail (in Debug Builds) if the Future returns an Error.

    */
    public init(_ futureProducer: () -> Future<Value>, mapError : (ErrorType) -> Error) {
        
        self.init { observer, disposable in
            
            let f = futureProducer()
            disposable += f.getDisposable()
            f.completeSignal(observer, mapError: mapError)
        }
    }
    
}

extension Action {
    
    ///
    convenience init<P: PropertyType where P.Value == Bool>(enabledIf: P, future_block: Input -> Future<Output>) {
        
        self.init(enabledIf: enabledIf) { (input:Input) -> SignalProducer<Output,Error> in
            
            return SignalProducer {
                return future_block(input)
            }
        }
        
    }

    convenience init(future_block: Input -> Future<Output>) {
        
        self.init(enabledIf: ConstantProperty(true)) { (input:Input) -> SignalProducer<Output,Error> in
            
            return SignalProducer {
                return future_block(input)
            }
        }
        
    }

    convenience init(block: Input -> Output) {
        
        self.init(enabledIf: ConstantProperty(true)) { (input:Input) -> SignalProducer<Output,Error> in
            
            return SignalProducer {
                return Future<Output> {
                    return block(input)
                }
            }
        }
        
    }

}

extension Future {
    
    public final func signal<E:ErrorType>(mapError : (ErrorType) -> E) -> Signal<T,E> {
        let (signal,sink) = Signal<T,E>.pipe()
        self.completeSignal(sink,mapError:mapError)
        return signal
    }

    public final func signal<E:ErrorType>() -> Signal<T,E> {
        let (signal,sink) = Signal<T,E>.pipe()
        self.completeSignal(sink)
        return signal
    }

    func getDisposableIfNotCompleted() -> Disposable? {
        return self.getCancelToken()
    }


    func getDisposable() -> Disposable {
        return self.getCancelToken()
    }

    // warning - this is implicity a one to many relationship between a Future and a SignalProducer.
    // this may be useful to cache a Future and than generate a
    // This will return a new producer that will just bind to this Future everytime start is called.
    // If you need to create a new Future everytime 'start' is called on the producer, than use `SignalProducer(_ futureProducer: () -> Future<T>)` instead.
    public final func producer<E : ErrorType>(mapError : (ErrorType) -> E) -> SignalProducer<T,E> {
        
        return SignalProducer { sink,disposable in
            self.completeSignal(sink, mapError: mapError)
        }
    }
    
    public final func producer<E:ErrorType>() -> SignalProducer<T,E> {
        return self.producer { (e) -> E in
            return e as! E
        }
    }
    
}

extension Future where T : AnyObject {
    func racSignal() -> RACSignal {
        let sp = SignalProducer<T,NSError> { () -> Future<T> in
            return self
        }
        return toRACSignal(sp)
    }
}


extension Future where T : SequenceType {
    
    // if you have a future that returns a sequence of items, you can filter that seqeunce into a new subarray.
    public final func filter(predicate: T.Generator.Element -> Bool) -> Future<[T.Generator.Element]> {
        return map { $0.filter(predicate) }
    }

    
    // if you have a future that returns a sequence of values, than create a SignalProducer that will genenrate a Signal where each value is seen once.
    public final func producerOfElements<E:ErrorType>() -> SignalProducer<T.Generator.Element,E> {
        
        return SignalProducer<T.Generator.Element,E> { sink,disposable in
            
            self.onSuccess  { values -> Void in
                for i in values {
                    sink.sendNext(i)
                }
                sink.sendCompleted()
            }
            self.onFail { error -> Void in
                sink.sendFailed(error as! E)
            }
        }
    }

    
    // if you have a future that returns a sequence of values, than create a SignalProducer that will genenrate a Signal where each value is seen once.
    public final func signalOfElements<E:ErrorType>() -> Signal<T.Generator.Element,E> {
        
        let (signal,sink) = Signal<T.Generator.Element,E>.pipe()
        self.onSuccess  { values -> Void in
            for i in values {
                sink.sendNext(i)
            }
            sink.sendCompleted()
        }
        self.onFail { error -> Void in
            sink.sendFailed(error as! E)
        }
        return signal
    }

}


extension CancellationToken : Disposable {
    public var disposed: Bool {
        return !self.cancelCanBeRequested
    }
    
    public func dispose() {
        self.cancel()
    }
}


extension SignalType {
    /// Forwards all events onto the given scheduler, instead of whichever
    /// scheduler they originally arrived upon.
    public final func observeOn(executor: Executor) -> Signal<Value, Error> {
        return Signal { observer in
            return self.observe { event in
                executor.execute {
                    observer.action(event)
                }
            }
        }
    }
    /// will reschedule events to run in the same Execution context, but only after an dispatchAsync()
    public final func lazy() -> Signal<Value, Error> {
        return observeOn(.CurrentAsync)
    }
}

/** The extension is defined as internal, since it's actually tricky and dangerous to try to convert a Signal to a future,
    unless you guarantee you can call completePromise() before the Signal has started reciving values 

    Use SignalProducer.startWithFuture() to bind a SignalProducer's Signal to a Future
*/
internal extension SignalType {
    
    internal final func completePromise(promise : Promise<Value>) {
        var lastResultSeen : Value?
        let disposable = self.observe { event in
            
            switch event {
            case .Next(let result):
                lastResultSeen = result
            case .Failed(let error):
                promise.completeWithFail(error)
                break
            case .Completed:
                assert(lastResultSeen != nil, "Signal completed with a result!")
                if let result = lastResultSeen {
                    promise.completeWithSuccess(result)
                }
                else {
                    promise.completeWithFail("Signal completed with any result! (FutureKit Promise has been broken!)")
                }
                break
            case .Interrupted:
                promise.completeWithCancel()
                break
            }
            
        }
        
        // if someone requests we cancel the Future, than try to dispose of the future.
        if let d = disposable {
            promise.onRequestCancel { (options) -> CancelRequestResponse<Value> in
                d.dispose()
                return .Continue  // NOTE!  We are trusting the Signal to send .Interrupted!
            }
        }
    }
    
    // warning - calling future on a Signal may not work correctly if the Signal is already been completed.
    // Care should be taken.  
    // Consider using `SignalProducer(_ futureProducer: () -> Future<T>)`
    internal final var future: Future<Value> {
        let p = Promise<Value>()
        self.completePromise(p)
        return p.future
    }
    
}


internal extension FutureResult {
    
    func sendResultToObserver<E:ErrorType>(
        observer : Observer<T,E>,
        mapError : (ErrorType) -> E) {
            switch self {
            case let .Success(value):
                observer.sendNext(value)
                observer.sendCompleted()
            case let .Fail(error):
                assert(E.self != NoError.self, "Signal is of type NoError - don't send Errors!")
                observer.sendFailed(mapError(error))
            case .Cancelled:
                observer.sendInterrupted()
            }
    }

    func sendResultToObserver<E:ErrorType>(
        observer : Observer<T,E>) {
            return sendResultToObserver(observer, mapError: { (e) -> E in
                return e as! E
            })
    }
    
}

extension Future {
    
    internal final func completeSignal<E:ErrorType>(
                observer : Observer<T,E>,
                mapError : (ErrorType) -> E) {
        self.onComplete { (result) -> Void in
            result.sendResultToObserver(observer, mapError: mapError)
        }
    }
    internal final func completeSignal<E:ErrorType>(
        observer : Observer<T,E>) {
            self.onComplete { (result) -> Void in
                result.sendResultToObserver(observer)
            }
    }
}

