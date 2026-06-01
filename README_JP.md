# DZAnimatedImageKit

SwiftUI と UIKit の両方に対応した iOS 向けアニメーション画像ライブラリです。

このリポジトリには現在、次の 2 つが含まれています。

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit)：Swift Package 本体
- [`ManualTestApp/`](./ManualTestApp)：表示確認用のローカル手動テスト App

## ハイライト

- SwiftUI / UIKit で一貫したコールバック（`onLoop` / `onFinished`）を提供
- 再生完了後に次のアニメーションへ切り替えるなど、シーケンス制御に対応
- 単なる表示コンポーネントではなく、業務ロジック向けのアニメーション編成基盤として利用可能

## 今後の計画

- 軽量な `Playlist/Sequence` API の追加
- コールバック発火タイミングとスレッド保証の明確化
- 自動 `preload` とメモリ圧力に応じた適応制御
- 再生メトリクスの可観測性強化（`buffer`、`FPS`、`dropped frames`）

## 動作要件

- iOS 15+
- Swift 6.1+
- Xcode 26+

## クイックスタート

### パッケージを自分のアプリに追加する

ローカルまたはリモートの Swift Package として追加し、次のようにインポートします。

```swift
import DZAnimatedImageKit
```

より詳しいパッケージの使い方はこちらです。

- [English package docs](./DZAnimatedImageKit/README.md)
- [简体中文包文档](./DZAnimatedImageKit/README_CN.md)
- [日本語パッケージ文書](./DZAnimatedImageKit/README_JP.md)

### 手動テスト App を起動する

次を開いてください。

- [`ManualTestApp/ManualTestApp.xcodeproj`](./ManualTestApp/ManualTestApp.xcodeproj)

このテスト App は [`DZAnimatedImageKit/`](./DZAnimatedImageKit) をローカル Swift Package として参照しているため、ライブラリ変更をすぐ確認できます。

## リポジトリ構成

```text
DZAnimatedImageKit/
├── DZAnimatedImageKit/   # Swift Package のソース、テスト、README
├── ManualTestApp/        # 手動確認用 App
├── README.md
├── README_CN.md
└── README_JP.md
```

## 開発メモ

- パッケージの入口: [`DZAnimatedImageKit/Package.swift`](./DZAnimatedImageKit/Package.swift)
- 手動テストのメインビュー: [`ManualTestApp/ManualTestApp/ContentView.swift`](./ManualTestApp/ManualTestApp/ContentView.swift)
- 手動テスト App には SwiftUI / UIKit の確認画面、ローカル GIF/APNG 生成、リモート URL テストが含まれます

## ライセンス

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
  - `onDecodedBufferChanged`：アニメーターが保持中のデコード済みバッファサイズ（bytes）を通知します。
- `repeatMode` は以下をサポート：
  - `.once`
  - `.finite(n)`
  - `.infinite`
- `preloadCount` は先読みするフレーム数を制御します。
- 実際の先読み数は内部上限で制限されます：
  - `effectivePreload = min(preloadCount, maxPreloadCap, frameCount - 1)`
