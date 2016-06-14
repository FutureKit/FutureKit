Simple Cancellation:  
---------------

1) Get a token().    
```
   let f = someAsyncFunction()
   let token = f.getCancelToken()
```
2) when you are ready to cancel it you cancel it.
```
    token.cancel()
```

There are some options on cancel() that I haven't told you about yet.  Usually you don't need them .  
But you need them in some edge cases, which I can explain after some basics:

if you have a chain of futures composed with 'onSuccess/onComplete' cancellations are forwarded as you would expect.

```
   let f = asyncFunc1().onSuccess { 
              return asyncFunc2()
       }
   let token = f.getCancelToken()
```
   later you call:
```
   token.cancel()
```

The cancellation will be 'forwarded' correctly to EITHER asyncFunc1()'s future OR asyncFunc2()'s future, depending when the cancellation happens.

You can also just call 'getCancelToken()' at the tail of your chain.
```
   let token = asyncFunc1().onSuccess { 
              return asyncFunc2()
       }.getCancelToken()
```

Remember:  Cancellations are never guaranteed!  You may still get a Success or Fail response, even if you 'requested' a cancelation.  This is intentional by design.   Think of the cancellation as a polite 'request' to be please stop, I dont need the answer anymore.  But since there is always a chance that the future has already been completed prior to the cancellation request, it's good form to never assume you will get a cancellation result, just because you requested a cancellation.

Also:  If the Future hasn't been implemented to support being cancelled, than the cancel() request will ALWAYS be ignored!  


Implementing Cancellation in your custom Promises:
---------------

If you are implementing a Promise, you should strongly consider adding cancellation support.  If you don't, than even if your consumer cancels it, the default logic is to IGNORE it.  Good Promise implementations allow for cancellations.   And FutureKit actually makes it really easy and reliable.

You add support for cancellation by adding a cancellation handler via onRequestCancel()
What you CAN'T do inside of onRequestCancel() is call any of the promises methods (like completeWithCancellation()).   Doing so causes all sort of retain cycle loop issues.  Which are terrible.  So instead we allow the onRequestCancel() to do it's work via it's own enumeration result.

The block will be given the set CancellationOptions (that were sent by the consumer - more on those later..) and you are required to respond to the method with a enumeration: CancelRequestResponse<T>.   
You basically need to respond to the request with either: 
    

-   .Continue  -   This means that the future should continue running.  And you plan on 'cancelling' the promise later with a call to  p.completeWithCancellation().    Very useful if you just want to forward to some other underlying cancel() method you are wrapping, and you still have to wait for an async confirmation. 
-   .Complete(Completion<T>)  -   you want to complete the promise right away, with the following completion.   You can even complete the promise with Success/Fail.  You could also decide to complete the promise with the use of some other subFuture via .Complete(.CompleteUsing(subFuture)).   


```
func asynFunc() -> Future<Int> {
    let p = Promise<Int>()
    p.onRequestCancel()  { options:CancellationOptions in 
         return . Complete(.Cancelled)
    }
   return p.future
}
```

Or more typically this is my snippet from the AlamoFire/FutureKit wrapper:

```
public extension Request {
    
    // so AlamoFire uses V as the Value Type and T as the serializer type.  Letters gotta match here or swift 2.0 gets superconfused.
    
    public func future<T: ResponseSerializerType>(responseSerializer s: T) -> Future<T.SerializedObject> {
        let p = Promise<T.SerializedObject>()
        p.onRequestCancel { _  in
            self.cancel()       // AlamoFire will send NSURLErrorDomain,.NSURLErrorCancelled error if cancel is successful
            return .Continue    // wait for NSError to arrive before canceling future.
        }
        
        self.response(queue: nil, responseSerializer: s) { response -> Void in
            switch response.result {
            case let .Success(t):
                p.completeWithSuccess(t)
            case let .Failure(error):
                let e = error as NSError
                if (e.domain == NSURLErrorDomain) && (e.code == NSURLErrorCancelled) {
                    p.completeWithCancel()
                }
                else {
                    p.completeWithFail(error)
                }
            }
        }

        
        return p.future

    }
```

Here we are just forwarding the cancelation request to the Request.cancel() method.   And we are checking for a 'cancellation' result when we look at the AlamoFire response. 


Advanced Stuffs - Future 'Chains'  vs Future 'Trees'
---------------

So ... Things get strange if you have a Future with multiple consumers.   Most Futures have a single consumer.  So typically there is a single "chain" of Futures that have been created, and FutureKit will by default always try to forward cancellations up the chain.

But what happens if you grab two tokens from the same future?
 Example:
```
   let future:Future<Void> = asyncFunc()
   let token1 = future.getCancelToken()
   let token2 = future.getCancelToken()
```

and than later..
```
   token1.cancel()
```

What happens?  Well.. by default.. all of these futures will be cancelled.  But is this the right behavior?

While the first consumer is no longer intestested in the result.. that doesn't mean the second one is not.  

Instead of a dependent "chain" , FutureKit has figured out that there is a dependent "tree" of futures.   And while one 'branch' isn't interested in the 'top' of the tree, that doesn't mean other branches still aren't.  By default FutureKit 2.0 will now forward this result (FutureKit 1.x used to not forward).


This sort of thing can happen if you also 'compose' two futures from the same shared future, since deep inside onSuccess() and onComplete() is a call to getCancellationToken()...

```
   let future:Future<Void> = asyncFunc()
   let subFuture1 = future.onSuccess {
        ....
  }
   let subFuture2 = future.onSuccess {
        ....
  }
  let token = subFuture2.getCancellationToken()
  token.cancel()   /// future is NOT cancelled, nor is subFuture1
```

What can you do?
well there is some options on cancel.  They all have horribly long names, but that's intentional so people understand whats happening when there are dependent 'trees' vs a single 'chain'

```
  token.cancel([.DoNotForwardCancelRequestIfThereAreOtherFuturesWaiting])  // Don't cancel other futures that still want the depdent future.
```

There is also a way to NOT forward your cancellation 'up' the chain.  Let's say you are using a subFuture, that you want to cancel, without cancelling the whole chain.

```
  token.cancel([.DoNotForwardRequest])  // Only the future that created this token will be canceled.  Not any future it was dependent on.  Useful for cancelling only the 'last' future in a chain of futures.  
```
And lastly there is an option for canceling future 'dirty'.   This means you really want an immediate cancellation result - EVEN IF the underlying logic has not been cancelled or cleaned up.  This is the equivalent of calling p.completeWithCancellation() on the underlying promise.

```
  token.cancel([.ForceThisFutureToBeCancelledImmediately])
```


Forcing a future to cancel is bad practice.  It won't cause any of the resources underneath to actually stop running.  They may keep going until they complete, and when they try to 'complete' the promise their result will be ignored (a Promise can only be completed once!  subsequent completions are ignored).


....









