# ClipRecall Manual Test Checklist

> Companion documents: [Technical Architecture](architecture.md), [Project Plan](project-plan.md). Chinese version: [manual-test-checklist.zh-CN.md](manual-test-checklist.zh-CN.md).
> **How to use**: after finishing a task group (T X.Y), find the **same-numbered** test (TC X.Y) and verify each item by hand, ticking as you go — **TC numbers map one-to-one to task groups: TC X.Y is the test for T X.Y**. When one task group has multiple test themes, they are grouped under bold sub-headings.
> **Why manual testing**: real pasteboard behavior, system permissions (TCC), cross-app paste compatibility and IAP sandboxing cannot be covered by unit tests — they must be verified by hand.

## 0. Test environment setup (one-time) ✅

- [x] Install test apps: Safari, Chrome, Terminal, VS Code, Finder, Notes / Pages (rich text), WeChat, Feishu, 1Password (or any password manager)
- [x] Enable the Accessibility permission in System Settings (TCC)
- [x] Prepare test material: long text (>5000 chars), a rich-text web page with tables and links, mixed Chinese/English text, screenshots (one Chinese, one English), a 10MB+ image, multi-file selection
- [x] Agree on a "long-run" scenario: use the machine normally for a full day, then check history completeness and resource usage
- [ ] Two-device tests (TC5.5 / TC5.6) require a second Mac; postpone them until a second device is available

## Stage 0

### TC0.1 Repository isolation (T0.1)
- [x] `closed/` is ignored by the outer git (git status shows no closed/ files)
- [x] closed/ is its own private git repository, committing and pushing normally
- [x] The open-source repository builds without anything from closed/ (delete closed/ and it still builds)

### TC0.3 Database creation & migration (T0.3)
- [x] First launch creates the database automatically; data survives restarts
- [ ] migration v1 upgrade path works (construct an old-version database to verify the migration script; not possible during v1 — deferred until v2 exists)

### TC0.4 Logging (T0.4)
- [x] Logs are emitted per module at the correct levels
- [ ] No error spam after running normally for 1 hour

## Stage 1: Local Engine

> Manual-testing rhythm: **after the debug UI (T1.3) is done, run TC1.1 / TC1.2 / TC1.3; from then on, run each task group's TC right after completing it (build one, test one).** TC1.6 retention items and TC1.7's custom exclusion-list item are verified after the settings page (T2.6.2) in stage 2.

### TC1.1 Basic monitoring (T1.1)
- [x] Copying from Safari / Chrome / Terminal / VS Code each appears in the debug list
- [x] Entries appear within 1 second (polling delay acceptable)
- [x] 100 rapid consecutive copies: nothing lost, no duplicates
- [x] After sleep & wake, monitoring recovers and copies are still recorded

### TC1.2 Format capture (T1.2)

**Text (T1.2.1)**
- [x] Copy plain text, click the entry in the debug list, press Cmd+V manually — the original is preserved (Chinese, English, emoji, multi-line, indentation)

**Rich text (T1.2.4)**
- [x] Copy formatted text from a web page (bold / links / tables) → click the entry → Cmd+V into Notes — formatting preserved
- [x] Copy a table from Pages / Numbers → paste into Notes — table structure preserved
- [x] Copy text from Notes → paste into Pages — formatting preserved

**Images & files (T1.2.2 / T1.2.3)**
- [x] Screenshot (Cmd+Shift+4) → the image entry appears in the debug list with a correct thumbnail
- [x] "Copy image" in a browser → the entry appears
- [x] Copy 1 file / multiple files in Finder → file entries appear with correct icon and name
- [x] Copy a 2GB file → recorded normally with no system lag (references only, no copy)

