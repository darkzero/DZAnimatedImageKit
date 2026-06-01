# DZAnimatedImageKit

SwiftUI と UIKit の両方に対応した iOS 向けアニメーション画像ライブラリです。

このリポジトリには現在、次の 2 つが含まれています。

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit)：Swift Package 本体
- [`ManualTestApp/`](./ManualTestApp)：表示確認用のローカル手動テスト App

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

[LICENSE](./LICENSE) を参照してください。
