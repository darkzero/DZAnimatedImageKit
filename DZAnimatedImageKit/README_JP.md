# DZAnimatedImageKit

iOS 向けのアニメーション画像表示ライブラリ（`GIF/APNG`）です。SwiftUI と UIKit の両方に対応しています。

## 動作要件

- iOS 15+
- Swift 6.1+

## インストール（Swift Package Manager）

Xcode で以下を実行します：

1. `File` -> `Add Package Dependencies...`
2. リポジトリ URL を指定
3. プロダクト `DZAnimatedImageKit` を追加

---

# How to use

## SwiftUI

インポート：

```swift
import SwiftUI
import DZAnimatedImageKit
```

### 1. リモートのアニメーション画像を表示

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

### 2. ローカルのアニメーション画像を表示

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

### 3. 進捗オーバーレイをカスタマイズ

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

### 4. ループ / 完了コールバック（SwiftUI）

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

インポート：

```swift
import UIKit
import DZAnimatedImageKit
```

### 1. `DZAnimatedImageUIView` を作成して配置

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

### 2. ローカル画像を読み込む

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### 3. デリゲートコールバック

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

### 4. 停止 / リセット

```swift
animatedView.stopAnimating()
animatedView.reset()
```

---

## 補足

- `AnimatedImage(url:)`：リモートリソースを読み込みます。
- `AnimatedImage(path:)`：ローカルファイルパスを読み込みます。
- SwiftUI コールバック：
  - `onLoop`：各ループの完了後に呼ばれます。
  - `onFinished`：`.once` または `.finite(n)` の再生完了時に呼ばれます。
  - `.infinite` では `onFinished` は呼ばれません。
- `repeatMode` は以下をサポート：
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` は先読みするフレーム数を制御します。
