# ClipRecall Project Plan

> Companion documents: [Technical Architecture](architecture.md), [Manual Test Checklist](manual-test-checklist.md). Chinese version: [project-plan.zh-CN.md](project-plan.zh-CN.md).
> **How to use (AI-assisted development)**: each sub-task (e.g. T1.2.3) is one independent AI code-generation unit — implement exactly one sub-task at a time and run the corresponding manual tests (TC numbers) when done. **TC numbers map one-to-one to task groups: TC X.Y is the test for T X.Y** (see the manual test checklist). Sub-tasks are sized at "one function / one small component" to avoid generating too much code at once.
> **Progress tracking**: flip the ✅ column from `[ ]` to `[x]` when a sub-task is done, keeping pace with the manual test checklist.
> Solo development, no schedule pressure; stages are ordered by dependencies. **Server-side tasks in stages 5–6 live in `closed/` (private repo); client-side tasks belong to the open-source repository (boundaries in the architecture doc, section 9). Everything else is open source.**

## 1. Goals & Milestones (What)

**Product in one sentence**: a macOS clipboard history manager — multi-format recording, instant recall, AI enhancement, E2EE cloud sync (paid).

**Business model in one sentence**: local features are open source & free; cloud sync + built-in AI credits are subscription-based (Free / Pro / Pro+).

| Milestone | Contents | Stages | Exit criteria |
|---|---|---|---|
| M1 Local MVP | capture / recall / basic management | 0–2 | self-sufficient daily use, ready to open-source |
| M2 AI | search + BYOK + local models | 3–4 | AI capabilities complete, internal dogfooding |
| M3 Monetization | cloud sync + subscriptions + credits | 5–6 | monetization loop complete |
| M4 Post-release | polish, open source, growth | 7–8 | website live, public repository |

**MVP boundary (deliberately excluded)**: team spaces, web app, iOS/iPadOS, Paddle billing, share links — all deferred to stage 8 Backlog.

## 2. Stage 0: Project Bootstrap (M1)

**Goal**: stand up the project skeleton, data model and repository isolation — the stakes for everything that follows.

### T0.1 Git & repository isolation

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T0.1.1 | [x] | Branching strategy & .gitignore | feature-branch convention; .gitignore (closed/, build artifacts, .env, key files) | TC0.1 |
| T0.1.2 | [x] | closed/ directory & private repo | closed/ skeleton + inner `git init` + private remote; boundary README | TC0.1 |

### T0.2 Project skeleton

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T0.2.1 | [x] | Xcode project + MenuBarExtra shell | app launches, menu bar icon visible | — |
| T0.2.2 | [x] | ClipRecallCore SPM package | package structure + module directories (architecture 3.1) | — |
| T0.2.3 | [x] | Build configuration | macOS 14+, sandbox & Hardened Runtime reserved, entitlements | — |

### T0.3 Data model

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T0.3.1 | [x] | Enums & basic types | ClipType / SourceApp / FormatMetadata | — |
| T0.3.2 | [x] | Clip & Format models | model definitions + Payload enum (architecture 4) | — |
| T0.3.3 | [x] | GRDB integration | DatabasePool singleton + connection management | TC0.3 |
| T0.3.4 | [x] | migration v1 | clips / formats tables + migration framework | TC0.3 |
| T0.3.5 | [x] | Blob file manager | blobs directory read/write, path generation | — |

### T0.4 Logging

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T0.4.1 | [x] | Logger wrapper | module / level structured logging | TC0.4 |

### T0.5 Build automation (optional)

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T0.5.1 | [ ] | GitHub Actions build | CI for the public repository | — |

## 3. Stage 1: Local Engine (M1 core)

**Goal**: complete, reliable multi-format clipboard capture. **This stage is the foundation of the product and carries the heaviest manual-testing load. The debug UI (T1.3) is built first — from then on, each completed task group gets its TC tests immediately (build one, test one).**

### T1.1 Clipboard monitoring

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.1.1 | [x] | PasteboardMonitor polling | changeCount polling loop (0.5s) | TC1.1 |
| T1.1.2 | [x] | Lifecycle management | start / stop / wake-from-sleep recovery | TC1.1 |
| T1.1.3 | [x] | Change event interface | callback protocol for collectors | — |

