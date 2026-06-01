# DZAnimatedImageKit

一个支持 SwiftUI 和 UIKit 的 iOS 动图展示库。

这个仓库现在包含两部分：

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit)：Swift Package 本体
- [`ManualTestApp/`](./ManualTestApp)：用于手工验证显示效果的本地测试 App

## 功能亮点

- 提供 SwiftUI 与 UIKit 一致的回调语义（`onLoop` / `onFinished`）
- 支持动画流程编排，例如当前动画结束后自动切换到下一段动图
- 不只是播放器，也可作为业务动画编排的基础组件

## 后续计划

- 提供轻量 `Playlist/Sequence` API
- 明确回调触发时机与线程保证
- 增加自动 `preload` 与内存压力自适应策略
- 增强播放可观测性（`buffer`、`FPS`、`dropped frames`）

## 环境要求

- iOS 15+
- Swift 6.1+
- Xcode 26+

## 快速开始

### 在你的项目里使用这个包

通过本地或远程 Swift Package Manager 引入后，直接导入：

```swift
import DZAnimatedImageKit
```

更完整的包使用说明在这里：

- [English package docs](./DZAnimatedImageKit/README.md)
- [简体中文包文档](./DZAnimatedImageKit/README_CN.md)
- [日本語パッケージ文書](./DZAnimatedImageKit/README_JP.md)

### 运行手工测试 App

直接打开：

- [`ManualTestApp/ManualTestApp.xcodeproj`](./ManualTestApp/ManualTestApp.xcodeproj)

这个测试 App 通过本地 Swift Package Manager 依赖到 [`DZAnimatedImageKit/`](./DZAnimatedImageKit)，所以你修改库代码后，可以立刻看到预览和运行结果。

## 仓库结构

```text
DZAnimatedImageKit/
├── DZAnimatedImageKit/   # Swift Package 源码、测试、包内 README
├── ManualTestApp/        # 手工测试 App
├── README.md
├── README_CN.md
└── README_JP.md
```

## 开发说明

- 包入口：[`DZAnimatedImageKit/Package.swift`](./DZAnimatedImageKit/Package.swift)
- 手工测试主入口：[`ManualTestApp/ManualTestApp/ContentView.swift`](./ManualTestApp/ManualTestApp/ContentView.swift)
- 手工测试 App 同时包含 SwiftUI 和 UIKit 测试页面，也包含本地 GIF/APNG 生成与远程 URL 测试

## 许可证

### 3. 自定义加载进度视图

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

### 4. 循环/结束回调（SwiftUI）

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

导入库：

```swift
import UIKit
import DZAnimatedImageKit
```

### 1. 创建并添加 `DZAnimatedImageUIView`

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

### 2. 加载本地动图

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### 3. 代理回调

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

### 4. 停止/重置

```swift
animatedView.stopAnimating()
animatedView.reset()
```

---

## 说明

- `AnimatedImage(url:)`：加载远程资源。
- `AnimatedImage(path:)`：加载本地文件路径。
- SwiftUI 回调：
  - `onLoop`：每次动画循环完成后触发。
  - `onFinished`：在 `.once` 或 `.finite(n)` 播放完成后触发。
  - `.infinite` 不会触发 `onFinished`。
  - `onDecodedBufferChanged`：回调当前动画器已解码缓冲帧的内存字节数。
- `repeatMode` 支持：
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` 用于控制预加载帧数量。
- 实际预加载窗口会受内部上限保护：
  - `effectivePreload = min(preloadCount, maxPreloadCap, frameCount - 1)`
