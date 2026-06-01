# DZAnimatedImageKit

一个用于 iOS 的动图展示库（`GIF/APNG`），同时支持 SwiftUI 和 UIKit。

## 环境要求

- iOS 15+
- Swift 6.1+

## 安装

通过 Swift Package Manager 添加 `DZAnimatedImageKit`。

在 Xcode 中：

1. `File` -> `Add Package Dependencies...`
2. 选择仓库地址或本地包路径
3. 添加产品：`DZAnimatedImageKit`

## SwiftUI

导入：

```swift
import SwiftUI
import DZAnimatedImageKit
```

### 加载远程动图

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

### 加载本地动图

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

### 自定义进度视图

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

### 循环和结束回调

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

### 5. 监听已解码缓冲内存（SwiftUI）

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

导入：

```swift
import UIKit
import DZAnimatedImageKit
```

### 创建并添加 `DZAnimatedImageUIView`

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

### 加载本地动图

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### 代理回调

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

### 停止和重置

```swift
animatedView.stopAnimating()
animatedView.reset()
```

## 说明

- `AnimatedImage(url:)`：加载远程资源
- `AnimatedImage(path:)`：加载本地文件路径
- SwiftUI 回调：
  - `onLoop`：每次动画循环完成后触发。
  - `onFinished`：在 `.once` 或 `.finite(n)` 播放完成后触发。
  - `.infinite` 不会触发 `onFinished`。
  - `onDecodedBufferChanged`：回调当前动画器已解码缓冲帧的内存字节数。
- `repeatMode` 支持：
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` 用于控制预加载帧数量

## 手工测试

如果你在这个仓库里开发，建议直接使用：

- [`../ManualTestApp/ManualTestApp.xcodeproj`](../ManualTestApp/ManualTestApp.xcodeproj)

这个测试 App 已经通过本地 Swift Package Manager 连接到当前包，方便快速验证修改效果。
