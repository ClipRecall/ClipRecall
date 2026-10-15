# ClipRecall

> 隐私优先的 macOS 剪贴板历史管理工具——记录你复制的一切，随时极速召回，AI 能力在路上。

[English](README.md)

## ClipRecall 是什么？

ClipRecall 监听你的剪贴板，把复制的所有内容保存成可搜索的历史：纯文本、富文本（HTML/RTF）、图片、文件、网址、代码和颜色。打开菜单栏面板，点击条目，按 ⌘V——完成。

**本地优先**：所有数据存储在本地 SQLite 数据库，无需账号，重启后历史仍在。隐私是一等公民：密码管理器可以排除在记录之外；敏感内容（卡号、API 密钥）在列表中自动打码展示，而完整内容始终保留、可随时召回粘贴。

## 已实现的功能

- **多格式采集**——文本、富文本（HTML/RTF）、图片（PNG/TIFF 含尺寸信息）、文件引用（记录名称/大小，不复制文件本体）
- **智能类型识别**——网址（含网站图标）、代码语言（Swift / Python / JavaScript）、颜色（色块预览）、邮箱和日期
- **去重与合并**——复制相同内容会刷新条目而非重复；分片复制自动合并为一条
- **隐私护栏**
  - 排除 App 名单（默认含密码管理器）——被排除 App 的复制永不记录
  - 敏感内容打码——卡号 / API 密钥在列表中打码展示（比例与位置将来可配置）；完整内容始终保留供召回
  - 一键暂停 / 恢复记录
- **持久化**——SQLite 历史 + 自动保留策略（默认 2000 条 / 30 天，固定条目豁免）
- **菜单栏应用**——轻量界面、图片缩略图、统一类型标注、辅助功能权限引导（为即将到来的"直接粘贴"做准备）

## 开发进度

| 阶段 | 状态 |
|---|---|
| 阶段 0 — 地基（工程结构、数据模型、数据库、安全外壳） | ✅ 完成 |
| 阶段 1 — 本地引擎（采集、识别、去重、持久化、隐私） | ✅ 完成 |
| 阶段 2 — 界面与召回（正式面板、纯键盘操作、直接粘贴、快捷键） | 🚧 规划中 |
| 阶段 3 — 搜索（全文、OCR、语义） | 🚧 规划中 |
| 阶段 4 — AI（BYOK 供应商、本地模型、动作） | 🚧 规划中 |
| 阶段 5–6 — 云与变现（E2EE 同步、订阅、AI 积分） | 🚧 规划中 |
| 阶段 7 — 发布（TestFlight、App Store、打磨） | 🚧 规划中 |

详细任务计划见 [docs/project-plan.zh-CN.md](docs/project-plan.zh-CN.md)，技术架构见 [docs/architecture.zh-CN.md](docs/architecture.zh-CN.md)。

## 路线图（承诺功能）

- **界面与交互**——正式面板、纯键盘操作、全局快捷键、面板弹出位置、UI 美化与动效
- **召回升级**——直接粘贴（Shift+回车，带开关设置）、纯文本粘贴模式、固定 / 删除 / 编辑条目、多选合并
- **设置页**——保留策略、排除名单、快捷键、敏感打码选项（比例 + 前 / 中 / 后位置）、直接粘贴开关
- **AI（免费档 BYOK）**——自带 API Key 接入任意 OpenAI 兼容供应商（OpenAI、DeepSeek、Moonshot、本地 Ollama / vLLM 等）：总结、翻译、润色、解释代码
- **搜索升级**——全文搜索、图片 OCR、本地语义搜索
- **ClipRecall Pro（订阅）**——端到端加密云同步、内置 AI 额度、网页版访问
- **更远期**——iOS / iPadOS、Paddle 双渠道、分享链接、团队空间、服务端自部署

## 从源码构建

要求：macOS 14+、Xcode（16 或更高）、[XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
xcodegen generate          # 由 project.yml 生成 ClipRecall.xcodeproj
open ClipRecall.xcodeproj  # ⌘R 运行
```

运行测试：

```bash
swift test --package-path ClipRecallCore
```

## 仓库结构

```
App/               macOS 应用（SwiftUI，菜单栏）
ClipRecallCore/    核心库（SPM，零 UI 依赖）
docs/              架构、项目计划、人工测试清单
closed/            ❌ 不在本仓库（私有服务端代码）
```

## 许可证

[MIT](LICENSE)。Logo 与品牌保留。

---

*早期开发阶段——云同步与 AI 功能在规划中、尚未实现。文档中提到的 `closed/` 目录是私有服务端代码库，刻意不包含在本公开仓库中。*
