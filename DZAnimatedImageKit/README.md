# DZAnimatedImageKit

Animated image view library for iOS (`GIF/APNG`), with both SwiftUI and UIKit APIs.

## Requirements

- iOS 15+
- Swift 6.1+

## Installation (Swift Package Manager)

In Xcode:

1. `File` -> `Add Package Dependencies...`
2. Select your repository URL
3. Add product: `DZAnimatedImageKit`

---

# How to use

## SwiftUI

Import package:

```swift
import SwiftUI
import DZAnimatedImageKit
```

### 1. Load remote animated image

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

### 2. Load local animated image

```swift
import SwiftUI
import DZAnimatedImageKit

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

### 3. Custom progress overlay

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

### 4. Loop / finish callbacks (SwiftUI)

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

### 5. Observe decoded buffer memory (SwiftUI)

```swift
@State private var decodedBytes = 0

DZAnimatedImageView(
    animatedImage: AnimatedImage(url: URL(string: "https://example.com/demo.gif")!),
    preloadCount: 6,
    onDecodedBufferChanged: { bytes in
        decodedBytes = bytes
    }
)
```

## UIKit

Import package:

```swift
import UIKit
import DZAnimatedImageKit
```

### 1. Create and add `DZAnimatedImageUIView`

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

### 2. Load local animated image

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### 3. Delegate callbacks

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

### 4. Stop/reset

```swift
animatedView.stopAnimating()
animatedView.reset()
```

---

## Notes

- `AnimatedImage(url:)` for remote resources.
- `AnimatedImage(path:)` for local file path.
- SwiftUI callbacks:
  - `onLoop`: called after each completed animation loop.
  - `onFinished`: called when playback reaches the end in `.once` or `.finite(n)`.
  - `.infinite` never triggers `onFinished`.
  - `onDecodedBufferChanged`: reports decoded frame-buffer bytes used by the animator.
- `repeatMode` supports:
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` controls how many frames are prepared ahead.
- The effective preload window is capped internally:
  - `effectivePreload = min(preloadCount, maxPreloadCap, frameCount - 1)`
