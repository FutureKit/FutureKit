
import FutureKit
#if os(iOS)
    import UIKit
    #else
    import Cocoa
    typealias UIImage = NSImage
    typealias UIImageView = NSImageView
#endif
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true


class ImageViewController : UIViewController {

    var imageView: UIImageView!
    override func loadView() {

        // UI

        let view = UIView()
        view.backgroundColor = .white

//        let image = UIImage(named: "Apple.jpg")
        self.imageView = UIImageView()

        view.addSubview(imageView)

        // Layout

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
            ])

        self.view = view
    }

}

PlaygroundPage.current.liveView = ImageViewController()

let namesPromise = Promise<[String]>()

//: the promise has a var `future`.  we can now return this future to others.
let namesFuture :Future<[String]> = namesPromise.future

var timeCounter = 0
namesFuture.onSuccess(.main) { (names : [String]) -> Void in
    for name in names {
        timeCounter += 1
        let timeCount = timeCounter
        let greeting = "Happy Future Day \(name)!"
        print(greeting)
    }
}
//: so we have a nice routine that wants to greet all the names, but someone has to actually SUPPLY the  names.  Where are they?
let names = ["Skyer","David","Jess"]
// let t = timeCounter += 1
namesPromise.completeWithSuccess(names)
//: Notice how the timeCounter shows us that the logic inside onSuccess() is executing after we execute completeWithSuccess().

//: A more typical case if you need to perform something inside a background queue.
//: I need a cat Picture.  I want to see my cats!  So go get me some!
//: Let's write a function that returns an Image.  But since I might have to go to the internet to retrieve it, we will define a function that returns Future instead
func getCoolCatPic(url: URL) -> Future<UIImage> {
    
    // We will use a promise, so we can return a Future<Image>
    let catPicturePromise = Promise<UIImage>()
    
    // go get data from this URL.
    let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
        if let e = error {
            // if this is failing, make sure you aren't running this as an iOS Playground. It works when running as an OSX Playground.
            catPicturePromise.completeWithFail(e)
        }
        else {
            // parsing the data from the server into an Image.
            if let d = data,
                let image = UIImage(data: d) {
                    let i = image
                    catPicturePromise.completeWithSuccess(i)
            }
            else {
                catPicturePromise.completeWithErrorMessage("couldn't understand the data returned from the server \(url) - \(response)")
            }
        }
        // make sure to keep your promises!
        // promises are promises!
        assert(catPicturePromise.isCompleted)
    }
    
    // add a cancellation Request handler.  If someone wants to cancel the Future, what should we do?
    catPicturePromise.onRequestCancel { (options) -> CancelRequestResponse<UIImage> in
        task.cancel()
        return .complete(.cancelled)
    }
    
    // start downloading.
    task.resume()
    
    // return the promise's future.
    return catPicturePromise.future
}




let catUrlIFoundOnTumblr = URL(string: "http://25.media.tumblr.com/tumblr_m7zll2bkVC1rcyf04o1_500.gif")!

let imageFuture = getCoolCatPic(url:catUrlIFoundOnTumblr)
    
imageFuture.onComplete(.mainAsync) { (result) -> Void in
    switch result {
    case let .success(value):
        let i = value
        print(i)
        imageView.image = value
    case let .fail(error):
        print("error \(error.localizedDescription)")
    case .cancelled:
        print("cancelled")
        break
    }
}



FutureBatch([imageFuture,namesFuture]).resultsFuture.onComplete(.mainAsync) { _ in
    print("done")
    PlaygroundPage.current.finishExecution()
}
//: [Next](@next)
