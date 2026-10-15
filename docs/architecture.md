# ClipRecall Technical Architecture

> This document describes the overall technical architecture of ClipRecall and serves as the basis for technical decisions across development stages. It evolves together with architecture decisions.
> Companion documents: [Project Plan](project-plan.md), [Manual Test Checklist](manual-test-checklist.md). Chinese version: [architecture.zh-CN.md](architecture.zh-CN.md).

## 1. Product Positioning & Architecture Goals

### 1.1 What the product is

ClipRecall is a macOS clipboard history manager: it records clipboard history (plain text, rich text, images, files and more), lets you recall any entry back to the clipboard instantly, and adds AI capabilities (summarize, translate, polish, semantic search, etc.) plus E2EE cloud sync.

Business model: core features are open source and free; cloud sync + built-in AI credits are subscription-based (Free / Pro / Pro+ tiers, Mac App Store first, Paddle later).

### 1.2 Why it is designed this way — four architecture principles

1. **Local-first**: the on-device database is the source of truth; the cloud is only an encrypted mirror. With no network, all local features (capture, recall, search, BYOK AI) remain fully functional.
2. **Core/UI separation**: all non-UI logic lives in `ClipRecallCore` (an SPM library); the UI layer (SwiftUI) only renders and interacts. This is the foundation for future iOS/iPadOS (and even Windows) ports — the cost of a port is limited to the UI.
3. **E2EE dumb storage**: the server stores only encrypted envelopes; keys never leave the device. Clipboard content (passwords, tokens, private messages) is more sensitive than notes — "a server breach leaks nothing readable" is the baseline, not a bonus.
4. **Open core**: the client is 100% open source (including the E2EE client — auditable equals trustworthy); the server is closed source. The free/paid boundary is naturally drawn by "local capability vs. cloud capability"; physical isolation rules are in section 9.

## 2. Technology Stack

### 2.1 Client (macOS)

| Area | Choice | Rationale |
|---|---|---|
| Language / UI | Swift 6 + SwiftUI, macOS 14+ | Best native experience and system integration (NSPasteboard, AX); Swift 6 strict concurrency |
| Database | GRDB.swift (SQLite + FTS5) | De-facto standard in the Swift ecosystem; DatabasePool concurrency |
| Crypto | CryptoKit (AES-256-GCM, hardware accelerated) + libsodium wrapper (Argon2id — not available in CryptoKit) | System-native first, fill only the gap |
| OCR | Vision (VNRecognizeTextRequest) | On-device, free, offline, Chinese + English |
| Semantic vectors | NaturalLanguage (NLEmbedding) | On-device free semantic search (free tier) |
| AI client | URLSession (OpenAI-compatible protocol, SSE streaming) | Zero third-party dependencies |
| DI | No third-party framework; constructor injection | Keep the dependency surface small for a solo project |

### 2.2 Server (self-hosted)

| Area | Choice | Rationale |
|---|---|---|
| Language / framework | Swift + Vapor 4 | Same language as the client — lowest maintenance for a solo full-stack developer |
| Database | PostgreSQL + pgvector | Relational data + vector search in one |
| Object storage | MinIO (S3-compatible) | Self-hosted blob storage |
| Reverse proxy / TLS | Caddy | Automatic HTTPS |
| Deployment | Docker Compose | Single-machine maintainable, portable later |

## 3. Client Architecture

### 3.1 Repository layout

```
ClipRecall/                      # open-source repository (git)
├── .gitignore                   # ignores closed/ and build artifacts
├── App/                         # open source: app UI (local features + BYOK, zero closed-source deps)
├── ClipRecallCore/              # open source: SPM library (zero UI dependency)
│   └── Sources/ClipRecallCore/
│       ├── Models/              # Clip, Format and other data models
│       ├── Clipboard/           # pasteboard monitoring and format capture
│       ├── Storage/             # GRDB repositories, blob file management, retention policy
│       ├── Search/              # FTS5, OCR indexing, semantic search
│       ├── AI/                  # provider abstraction, AI actions (BYOK)
│       ├── Sync/                # E2EE client (key management, envelopes, sync engine)
│       └── Diagnostics/         # structured logging
├── docs/                        # open source: architecture, plan, test checklist (EN + zh-CN)
└── closed/                      # ❌ ignored by .gitignore; its own private git repository
    ├── server/                  # Vapor server (auth/sync/gateway/billing/credits)
    ├── configs/                 # deployment config templates (real secrets live in .env)
    └── README.md                # closed-source boundary notes
```

