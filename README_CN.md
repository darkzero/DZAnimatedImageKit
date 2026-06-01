# DZAnimatedImageKit

一个支持 SwiftUI 和 UIKit 的 iOS 动图展示库。

这个仓库现在包含两部分：

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit)：Swift Package 本体
- [`ManualTestApp/`](./ManualTestApp)：用于手工验证显示效果的本地测试 App

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

见 [LICENSE](./LICENSE)。