### TC1.3 Debug UI (T1.3)
- [x] The menu bar dropdown shows recent entries (max 50), newest on top
- [x] Clicking an entry copies it back to the clipboard (the verification entry point for TC1.2's formats)
- [x] Debug menu items: pause/resume toggle and accessibility-permission entry work

### TC1.4 Type detection (T1.4)
- [x] Copy a URL → link icon + domain shown, recognized as a link type
- [x] Copy code → recognized as a code type with a language label (syntax highlighting deferred to the stage-2 panel)
- [x] Copy a color value (e.g. #FF5733) → color swatch preview shown

### TC1.5 Dedup & merge (T1.5)
- [x] Copy the same content 3 times → only one entry in the list
- [x] Copy a large text from a web page (system-chunked copy) → merged into one complete entry (hard to reproduce manually; guarded by 5 unit tests)

### TC1.6 Storage & retention (T1.6; verify after the settings page T2.6.2)
- [ ] Set a limit of 100 entries → oldest entries are cleaned beyond the limit
- [ ] Set 7-day retention → entries older than 8 days are cleaned
- [ ] Pinned entries are exempt from retention cleanup

### TC1.7 Privacy filtering (T1.7)
- [x] Copying a password in 1Password → never appears in the list (default exclusion list; verified in practice by temporarily adding TextEdit to the list)
- [x] Copy card-number-format / API-key-format text → detected (masked display + category label; recalling pastes the full original)
- [x] Debug-menu pause → copies stop entering the list; resume → normal (verified during T1.3.2)
- [ ] Excluded-app copies are not recorded (custom exclusion list verified after the settings page T2.6.2)

### TC1.8 Permissions (T1.8)
- [x] Debug-menu "Accessibility" click → guide card + jump to System Settings works (debug builds not appearing in the TCC list is a known system quirk; full grant testing deferred until proper signing)
- [x] Graceful degradation without the permission: the guide card shows the unpermitted state normally, no crashes

## Stage 2: UI & Recall

### TC2.1 Panel & rendering (T2.1)
- [x] Clicking the menu bar icon opens the panel
- [ ] Text / image / file / URL / code / color entries all render correctly
- [x] Scrolling 5000 entries stays smooth (list virtualization; verified via the "Test data" debug button, auto-cleaned on restart)

### TC2.2 Keyboard interaction (T2.2)
- [ ] Full keyboard flow: open → arrow-select → Enter to copy → Esc to close
- [ ] Shift+Enter pastes directly into the frontmost app and closes the panel
- [ ] The panel never steals focus from the frontmost app; focus returns correctly after Esc

### TC2.3 Paste compatibility matrix (core test, go app by app)

| App | Original-format paste | Plain-text paste |
|---|---|---|
| Notes / Pages | ☐ | ☐ |
| Terminal | ☐ | ☐ |
| VS Code | ☐ | ☐ |
| WeChat / Feishu | ☐ | ☐ |
| Safari address bar | ☐ | ☐ |

**Paste modes (T2.3.3)**
- [ ] Plain-text mode: formatted web text pastes into Notes without formatting pollution
- [ ] Original-format mode: pasting into a rich-text editor preserves formatting (pairs with TC1.2)

### TC2.4 Entry management (T2.4)
- [ ] Pinned entries survive app restarts
- [ ] Delete asks for confirmation; batch delete works
- [ ] Editing an entry then copying yields the edited version
- [ ] Multi-select 3 entries and merge-copy → pastes as one continuous content

### TC2.5 Global hotkey (T2.5)
- [ ] Custom hotkey takes effect after rebinding
- [ ] Conflicts with system / common app shortcuts produce a hint
- [ ] The hotkey works in fullscreen apps and games

### TC2.6 Settings & launch (T2.6)
- [ ] Launch at login (SMAppService) works; the app auto-starts after reboot
- [ ] All settings apply immediately or clearly prompt for a restart

## Stage 3: Search

### TC3.1 Full-text search (T3.1)
- [ ] Chinese keywords hit the right entries (**record poor-tokenization cases** — decides whether to switch to the trigram tokenizer)
- [ ] English search is case-insensitive
- [ ] Fuzzy search (missing/wrong characters) hits within reason

### TC3.2 Filtering (T3.2)
- [ ] Typing in the search box searches immediately (debounced), no lag
- [ ] Filter by type (text / image / file / URL / code / color) works
- [ ] Filter by source app works
- [ ] Filter by time works; combined filters work

### TC3.3 Image OCR (T3.3)

**Accuracy (T3.3.1 / T3.3.3)**
- [ ] Chinese screenshot content is searchable by keyword
- [ ] English screenshot content is searchable by keyword
- [ ] Handwriting / low-resolution screenshots (**record failure cases**, evaluate whether it's worth optimizing)

**Resource usage (T3.3.2)**
- [ ] Batch-indexing 100 screenshots keeps CPU under control without foreground lag
- [ ] Indexing resumes from where it stopped after a restart

### TC3.4 Local semantic search (T3.4)
- [ ] A related sentence without the keyword (e.g. "last week's flight info") finds the right entry
- [ ] Unrelated entries don't appear (**record false-positive cases**)
- [ ] Semantic search works offline (local implementation)

## Stage 4: AI

### TC4.1 Provider connectivity (T4.1)
- [ ] OpenAI / DeepSeek / Moonshot / custom endpoints each work after configuration
- [ ] A wrong API key produces a clear error
- [ ] Keys persist in the Keychain across restarts

### TC4.2 Action quality (T4.2)

**Quality (T4.2.1 / T4.2.3)**
- [ ] Summarize / translate / polish / rewrite tone / explain code all produce reasonable results
- [ ] Streaming renders word by word without UI lag

**Edge cases (T4.2.2)**
- [ ] Very long text (>10k chars) → truncation kicks in or a clear hint appears
- [ ] Offline / timeout / provider 5xx → friendly error, retryable
- [ ] Garbled / unexpected provider responses → no crash

### TC4.3 Local models (T4.3)
- [ ] With Ollama running locally → auto-detected ✅ + model dropdown is correct
- [ ] Ollama not installed → install-guide entry shown (links to Ollama's official page)
- [ ] vLLM custom endpoint works after configuration
- [ ] Local models run offline — no network requests are made

### TC4.4 Result management (T4.4)
- [ ] AI results are saved as derived entries and can be copied on their own
- [ ] The original entry is never overwritten
- [ ] Action history is browsable

### TC4.5 Privacy interaction (T4.5)
- [ ] A confirmation dialog appears before every call; cancelling sends nothing
- [ ] BYOK mode says "direct to your provider"; built-in-credits mode says "transiently processed by our server"
- [ ] AI is off by default and must be enabled manually

## Stage 5: Backend & Sync

### TC5.1 Server deployment (T5.1)
- [ ] Docker Compose starts everything with one command; HTTPS certificates work
- [ ] Backup scripts run + **one restore drill** (prove the backups actually work)

### TC5.2 Accounts (T5.2; verify after the account UI in T5.6.1)
- [ ] Register / login / logout full flow
- [ ] Weak passwords are rejected at registration
- [ ] Expired tokens re-login cleanly

### TC5.3 E2EE key system (T5.3; verify after the account UI in T5.6.1)

**Password lifecycle (T5.3.2 / T5.3.3 / T5.3.4)**
- [ ] Change password (old one known) → zero data movement, other devices unaffected
- [ ] Forgot password + recovery key → zero-loss recovery
- [ ] Forgot password without recovery key → warning shown (with "N cloud entries not synced to this device") → cloud cleared & re-uploaded, local data intact

**Recovery key (T5.3.5)**
- [ ] Generated at registration with smooth save guidance
- [ ] Regenerable any time in settings after login
- [ ] Regenerating invalidates the old key immediately

### TC5.4 Per-entry encryption (T5.4; spot-check the server)
- [ ] The server database and object storage contain **no plaintext clipboard content**
- [ ] Envelope metadata is limited to id / time / type / size

### TC5.5 Sync (T5.5)
- [ ] Two devices (same account) sync both ways; new entries appear on both
- [ ] Deletes propagate (tombstones work)
- [ ] Simultaneously editing the same pin on two devices → LWW leaves them consistent
- [ ] Copies made offline upload automatically when the network returns
- [ ] Server down → local features completely unaffected

### TC5.6 Multi-device self-healing (T5.6; includes T5.3.6 MK epoch)
- [ ] Device A resets its password → device B detects the epoch change and asks to re-login → after re-login the cloud holds the union of both devices (no duplicates)

## Stage 6: Subscriptions & Credits

### TC6.1 IAP purchases (T6.1; StoreKit sandbox)
- [ ] Pro monthly / yearly, Pro+ monthly / yearly and top-up packs are all purchasable in the sandbox
- [ ] Monthly and yearly both verified
- [ ] Cancel subscription / restore purchases work

### TC6.2 Entitlement sync (T6.2)

**Subscription lifecycle (T6.2.1 / T6.2.3)**
- [ ] Trial → renew → expire & downgrade to Free → re-subscribe: entitlements are correct at each stage
- [ ] Entitlement changes switch features on/off immediately (sync / AI credits / semantic search)

**Refunds & grace (T6.2.2)**
- [ ] Sandbox-simulated refund → the server revokes the entitlement
- [ ] Billing failure enters the grace period → auto-downgrade afterwards

### TC6.3 Gateway (T6.3)
- [ ] Built-in-credit calls go through the server gateway successfully
- [ ] Server logs confirm **no plaintext is persisted**

### TC6.4 Credits (T6.4)
- [ ] Every AI action debits accurately in real time
- [ ] Monthly rollover works (capped at one month's allowance)
- [ ] Out of credits → hard stop + top-up guidance
- [ ] Buying a top-up pack adds credits instantly; the balance is consistent across devices

### TC6.5 Channel switching (T6.5)
- [ ] BYOK ↔ built-in-credits switching takes effect instantly without interference
- [ ] Unsubscribed users get full BYOK actions (the free tier's core experience)

## Stage 7: Pre-release Regression

### TC7.1 Compliance (T7.1)
- [ ] The privacy policy matches actual app behavior (E2EE promises, transient-AI exception, metadata disclosure)
- [ ] The website is reachable and subscription guidance is correct

### TC7.2 TestFlight (T7.2)
- [ ] Invite / install / update full flow
- [ ] Beta feedback channel works and feeds the task tracker

### TC7.3 Performance (T7.3)
- [ ] Cold start < 2s
- [ ] Panel opens feeling instant (< 100ms target)
- [ ] A full day of continuous use: stable memory, no leaks, no crashes

### TC7.4 App Store submission (T7.4)
- [ ] Notarized build installs without Gatekeeper warnings
- [ ] All features work under the sandbox
- [ ] Self-check against the App Store review checklist (clipboard-permission disclosure, privacy labels)

### TC7.5 Open-source release (T7.5)
- [ ] The public repository builds cleanly (no private dependencies)
- [ ] closed/ is not part of the public repository (.gitignore effective, no closed code in history)
- [ ] No hardcoded keys / credentials anywhere
- [ ] README / Contributing / MIT License complete

---

> When architecture decisions change, check whether this list needs new test entries; problems found during testing are recorded against the corresponding task's deliverable in [Project Plan](project-plan.md).