### 3.2 Module responsibilities & data flow

```
NSPasteboard ──monitor──▶ ClipboardMonitor ──capture formats──▶ Storage (SQLite + files)
                                                                    │
                                                    ┌───────────────┼───────────────┐
                                                    ▼               ▼               ▼
                                              Search index     Sync engine      UI panel
                                              (FTS5/OCR/vectors)(E2EE envelopes)(list/keyboard/recall)
```

- **ClipboardMonitor**: polls `NSPasteboard.changeCount` (every 0.5s) and reads all representations on change;
- **Storage**: clip metadata goes into SQLite, large objects (images, long HTML) go to disk; applies dedup, merge and retention policies;
- **Search**: background queue builds indexes incrementally (FTS5 full-text + OCR text + semantic vectors);
- **Sync**: an independent background queue consuming storage changes; retries silently on network failures;
- **UI**: menu bar panel (MenuBarExtra), event-driven reads from storage.

### 3.3 Concurrency model

- Main actor for UI; GRDB DatabasePool separates reads and writes;
- One serial queue per background job family (capture, OCR, indexing, sync) to avoid racing on the same data;
- The capture path is latency-first (< 50ms to persist); OCR/sync heavy work is always asynchronous, throttled while the user is active.

## 4. Data Model

### 4.1 Core entity: Clip (clipboard entry)

```swift
struct Clip {
  let id: UUID            // client-generated; makes sync idempotent
  var capturedAt: Date
  var sourceApp: SourceApp?   // { bundleId, name } of the originating app
  var primaryType: ClipType   // text / richText / image / file / url / code / color
  var formats: [Format]       // the format bundle
  var textPreview: String?    // list display + search index
  var pinned: Bool
  var tags: [String]
  var groupId: UUID?
  var updatedAt: Date         // LWW conflict-resolution field
  var isDeleted: Bool         // tombstone (soft delete, sync-friendly)
}
```

### 4.2 Format: the format bundle (mirrors the system pasteboard's multiple representations)

A macOS pasteboard entry naturally carries several representations (plain text / HTML / PNG / file URLs); the data model mirrors this directly, and this is what makes "rich formats" work:

```swift
struct Format {
  let type: String      // UTI: public.utf8-plain-text / public.html / public.png / public.file-url …
  var payload: Payload  // .inline(Data) for small content; .file(path) for large content on disk
  var metadata: FormatMetadata  // image size / file count / code language …
  let version: Int      // format version, reserved for evolution
}
```

Design points:

- **File entries store references, never copies**: copying a 2GB file records only paths + name/icon/size metadata; if the file is later deleted, the preview still shows "file no longer exists";
- **URL / code / color are derived types**: detected from the plain text, reusing the same data without duplication;
- Large-object directory: `Application Support/ClipRecall/blobs/{uuid}`, thumbnails in a separate directory.

### 4.3 Database tables

| Table | Purpose |
|---|---|
| clips | main entries (pinned / tags / updatedAt / tombstone) |
| formats | format bundle (one Clip → many Formats) |
| fts | FTS5 virtual table (textPreview + OCR text) |
| sync_state | per-entry local sync status (pending / synced) |
| settings | user settings (retention policy, exclusion list, hotkey) |

### 4.4 Search indexing strategy

- **Full-text**: FTS5. Chinese search caveat: the default unicode61 tokenizer splits CJK into single characters — queries use phrase matching with a LIKE fallback (verified manually in task T3.1; switch to the trigram tokenizer if needed);
- **OCR text**: Vision results go into the FTS5 index so images are searchable;
- **Semantic vectors**: see 5.4.

## 5. AI Subsystem

### 5.1 Provider abstraction (OpenAI-compatible protocol)

All providers speak the OpenAI-compatible `/v1/chat/completions` protocol (SSE streaming):

- Built-in presets: OpenAI, DeepSeek, Moonshot, Ollama (`localhost:11434/v1`), vLLM (custom endpoint), Custom (any compatible service);
- BYOK: API keys live in the Keychain; the client talks directly to the provider, never through our server;
- Ollama auto-detection: ping `localhost:11434` at launch, show status and fetch installed models (`GET /api/tags`) into a dropdown; when not installed, show a guide link to the official install page (no bundled installer).

### 5.2 Actions & credit pricing

| Action | Description | Credits (Pro built-in) |
|---|---|---|
| Translate | short text | 1 |
| Polish / rewrite tone | single entry | 2 |
| Explain code | single entry | 2 |
| Summarize | long text | 5 |
| Semantic search | per query | 0.5 |

