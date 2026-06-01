# DZAnimatedImageKit

SwiftUI と UIKit の両方に対応した iOS 向けアニメーション画像ライブラリ（`GIF/APNG`）です。

## 動作要件

- iOS 15+
- Swift 6.1+

## インストール

Swift Package Manager で `DZAnimatedImageKit` を追加します。

Xcode では次の手順です。

1. `File` -> `Add Package Dependencies...`
2. リポジトリ URL またはローカルパッケージのパスを選択
3. プロダクト `DZAnimatedImageKit` を追加

## SwiftUI

インポート：

```swift
import SwiftUI
import DZAnimatedImageKit
```

### リモートのアニメーション画像を表示

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

### ローカルのアニメーション画像を表示

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

### 進捗表示をカスタマイズ

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

### ループと完了コールバック

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

### 5. デコード済みバッファメモリを監視（SwiftUI）

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

インポート：

```swift
import UIKit
import DZAnimatedImageKit
```

### `DZAnimatedImageUIView` を作成して配置

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

### ローカル画像を読み込む

```swift
if let path = Bundle.main.path(forResource: "sample", ofType: "gif") {
    animatedView.aniImage = AnimatedImage(path: path)
}
```

### デリゲートコールバック

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

### 停止とリセット

```swift
animatedView.stopAnimating()
animatedView.reset()
```

## 補足

- `AnimatedImage(url:)`：リモートリソースを読み込みます
- `AnimatedImage(path:)`：ローカルファイルパスを読み込みます
- SwiftUI コールバック：
  - `onLoop`：各ループ完了後に呼ばれます
  - `onFinished`：`.once` または `.finite(n)` の再生完了時に呼ばれます
  - `.infinite` では `onFinished` は呼ばれません
- `repeatMode` は以下をサポートします：
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` は先読みフレーム数を制御します

## 手動テスト

このリポジトリ内で開発する場合は、次を利用してください。

- [`../ManualTestApp/ManualTestApp.xcodeproj`](../ManualTestApp/ManualTestApp.xcodeproj)

このテスト App はローカル Swift Package Manager で現在のパッケージに接続されており、変更確認に便利です。