### T1.2 Format capture

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.2.1 | [x] | Text capture | plain text + RTF / HTML multi-representation reads | TC1.2 |
| T1.2.2 | [x] | Image capture | PNG / TIFF reads + size metadata | TC1.2 |
| T1.2.3 | [x] | File capture | file-url parsing + Finder metadata (name / size) | TC1.2 |
| T1.2.4 | [x] | Rich-text preservation | web / Pages format-preserving path | TC1.2 |
| T1.2.5 | [x] | Payload write policy | inline vs. disk threshold | — |

### T1.3 Debug UI (visual entry point for manual testing, built first)

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.3.1 | [x] | Debug list | menu bar dropdown showing recent entries (max 50), click to copy back | TC1.3 |
| T1.3.2 | [x] | Debug menu items | pause/resume toggle, accessibility-permission entry | TC1.3 |

### T1.4 Type detection

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.4.1 | [x] | URL detection | URL recognition + domain extraction | TC1.4 |
| T1.4.2 | [x] | favicon fetching | async fetch + disk cache | TC1.4 |
| T1.4.3 | [x] | Code language detection | heuristics (Swift / Python / JS) | TC1.4 |
| T1.4.4 | [x] | Color / email / date detection | derived-type annotation | TC1.4 |

### T1.5 Dedup & merge

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.5.1 | [x] | Global dedup | fingerprint match against history; duplicates refresh to the top | TC1.5 |
| T1.5.2 | [x] | Chunk merge | time-window + prefix-continuation merge | TC1.5 |

### T1.6 Storage & retention

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.6.1 | [x] | ClipRepository | write / query / update APIs | TC1.6 |
| T1.6.2 | [x] | Thumbnail generation | image thumbnails + disk cache | TC1.2、TC2.1 |
| T1.6.3 | [x] | Retention executor | count / day limits + pinned exemption | TC1.6 |

### T1.7 Privacy filtering

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.7.1 | [x] | App exclusion list | list configuration + interception | TC1.7 |
| T1.7.2 | [x] | Sensitive-content detection | card / key regex detection with masking | TC1.7 |
| T1.7.3 | [x] | Manual pause | state toggle + menu bar entry | TC1.7 |

### T1.8 Permissions

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T1.8.1 | [x] | Accessibility permission | detection + guided jump to System Settings | TC1.8 |

## 4. Stage 2: UI & Recall (M1 core)

**Goal**: make the high-frequency path "instant + keyboard-first" — the experience core of the product.

### T2.1 Panel skeleton

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.1.1 | [x] | MenuBarExtra entry | icon + click to open | TC2.1 |
| T2.1.2 | [x] | List rendering | List virtualization + scroll performance | TC2.1 |
| T2.1.3 | [ ] | Entry row views ×6 | text / image / file / URL / code / color rows | TC2.1 |

### T2.2 Keyboard interaction

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.2.1 | [ ] | Focus management | keyboard focus without stealing the frontmost app's | TC2.2 |
| T2.2.2 | [ ] | Enter-to-copy & Esc | select → copy → close flow | TC2.2 |

### T2.3 Recall & paste

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.3.1 | [ ] | Pasteboard write-back | multi-format NSPasteboard write | TC2.3 |
| T2.3.2 | [ ] | Direct paste | AX frontmost-app + CGEvent Cmd+V | TC2.3 |
| T2.3.3 | [ ] | Plain-text paste mode | format-stripping write | TC2.3 |

### T2.4 Entry management

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.4.1 | [ ] | Pin / delete | actions + confirmation UI | TC2.4 |
| T2.4.2 | [ ] | Edit then copy | editor + overwrite write-back | TC2.4 |
| T2.4.3 | [ ] | Multi-select merge | multi-select + concatenated copy | TC2.4 |

### T2.5 Global hotkey

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.5.1 | [ ] | Hotkey registration | Carbon hotkey wrapper | TC2.5 |
| T2.5.2 | [ ] | Configuration & conflict detection | settings-page rebinding + conflict hints | TC2.5 |

### T2.6 Settings page

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T2.6.1 | [ ] | Settings storage | settings table + read/write | — |
| T2.6.2 | [ ] | Settings UI | retention / exclusion list / hotkey groups | TC2.6 |
| T2.6.3 | [ ] | Launch at login | SMAppService registration | TC2.6 |

