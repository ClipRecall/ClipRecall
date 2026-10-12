# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概况

- **项目名**：ClipRecall —— macOS 剪贴板历史管理工具：多格式记录（文本 / 富文本 / 图片 / 文件 / URL / 代码 / 颜色）、极速召回粘贴、AI 增强（总结 / 翻译 / 润色 / 语义搜索等）、E2EE 云同步
- **商业模式**：本地功能开源免费；云同步 + AI 内置额度订阅收费（Free / Pro / Pro+ 三档，Mac App Store 首发，后期加 Paddle）
- **里程碑**：M1 本地 MVP → M2 AI 能力 → M3 变现闭环 → M4 发布（详见 docs/project-plan.md）

## 关键设计决策（详情见 docs/architecture.md）

- **技术栈**：Swift 6 + SwiftUI（最低 macOS 14）；核心逻辑在 ClipRecallCore（SPM 库，零 UI 依赖，为跨平台留路）；GRDB（SQLite + FTS5）；服务端 Vapor + PostgreSQL(pgvector) + MinIO
- **数据模型**：Clip（元数据）+ Format 格式包（镜像系统剪贴板多表示）；文件条目存引用不存副本；URL / 代码 / 颜色为派生类型
- **E2EE**：主密钥 MK 双包裹（密码 KEK + 恢复密钥，恢复密钥仅忘密码时用）；每条目 DEK + AES-256-GCM；服务端哑存储；LWW 同步；改密码零移动、忘密码清云重传
- **AI**：OpenAI 兼容协议统一接入；BYOK（免费档）与内置额度（Pro 积分制）双通道；Ollama / vLLM 自动检测；Vision 本机 OCR + NLEmbedding 本机语义搜索
- **开源/闭源隔离（硬性规则）**：客户端 100% 开源；闭源（服务端 + 配置）只允许放在 `closed/`（被 .gitignore 忽略、内部独立私有 git）；开源代码禁止 import 闭源代码

## 开发工作流

- **任务粒度**：按 docs/project-plan.md 的子任务（T 编号）逐个开发，一次只做一个子任务；完成后执行 docs/manual-test-checklist.md 对应的人工测试（TC 编号）
- **用户不懂 Mac/Swift 开发**：执行用户要求时，尽量用通俗语言解释当前在做什么、这个功能有什么用——不默认用户了解 Swift、Xcode、系统框架等概念；讨论技术方案时先讲清背景再给结论
- **工程文件**：避免手改 project.pbxproj；App 工程用 Xcode 16+ 同步文件夹（或 Xcode 27.2+ JSON 格式 .xcproj），核心库走 SPM，工程结构变更交给 Xcode 或生成器
- **Git 工作流（本项目约定，用户明确：main / dev 未开保护，直接推送到 dev）**：
  1. 日常开发**直接提交并推送到 `dev` 分支**，无需功能分支合并流程；需要隔离的大功能可临时开功能分支；
  2. 改动前先 `git pull`；commit 前先确认当前分支；
  3. 出现新文件类型时，判断是否需要添加 .gitignore；
  4. `main` 保持发布用途，不直接推送
- **编码流程**：遵守用户全局偏好——先给实现思路经批准后再写代码；适合单元测试的函数必须编写单元测试

## 仓库现状

- 代码尚未开工（阶段 0 进行中）；docs/ 已含完整技术架构、项目计划、人工测试清单
- 构建 / 测试命令待工程建立后补充；当前分支以实际 git 状态为准
