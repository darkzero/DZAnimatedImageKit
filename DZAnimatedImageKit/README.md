# DZAnimatedImageKit

Animated image view library for iOS (`GIF/APNG`) with both SwiftUI and UIKit APIs.

## Requirements

- iOS 15+
- Swift 6.1+

## Installation

Add `DZAnimatedImageKit` through Swift Package Manager.

In Xcode:

1. `File` -> `Add Package Dependencies...`
2. Select your repository URL or local package path
3. Add product: `DZAnimatedImageKit`

## SwiftUI

Import the package:

```swift
import SwiftUI
import DZAnimatedImageKit
```

### Load a remote animated image

```swift
struct DemoView: View {
    var body: some View {
        DZAnimatedImageView(
            animatedImage: AnimatedImage(url: URL(string: "https://example.com/demo.gif")!),
            placeHolder: .systemImage("photo", .gray),
            repeatMode: .infinite,
            preloadCount: 6
        )
        .frame(width: 220, height: 220)
    }
}
```

### Load a local animated image

```swift
struct LocalDemoView: View {
    var body: some View {
        DZAnimatedImageView(
            animatedImage: AnimatedImage(path: Bundle.main.path(forResource: "sample", ofType: "gif")!),
            placeHolder: .color(.black.opacity(0.08)),
            repeatMode: .finite(3)
        )
        .frame(width: 220, height: 220)
    }
}
```

### Customize the progress overlay

```swift
DZAnimatedImageView(
    animatedImage: AnimatedImage(url: URL(string: "https://example.com/demo.gif")!),
    progressOverlay: { state, size in
        DZCircularProgressView(
            state: state,
            size: 56,
            lineWidth: 6,
            progressColor: .green,
            spinnerColor: .green
        )
    }
)
.frame(width: 220, height: 220)
```

### Loop and finish callbacks

```swift
struct PlaylistView: View {
    @State private var index = 0
    let items: [AnimatedImage]

    var body: some View {
        DZAnimatedImageView(
            animatedImage: items[index],
            repeatMode: .once,
            onLoop: { count in
                print("loop:", count)
            },
            onFinished: {
                index = (index + 1) % items.count
            }
        )
        .frame(width: 220, height: 220)
    }
}
```

## UIKit

Import the package:

```swift
import UIKit
import DZAnimatedImageKit
```

### Create and add `DZAnimatedImageUIView`

```swift
final class DemoViewController: UIViewController {
    private let animatedView = DZAnimatedImageUIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        animatedView.frame = CGRect(x: 40, y: 140, width: 220, height: 220)
        animatedView.repeatMode = .infinite
        animatedView.willShowProgress = true
        view.addSubview(animatedView)

        animatedView.aniImage = AnimatedImage(url: URL(string: "https://example.com/demo.gif")!)
    }
}
```

### Load a local animated image

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### Delegate callbacks

```swift
final class DemoViewController: UIViewController, DZAnimatedImageUIViewDelegate {
    private let animatedView = DZAnimatedImageUIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        animatedView.delegate = self
    }

    func animatedImageView(_ imageView: DZAnimatedImageUIView, didPlayAnimationLoops count: UInt) {
        print("loop: \(count)")
    }

    func animatedImageViewFinished(_ imageView: DZAnimatedImageUIView) {
        print("animation finished")
    }
}
```

### Stop and reset

```swift
animatedView.stopAnimating()
animatedView.reset()
```

## Notes

- `AnimatedImage(url:)` loads remote resources
- `AnimatedImage(path:)` loads a local file path
- SwiftUI callbacks:
  - `onLoop`: called after each completed animation loop
  - `onFinished`: called when playback reaches the end in `.once` or `.finite(n)`
  - `.infinite` does not trigger `onFinished`
- `repeatMode` supports:
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` controls how many frames are prepared ahead

## Manual Testing

If you are working inside this repository, use:

- [`../ManualTestApp/ManualTestApp.xcodeproj`](../ManualTestApp/ManualTestApp.xcodeproj)

That app is connected to this package through local Swift Package Manager for quick verification.