> **T2.6.2 settings detail (do not forget)**: ① retention policy (count / days; reads & writes T1.6.3's RetentionPolicy); ② app exclusion list (reads & writes T1.7.1's AppExclusionList — the default password-manager list is editable here); ③ global hotkey; ④ sensitive-content masking (on/off + maskingRatio + front/middle/back maskPosition; reads & writes T1.7.2); ⑤ **direct-paste toggle (requested by the user on 2026-10-15): ON = clicking an entry pastes directly into the frontmost app; OFF = content goes to the clipboard and the user presses Cmd+V themselves (branches into T2.3.2 / T2.3.1)**; ⑥ when this page is done, remind the user to back-test the three TC1.6 items (limit 100 entries / keep 7 days / pinned exemption).

## 5. Stage 3: Search (M2)

**Goal**: the more history you have, the more you rely on search. Three layers, one at a time: full-text → OCR → semantic.

### T3.1 Full-text search

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T3.1.1 | [ ] | FTS5 table & writes | virtual table + synchronized writes | TC3.1 |
| T3.1.2 | [ ] | Query API | phrase matching + LIKE fallback (Chinese) | TC3.1 |
| T3.1.3 | [ ] | Index rebuild | full rebuild command | TC3.1 |

### T3.2 Filtering

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T3.2.1 | [ ] | Filter model | type / source / time combined queries | TC3.2 |
| T3.2.2 | [ ] | Search & filter UI | search box + filter bar | TC3.2 |

### T3.3 Image OCR

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T3.3.1 | [ ] | Vision wrapper | Chinese + English recognition requests | TC3.3 |
| T3.3.2 | [ ] | Incremental index queue | background queue + resume | TC3.3 |
| T3.3.3 | [ ] | OCR text into index | results written into FTS5 | TC3.3 |

### T3.4 Local semantic search

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T3.4.1 | [ ] | NLEmbedding vectorization | text → vectors | — |
| T3.4.2 | [ ] | Vector store & search | local vector storage + cosine search | TC3.4 |

## 6. Stage 4: AI (M2)

**Dependencies**: T4.1 needs only stage 1 (data); the action UI (T4.2) needs stage 2 (panel). **No backend dependency — can run in parallel with stage 3.**

### T4.1 Provider abstraction

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T4.1.1 | [ ] | Request models | ChatMessage / ChatRequest + OpenAI-compatible encoding | — |
| T4.1.2 | [ ] | SSE streaming parser | streaming response parsing | TC4.2 |
| T4.1.3 | [ ] | Provider presets | OpenAI / DeepSeek / Moonshot / Ollama / vLLM / Custom | TC4.1 |
| T4.1.4 | [ ] | Keychain storage | API key secure storage | TC4.1 |

### T4.2 AI actions

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T4.2.1 | [ ] | Actions & prompt templates | summarize / translate / polish / rewrite tone / explain code | TC4.2 |
| T4.2.2 | [ ] | Execution engine | input truncation / timeout / retry | TC4.2 |
| T4.2.3 | [ ] | Action UI | in-panel trigger + streaming display | TC4.2 |

