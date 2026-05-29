# DZAnimatedImageKit 任务计划（P0 / P1 / P2）

> 版本基线：v1.0.0（iOS-only）
> 目标：先稳基础，再强化差异化能力，再补齐可观测与测试体系。

## 计划总览

- P0（稳定性与工程清理）：1~2 周
- P1（核心能力增强）：2~4 周
- P2（可观测与质量体系）：4~8 周

---

## P0：稳定性优先（必须先做）

## P0-1 下载链路语义补齐

- 目标：统一下载成功/失败/取消语义，避免线上偶发停播和状态不一致。
- 任务：
  - 完成 `SourceDownloader.downloadImageAsync` 中 `successFile` 分支。
  - 统一 `DownloadEvent` 的结束行为（成功完成、失败终止、取消终止）。
  - 明确取消后是否触发失败回调，并在代码注释和 README 中写清楚。
- 涉及文件：
  - `DZAnimatedImageKit/Sources/DZAnimatedImageKit/Downloader/SourceDownloader.swift`
  - `DZAnimatedImageKit/Sources/DZAnimatedImageKit/Downloader/SessionDataTask.swift`
- 验收标准（DoD）：
  - `successData/successFile/failure/cancel` 均有单测覆盖。
  - 同 URL 多消费者场景下，取消不误伤其他消费者。

## P0-2 工程结构清理

- 目标：减少后续维护噪音。
- 任务：
  - 清理空文件 `SessionDownloadTask.swift`（删除或补完整实现）。
  - 清理仓库中的 `.DS_Store` 和无效占位文件（例如空 `.swift`）。
  - 更新 `.gitignore`，防止重复提交无关文件。
- 涉及文件：
  - `DZAnimatedImageKit/Sources/DZAnimatedImageKit/Downloader/SessionDownloadTask.swift`
  - `DZAnimatedImageKit/Sources/DZAnimatedImageKit/.swift`
- 验收标准（DoD）：
  - 仓库无无意义文件。
  - CI 通过且无新增 warning。

## P0-3 文档语义对齐

- 目标：API 行为可预期，减少调用方误用。
- 任务：
  - 在 README（中/英/日）补充取消语义和完成回调语义。
  - 明确 `.once/.finite/.infinite` 在回调触发时机上的差异。
- 验收标准（DoD）：
  - README 三语一致。
  - 示例代码与真实行为一致。

---

## P1：能力增强（形成差异化）

## P1-1 Sequence / Playlist 高阶 API

- 目标：把“回调可编排”升级为“开箱可编排”。
- 任务：
  - 设计 `Sequence` 数据结构（项、切换规则、循环策略）。
  - 提供 SwiftUI 包装（例如 `DZAnimatedSequenceView`）。
  - UIKit 提供对应控制器/协调器接口。
- 验收标准（DoD）：
  - 支持常见场景：播完切下一段、循环 N 次再切换、条件切换。
  - 提供最小可运行 demo（ManualTestApp）。

## P1-2 Auto Preload 模式

- 目标：降低 preload 手工调参成本。
- 任务：
  - 新增策略枚举：`manual(Int)` / `auto`。
  - `auto` 根据帧尺寸、当前缓冲、视图大小等动态计算窗口。
  - 保留 hard cap，确保峰值内存可控。
- 验收标准（DoD）：
  - 与 `manual` 对比有可量化收益（内存峰值或掉帧率改善）。
  - 默认配置下无需手工调参即可稳定运行。

## P1-3 ManualTestApp 强化

- 目标：把手测工具变成真实调参面板。
- 任务：
  - 增加 `preload mode` 切换。
  - 增加 sequence 示例页。
  - 保留并增强内存指标显示。
- 验收标准（DoD）：
  - 一屏可验证核心能力（加载、编排、内存变化）。

---

## P2：可观测与质量体系

## P2-1 播放指标可观测化

- 目标：把“体感问题”变“可诊断问题”。
- 任务：
  - 暴露指标：`decodedBufferBytes`、`effectivePreloadCount`、估算 FPS、dropped frames。
  - 增加 debug 日志/回调出口。
- 验收标准（DoD）：
  - 指标可在 SwiftUI/UIKit 两端读取。
  - 能用于回归对比（优化前后）。

## P2-2 测试体系升级

- 目标：防止重构回归。
- 任务：
  - 增加状态机测试：`once/finite/infinite` 回调触发时序。
  - 增加取消语义测试：同 URL 多消费者。
  - 增加 preload 边界测试：`frameCount <= preloadCount`。
- 验收标准（DoD）：
  - 测试覆盖关键状态流。
  - CI 中加入测试任务（iOS 目标）。

## P2-3 发布流程标准化

- 目标：降低后续 release 的人为风险。
- 任务：
  - 增加 release checklist（tag、notes、smoke test）。
  - 固化 CI 产物检查。
- 验收标准（DoD）：
  - 每次发布按 checklist 执行，无遗漏项。

---

## 依赖关系

- P1 依赖 P0（尤其下载语义和结构清理）。
- P2 可分段并行，但测试升级建议与 P1 同步进行。

---

## 建议里程碑

- M1（完成 P0）：稳定版本 `v1.0.x`
- M2（完成 P1 核心）：能力版本 `v1.1.0`
- M3（完成 P2）：可观测/质量版本 `v1.2.0`

---

## 当前执行建议（下一步）

1. 先开 3 个 P0 issue：下载语义、结构清理、文档对齐。
2. 每个 issue 都加 DoD 与测试清单。
3. P0 全绿后再开 P1 的 Sequence 设计稿。