These numbers are directional and will be calibrated after beta usage measurement; credits are priced per action while the model is routed internally (small vs. large) to control cost.

### 5.3 Two AI channels

```
BYOK channel:        client ──direct──▶ the user's own provider (never touches our server)
Built-in credits:    client ──TLS──▶ our AI gateway ──▶ cloud model (transient, never persisted)
```

The built-in-credits channel is the explicit exception to the E2EE promise: content transiently passes through the server with user consent, is processed, and is discarded — never written to storage.

### 5.4 Semantic search architecture

- **Free tier**: NLEmbedding on-device vectors + local cosine search (zero cost, zero network; multilingual quality below cloud models);
- **Pro tier**: the client computes embeddings with a local CoreML model → vectors are uploaded as non-sensitive metadata → the server runs pgvector search → returns entry IDs → the client decrypts and displays. **The server stores vectors only, never plaintext** — compatible with E2EE.

### 5.5 Storing AI results

AI outputs (summaries, translations) are stored as a derived Format on the entry (type `ai-summary` etc., with provider/model metadata), copyable on their own, never overwriting the original content.

## 6. E2EE & Sync

### 6.1 Key hierarchy (double-wrapping model)

```
            randomly generated master key MK (32 bytes, encrypts all data)
                    ▲              ▲
    password-derived KEK_pw wraps   recovery-key-derived KEK_rk wraps
                    │              │
    server stores: wrapped_pw(MK) + wrapped_rk(MK) + auth hash
```

- **MK**: generated on the client, never leaves the device; the server only sees the two wrapped(MK) blobs;
- **KEK_pw**: Argon2id(password, salt) with OWASP-recommended parameters and a minimum-strength check at registration;
- **Recovery key**: a 32-character random string used only when the password is forgotten; it can be regenerated any time while logged in (re-wrap MK, old key invalidated) — no "shown once, lose it and you're doomed" pressure;
- **MK epoch (version number)**: incremented after a reset; other devices detect the change, ask for re-login and re-upload automatically (multi-device self-healing).

### 6.2 Per-entry encryption

- Each entry gets a random DEK (AES-256-GCM), wrapped by MK and stored with the entry; a single leaked entry reveals nothing else, and this design reserves the future "share link" feature (re-wrap one DEK for the recipient);
- Envelope format (what the server sees):

```
{ itemId, updatedAt, type, size, iv, wrappedDEK, ciphertext }
```

- The first four fields are the only plaintext metadata (required for incremental sync); content is strictly encrypted. This trade-off is disclosed in the privacy policy.

### 6.3 Sync protocol

- The server is dumb storage: encrypted envelopes + change records, with zero decryption capability;
- The client uploads local changes (create/update/delete tombstones) and pulls server changes;
- Conflict resolution: per-entry LWW (last-write-wins by updatedAt) — clipboard history is append-mostly, concurrent edits to the same entry are rare, LWW suffices; no full CRDT;
- Compress before encrypting; batched, resumable uploads; server retention (e.g., 90 days) is configured separately from the local retention policy.

### 6.4 Password lifecycle

| Scenario | Flow | Data impact |
|---|---|---|
| Normal login | password unwraps MK | none |
| Change password (old one known) | new KEK_pw re-wraps MK | zero data movement, instant |
| Forgot password + recovery key | recovery key unwraps MK → set new password → re-wrap | zero loss |
| Forgot password, no recovery key | clear cloud + full re-upload from devices (UUID idempotent) | only "cloud-only" data is lost; clear warning before reset |

- Web app (later feature): in-browser Argon2id (WASM) + WebCrypto decryption, keys never uploaded; the key design already accommodates it with zero rework.

### 6.5 Threat model & promises

- Server breach / intrusion: only encrypted envelopes and minimal metadata, no readable content;
- Weak passwords: Argon2id with high parameters + minimum-strength check at registration (same threat model as Bitwarden);
- Built-in AI credits: transient plaintext, transmitted only with consent, never persisted;
- Known trade-off (disclosed): the server can see entry id / timestamp / type / size metadata.

## 7. Server Architecture

### 7.1 Services

| Service | Responsibility |
|---|---|
| auth | register / login / tokens; Argon2id auth hash (isolated from the encryption KEK — neither derivable from the other) |
| sync | envelope upload / download / change pulling (dumb storage, cannot read content) |
| ai-gateway | subscription auth, model routing, relay (never persisted), usage reporting |
| billing | StoreKit 2 server verification, entitlement management, subscription events |
| credits | credit ledger (transactional debits, monthly rollover, top-up packs) |
| search | pgvector search (vectors only, no plaintext) |