### T4.3 Local model integration

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T4.3.1 | [ ] | Ollama detection | ping + status display | TC4.3 |
| T4.3.2 | [ ] | Model list | /api/tags dropdown | TC4.3 |
| T4.3.3 | [ ] | vLLM preset | custom endpoint configuration | TC4.3 |
| T4.3.4 | [ ] | Install guide | guide entry when not installed (link to Ollama's official page) | TC4.3 |

### T4.4 Result management

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T4.4.1 | [ ] | Derived Format storage | AI results persisted | TC4.4 |
| T4.4.2 | [ ] | Action history | history & traceability | TC4.4 |

### T4.5 Privacy interaction

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T4.5.1 | [ ] | Pre-send confirmation | confirmation dialog | TC4.5 |
| T4.5.2 | [ ] | Data-destination notice | BYOK / built-in-credits copy | TC4.5 |
| T4.5.3 | [ ] | Default-off switch | AI off by default, enabled manually in settings | TC4.5 |

## 7. Stage 5: Backend & E2EE Sync (M3)

**Note**: **server-side deliverables are developed inside `closed/` (private repo)**; **client-side deliverables (E2EE key system, per-entry encryption, sync engine) belong to the open-source repository** — an open E2EE client is the foundation of trust (architecture section 9). The "Location" column marks each task's home. Security over features — take it slow.

### T5.1 Server skeleton

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.1.1 | [ ] | Vapor project + Docker Compose | Caddy / PG (pgvector) / MinIO orchestration | closed | TC5.1 |
| T5.1.2 | [ ] | Configuration management | env vars / secret templates (.env never committed) | closed | — |
| T5.1.3 | [ ] | Backup & restore | backup scripts + restore drill | closed | TC5.1 |

### T5.2 Accounts

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.2.1 | [ ] | Users & register / login | users table + endpoints | closed | TC5.2 |
| T5.2.2 | [ ] | Argon2id auth hash | server-side hash (isolated from the encryption KEK) | closed | TC5.2 |
| T5.2.3 | [ ] | Session tokens | issue / verify / refresh | closed | TC5.2 |

### T5.3 E2EE key system

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.3.1 | [ ] | Argon2id client wrapper | KDF (libsodium) | open Core | — |
| T5.3.2 | [ ] | MK generation & double wrapping | MK / KEK_pw / KEK_rk + wrapped upload endpoint | open Core + closed | TC5.3 |
| T5.3.3 | [ ] | Change-password flow | re-wrap MK, zero data movement | open Core + closed | TC5.3 |
| T5.3.4 | [ ] | Forgot-password paths | recovery-key path / clear-cloud path | open Core + closed | TC5.3 |
| T5.3.5 | [ ] | Recovery-key management | generate / regenerate (old key invalidated) | open Core | TC5.3 |
| T5.3.6 | [ ] | MK epoch | version number + multi-device self-healing | open Core + closed | TC5.6 |

### T5.4 Per-entry encryption

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.4.1 | [ ] | DEK generation & wrapping | random DEK per entry | open Core | — |
| T5.4.2 | [ ] | Envelope codec | AES-256-GCM + compression + envelope format | open Core | TC5.4 |
| T5.4.3 | [ ] | Batch encrypt / decrypt | batch processing APIs | open Core | TC5.4 |

### T5.5 Sync protocol

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.5.1 | [ ] | Server envelope storage | envelopes table + MinIO blobs + change endpoints | closed | TC5.5 |
| T5.5.2 | [ ] | Client upload engine | incremental upload + resumable | open Core | TC5.5 |
| T5.5.3 | [ ] | Client pull & merge | incremental pull + LWW | open Core | TC5.5 |
| T5.5.4 | [ ] | Tombstone handling | delete propagation | open Core | TC5.5 |
| T5.5.5 | [ ] | sync_state tracking | local sync status flags | open Core | TC5.5 |

### T5.6 Multi-device

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T5.6.1 | [ ] | Account UI | login / register / account settings (change password, recovery key) + MK unwrap flow | open Core + open App | TC5.2、TC5.3 |
| T5.6.2 | [ ] | Epoch self-healing | version detection + automatic re-upload | open Core | TC5.6 |

## 8. Stage 6: Subscriptions & AI Credits (M3)

**Note**: **server-side deliverables (entitlement verification, gateway, ledger) are developed in `closed/`; client-side deliverables (StoreKit, entitlement state, credit UI) belong to the open-source repository.** IAP sandbox testing is the most tedious manual-testing area of the whole project — budget time generously.

### T6.1 StoreKit 2

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T6.1.1 | [ ] | Product definitions | Pro monthly / yearly, Pro+ monthly / yearly, top-up packs | open App | TC6.1 |
| T6.1.2 | [ ] | Purchase flow | product display + purchase UI | open App | TC6.1 |
| T6.1.3 | [ ] | Transactions & restore | transaction listener + restore purchases | open App | TC6.1 |

### T6.2 Entitlement sync

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T6.2.1 | [ ] | App Store Server API verification | receipt / transaction validation | closed | TC6.2 |
| T6.2.2 | [ ] | Server Notifications V2 | renew / refund / grace handling | closed | TC6.2 |
| T6.2.3 | [ ] | Client entitlement state machine | Free / Pro / Pro+ transitions | open Core | TC6.2 |

### T6.3 AI gateway

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T6.3.1 | [ ] | Gateway auth | subscription-token middleware | closed | TC6.3 |
| T6.3.2 | [ ] | Model routing | small / large model routing config | closed | TC6.3 |
| T6.3.3 | [ ] | Streaming relay | relay + never persisted | closed | TC6.3 |

### T6.4 Credit ledger

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T6.4.1 | [ ] | Ledger & debits | transactional debits + idempotency | closed | TC6.4 |
| T6.4.2 | [ ] | Monthly rollover | rollover capped at one month's allowance | closed | TC6.4 |
| T6.4.3 | [ ] | Credit UI | remaining-credits display + hard-stop hints | open App | TC6.4 |

### T6.5 Channel switching

| # | ✅ | Task | Deliverable | Location | Manual test |
|---|---|---|---|---|---|
| T6.5.1 | [ ] | BYOK ↔ built-in-credits switch | instant switching + built-in channel client (via gateway) | open Core + open App | TC6.5 |

## 9. Stage 7: Polish & Release (M4)

**Goal**: from "works" to "trusted and sellable".

### T7.1 Compliance materials

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T7.1.1 | [ ] | Privacy policy | E2EE promises + AI exceptions disclosed | TC7.1 |
| T7.1.2 | [ ] | Terms + website | agreement + landing page | TC7.1 |

### T7.2 Beta

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T7.2.1 | [ ] | TestFlight setup | invite / install / update | TC7.2 |
| T7.2.2 | [ ] | Feedback collection | channel + task tracking | TC7.2 |

### T7.3 Performance polish

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T7.3.1 | [ ] | Launch performance | cold start < 2s | TC7.3 |
| T7.3.2 | [ ] | Panel responsiveness | open < 100ms | TC7.3 |
| T7.3.3 | [ ] | Memory & leaks | stable all-day runs | TC7.3 |

### T7.4 App Store submission

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T7.4.1 | [ ] | Notarization & Hardened Runtime | signing / notarization config | TC7.4 |
| T7.4.2 | [ ] | Sandbox adaptation | full-feature sandbox validation | TC7.4 |
| T7.4.3 | [ ] | MAS submission | submission + review handling | TC7.4 |

### T7.5 Open-source release

| # | ✅ | Task | Deliverable | Manual test |
|---|---|---|---|---|
| T7.5.1 | [ ] | Repository public | the outer repository goes public as-is (no code relocation) | — |
| T7.5.2 | [ ] | README / Contributing / MIT | the open-source trio | TC7.5 |
| T7.5.3 | [ ] | Clean build & scan | no closed/ references, no credentials | TC7.5 |

## 10. Stage 8: Backlog (unscheduled)

Web app (in-browser decryption) | iOS / iPadOS | Paddle billing | Share links (DEK re-wrapping) | Team spaces | Open-sourcing & self-hosting the server | i18n | Panel popup positioning (follow cursor / screen corner) | UI polish & animations (formal panel visual pass)

## 11. Dependencies

```
Stage 0 → 1 → 2 → 3              (M1–M2 main line, sequential)
              ↘
                Stage 4           (T4.1 needs stage 1; action UI needs stage 2; parallel with 3)
Stage 5 → 6                      (server in closed/, client open-source; needs stage 1's data model)
Stage 7                          (needs M3 complete)
```

## 12. Risks & Countermeasures

| Risk | Impact | Countermeasure |
|---|---|---|
| FTS5 Chinese tokenization is poor | search quality suffers | verify in T3.1.2; switch to trigram tokenizer + LIKE fallback if needed |
| OCR background indexing hog | perceived lag | throttle in foreground + incremental resume (TC3.3) |
| IAP review rejection (clipboard sensitivity) | launch delay | T1.7 privacy filtering + T7.1.1 privacy policy first; self-check against the review checklist (TC7.4) |
| Forgot-password UX complaints | paid-user churn | clear pre-reset warnings + recovery-key guidance (full TC5.3 flow) |
| AI cost runaway | margin erosion | credit soft cap + model routing + beta-usage calibration |
| Closed code leaks into the public repo | core asset exposure | .gitignore hard isolation + TC0.1 / TC7.5 double checks |
