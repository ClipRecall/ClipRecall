# ClipRecall

> A privacy-first clipboard history manager for macOS — record everything you copy, recall it instantly, with AI on the roadmap.

[中文文档](README.zh-CN.md)

## What is ClipRecall?

ClipRecall watches your clipboard and keeps a searchable history of everything you copy: plain text, rich text (HTML/RTF), images, files, URLs, code and colors. Open the menu bar panel, click an entry, press ⌘V — done.

It is built **local-first**: everything is stored in a local SQLite database, no account required, and your history survives restarts. Privacy is a first-class feature: password managers can be excluded from recording, and sensitive content (card numbers, API keys) is automatically masked in the list while the full content is preserved for recall.

## Features (implemented)

- **Multi-format capture** — text, rich text (HTML/RTF), images (PNG/TIFF with dimensions), file references (name/size preserved without copying the file)
- **Smart type detection** — URLs (with favicons), code languages (Swift / Python / JavaScript), colors (hex with swatch preview), emails and dates
- **Dedup & merge** — copying the same content refreshes the entry instead of duplicating it; chunked copies are merged into one
- **Privacy guardrails**
  - App exclusion list (password managers by default) — copies from excluded apps are never recorded
  - Sensitive-content masking — card numbers / API keys are masked in the list (ratio and position configurable in the future); the full content is always preserved for recall
  - Pause/resume recording with one click
- **Persistence** — SQLite-backed history with automatic retention policy (2000 entries / 30 days by default, pinned entries exempt)
- **Menu bar panel & recall** — keyboard-first navigation (arrows to select, Enter to recall, Esc to close), global hotkey, direct paste (Shift+Enter, optional), paste-as-plain-text mode, pin / delete / clear / multi-select merge
- **Settings window** — retention policy, app exclusion list, masking ratio & position, paste-mode toggles, hotkey recorder, launch at login
- **Full-text search** — Chinese & English keywords (case-insensitive, partial-word matching) with type / source / time filters
- **Image OCR** — screenshot text is recognized automatically and becomes searchable (on-device)
- **Local semantic search** — automatic semantic fallback when keywords miss (offline)

## Development progress

| Stage | Status |
|---|---|
| Stage 0 — Foundation (project structure, data model, database, security) | ✅ Done |
| Stage 1 — Local engine (capture, detection, dedup, persistence, privacy) | ✅ Done |
| Stage 2 — UI & recall (polished panel, keyboard-first, direct paste, hotkey) | ✅ Done |
| Stage 3 — Search (full-text, OCR, semantic) | ✅ Done |
| Stage 4 — AI (BYOK providers, local models, actions) | 🚧 Planned |
| Stage 5–6 — Cloud & monetization (E2EE sync, subscriptions, AI credits) | 🚧 Planned |
| Stage 7 — Release (TestFlight, App Store, polish) | 🚧 Planned |

See [docs/project-plan.md](docs/project-plan.md) for the detailed task plan and [docs/architecture.md](docs/architecture.md) for the technical architecture.

## Roadmap (promised features)

- **AI (free tier via BYOK)** — bring your own API key for any OpenAI-compatible provider (OpenAI, DeepSeek, Moonshot, local Ollama/vLLM and more): summarize, translate, polish, explain code
- **ClipRecall Pro (subscription)** — end-to-end encrypted cloud sync across devices, built-in AI credits, web access
- **Later** — iOS/iPadOS, Paddle billing, share links, team spaces, self-hosted server

## Building from source

Requirements: macOS 14+, Xcode (16 or later), [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
xcodegen generate          # generates ClipRecall.xcodeproj from project.yml
open ClipRecall.xcodeproj  # ⌘R to run
```

Run the test suite:

```bash
swift test --package-path ClipRecallCore
```

## Repository layout

```
App/               macOS app (SwiftUI, menu bar)
ClipRecallCore/    core library (SPM, zero UI dependency)
docs/              architecture, project plan, manual test checklist
closed/            ❌ NOT in this repository (private server code)
```

## License

[MIT](LICENSE). Logo and branding are reserved.

---

*Early development — cloud sync and AI features are planned, not yet implemented. The `closed/` directory referenced in the documentation is the private server codebase and is intentionally not part of this public repository.*
