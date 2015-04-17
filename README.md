# FutureKit
A Swift based Future/Promises Library for IOS and OS X.   


FutureKit is a iOS implementation of Futures and Promises, but modified specifically for iOS/OSX programmers.

WARNING - Half Written Readme.  Better docs coming soon.

# Some background - 

There are number of different Future/Promise varients for different langauages.
You can read about some here:
http://en.wikipedia.org/wiki/Futures_and_promises

I discovered them when doing backend programming using Scala. And once you master them, they solve all sorts of issues.

For iOS/OSX, your "closest" existing Future/Promises implementation is currently Bolts.
https://github.com/BoltsFramework/Bolts-iOS

And I LOVE Bolts!  And wrote a bunch of Bolts.

But then Swift came out.   And we started using Bolts with Swift, but it didn't feel right.  

I immediately ported Bolts to a native Swift version.  (You can find a version of that here:https://github.com/mishagray/SwiftTask).  
But my coworkers still had issues with Bolts (and also with my Swift Port).   

All this "dependentTask" etc.  I started writing methods that returned "Tasks" and my fellow programmer asked me "how do I start this Task?".  "Why do I have to keep returning 'nil'".    And eventually they figured it out, but I think they still look at me funny when I'm not looking

So While the BFTask IMPLEMENTATION is pretty spot on (you can still shadows of its implementation here).  The nomenclature was strange to understand.   And it wasn't swift!  



# FutureKit is TYPE SAFE

FutureKit is 100% Swift and uses Swift Generics heavily to ensure you methods are type safe

FutureKit uses simpler handler methods (onComplete/onSuccess/onFail etc). 
FutureKit is still highly composable, since any existing Future<T> can be 'mapped' to a new Future<S>.

# Documentation 

FutureKit documentation is being written as XCode Playgrounds.  The best way to start is to open the FutureKit.workspace and then opening the Playgrounds inside.  (If you open the Playgrounds outside of the workspace, then FutureKit module may not import correctly).
The XCode Playgrounds probably require XCode 6.3 (in order to see the Markup correcty)

If you are impatient, or not near your copy of XCode, you can try to read the first intro "raw" playground here:
https://github.com/mishagray/FutureKit/blob/master/FutureKit-Future.playground/Contents.swift