### 7.2 Database tables

users / sessions / wrapped_keys / entitlements / subscriptions / credits_ledger / envelopes / vectors (pgvector)

### 7.3 Deployment & operations

- Docker Compose: Caddy (HTTPS) + Vapor + PostgreSQL (pgvector) + MinIO;
- Backups: logical PostgreSQL dumps + MinIO data mirroring (offsite / multiple copies);
- Monitoring: structured logs + a health-check endpoint (no heavyweight monitoring stack for a solo project).

### 7.4 API overview

| Endpoint | Purpose |
|---|---|
| POST /auth/register, /auth/login, /auth/refresh | account & tokens |
| POST /auth/password/change | change password (re-wrap MK) |
| POST /auth/password/recover | forgot password (recovery-key path / clear-cloud path) |
| GET /sync/changes?since= | pull incremental changes |
| POST /sync/items, GET /sync/items/{id} | envelope batch upload / download |
| POST /ai/chat | built-in-credits channel (streaming, never persisted) |
| POST /search/query | vector search |
| POST /billing/webhook/appstore | App Store Server Notifications V2 |

## 8. Subscription & Billing

| | Free | Pro | Pro+ |
|---|---|---|---|
| Price | 0 | $4/mo ($40/yr) | $8/mo ($80/yr) |
| E2EE cloud sync | ❌ | ✅ | ✅ |
| AI credits / month | 0 (BYOK unlimited) | 1000 | 3000 |
| Semantic search | local (NLEmbedding) | cloud vectors + local | same as Pro |
| Credit rollover | — | up to 1 month's allowance | same as Pro |

- Overage: hard stop + one-time "credit top-up packs" (IAP consumable) — no automatic recharge (avoids surprise bills and refund disputes);
- Entitlement sync: App Store Server API + Server Notifications V2 (subscribe / renew / refund / grace period); Paddle joins the same entitlement table later;
- The credit ledger lives server-side (shared across devices), with transactional, idempotent debits; heavy users naturally gravitate to BYOK, so built-in credits act as a soft cap.

## 9. Open/Closed Source Isolation

### 9.1 Boundary

- **Open source (public GitHub)**: the entire client — app UI, capture, storage, search, BYOK, the E2EE client, and the gateway call protocol. Open-sourcing the E2EE client is the foundation of trust (auditable); open-sourcing BYOK is the engine of word-of-mouth among power users;
- **Closed source (private repo)**: the entire server (auth / sync / gateway / billing / credits), deployment configs, and any future closed client modules (e.g., team features).

The key point about built-in credits: the client only "calls a public protocol" — authentication, model routing and credit debiting all happen server-side, so **the client can be 100% open source**. Closed code = server + configs.

### 9.2 Physical isolation rules (hard constraints)

1. **Directory isolation**: closed code lives only in `closed/`; `closed/` is fully ignored by the outer `.gitignore`;
2. **Version control**: `closed/` is its own private git repository (GitHub private or self-hosted), never referenced by the outer repository;
3. **Build isolation**: open-source code must never `import` closed code — a fresh clone of the public repository builds all local features + BYOK completely; the built-in-credits channel degrades gracefully without a subscription;
4. **Secret isolation**: `closed/configs/` holds templates only; real secrets/certificates live in `.env` (also ignored, never committed anywhere);
5. **Release check**: run a scan before making the repository public (task T7.5.3): no `closed/` references, no hardcoded credentials.

### 9.3 License & repositories

- Open-source part: MIT; logo and branding reserved;
- Closed part: private repository, not licensed;
- Release strategy: the directory layout supports splitting naturally — the outer repository can be made public as-is, no code relocation needed.

## 10. Performance & Security Baselines

- Panel opens < 100ms; capture-to-persist < 50ms;
- Polling interval 0.5s; background jobs (OCR/sync) throttle while the user is active;
- Images: original capped at 10MB + thumbnail; local history defaults to 2000 entries / 30 days (configurable);
- Security: passwords / MK / recovery key / API keys all in the Keychain; zero hardcoded credentials; notarization + Hardened Runtime; Argon2id auth hashes server-side.

---

> This document evolves with architecture decisions; any change should also check whether [Project Plan](project-plan.md) and [Manual Test Checklist](manual-test-checklist.md) are affected.
