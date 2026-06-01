# DZAnimatedImageKit

Animated image library for iOS with both SwiftUI and UIKit APIs.

This repository now contains two parts:

- [`DZAnimatedImageKit/`](./DZAnimatedImageKit): the Swift Package
- [`ManualTestApp/`](./ManualTestApp): the local manual test app used to verify rendering behavior

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

See [LICENSE](./LICENSE).
