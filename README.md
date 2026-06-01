# DZAnimatedImageKit

Animated image library for iOS with both SwiftUI and UIKit APIs.

This repository now contains two parts:

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit): the Swift Package
- [`ManualTestApp/`](./ManualTestApp): the local manual test app used to verify rendering behavior

## Highlights

- Provides consistent callback semantics across SwiftUI and UIKit (`onLoop` / `onFinished`)
- Supports animation flow orchestration, such as switching to the next animated image after completion
- Works as both an image player and a foundation for business-level animation sequencing

## Roadmap

- Add a lightweight `Playlist/Sequence` API
- Clarify callback timing and threading guarantees
- Add auto-`preload` with memory-pressure-aware adaptation
- Improve playback observability (`buffer`, `FPS`, `dropped frames`)

## Requirements

- iOS 15+
- Swift 6.1+
- Xcode 26+

## Quick Start

### Use the package in your own app

Add the local or remote Swift Package and import:

```swift
import DZAnimatedImageKit
```

Detailed package usage lives here:

- [English package docs](./DZAnimatedImageKit/README.md)
- [简体中文包文档](./DZAnimatedImageKit/README_CN.md)
- [日本語パッケージ文書](./DZAnimatedImageKit/README_JP.md)

### Run the manual test app

Open:

- [`ManualTestApp/ManualTestApp.xcodeproj`](./ManualTestApp/ManualTestApp.xcodeproj)

The test app is wired to the local package through Swift Package Manager, so changes in [`DZAnimatedImageKit/`](./DZAnimatedImageKit) can be previewed and validated immediately.

## Repository Structure

```text
DZAnimatedImageKit/
├── DZAnimatedImageKit/   # Swift Package source, tests, package README files
├── ManualTestApp/        # Manual verification app
├── README.md
├── README_CN.md
└── README_JP.md
```

## Development Notes

- Package root: [`DZAnimatedImageKit/Package.swift`](./DZAnimatedImageKit/Package.swift)
- Manual test entry view: [`ManualTestApp/ManualTestApp/ContentView.swift`](./ManualTestApp/ManualTestApp/ContentView.swift)
- The manual test app includes SwiftUI and UIKit test surfaces, local GIF/APNG generation, and a remote URL test section.

## License

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
