# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

- **Name**: ClipRecall — a macOS clipboard history manager: multi-format recording (text / rich text / images / files / URLs / code / colors), instant recall & paste, AI enhancements (summarize / translate / polish / semantic search, etc.), E2EE cloud sync
- **Business model**: local features are open source & free; cloud sync + built-in AI credits are subscription-based (Free / Pro / Pro+ tiers, Mac App Store first, Paddle later)
- **Milestones**: M1 local MVP → M2 AI → M3 monetization → M4 release (see docs/project-plan.md)

## Key Design Decisions (details in docs/architecture.md)

- **Tech stack**: Swift 6 + SwiftUI (macOS 14+); core logic lives in ClipRecallCore (SPM library, zero UI dependency, keeping the door open for cross-platform); GRDB (SQLite + FTS5); server: Vapor + PostgreSQL (pgvector) + MinIO
- **Data model**: Clip (metadata) + Format bundle (mirrors the system pasteboard's multiple representations); file entries store references, never copies; URL / code / color are derived types
- **E2EE**: master key MK double-wrapped (password KEK + recovery key; recovery key only used when the password is forgotten); per-item DEK + AES-256-GCM; dumb server storage; LWW sync; changing the password moves nothing, forgetting it clears cloud & re-uploads
- **AI**: unified OpenAI-compatible protocol; dual channels — BYOK (free tier) and built-in credits (Pro); Ollama / vLLM auto-detection; on-device Vision OCR + NLEmbedding semantic search
- **Open/closed isolation (hard rule)**: the client is 100% open source; closed code (server + configs) lives only in `closed/` (ignored by .gitignore, its own private git repo); open-source code must never import closed-source code

## Development Workflow

- **Task granularity**: develop one sub-task (T-number) at a time from docs/project-plan.md; after each one, run the corresponding manual tests (TC numbers) in docs/manual-test-checklist.md
- **The user is not familiar with macOS/Swift development**: when carrying out their requests, explain in plain language what is being done and why it matters — do not assume knowledge of Swift, Xcode, or system frameworks; when discussing technical options, give the background before the conclusion
- **Project files**: never hand-edit project.pbxproj; the app project is generated from project.yml via XcodeGen (re-run `xcodegen generate` after adding new App files); the core library is a plain SPM package
- **Git workflow (project convention, overrides parts of the user's global preferences; the user explicitly confirmed: main / dev have no branch protection)**:
  1. small changes are committed and pushed directly to the `dev` branch; large changes or feature work open a new branch;
  2. `git pull` before making changes; confirm the current branch before committing;
  3. when new file types appear, consider whether .gitignore needs updating;
  4. `main` is the release branch — do not push to it directly
- **Coding process**: follow the user's global preferences — present the implementation approach and get approval before writing code; functions suitable for unit testing must have unit tests
- **Testing**: after every task, check docs/manual-test-checklist.md to decide whether the user needs to do manual testing, and review whether the checklist entries themselves are reasonable

## Repository Status

- Stages 0 and 1 are complete (foundation + local engine); docs/ contains the architecture, the task plan and the manual test checklist in both English and Chinese
- Current branch follows the actual git state; build with `xcodegen generate` + Xcode, tests with `swift test --package-path ClipRecallCore`
