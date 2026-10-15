# ClipRecall 技术架构

> 本文档描述 ClipRecall 的整体技术架构，是开发各阶段技术决策的依据，随架构决策持续演进。
> 配套文档：[项目计划](project-plan.zh-CN.md)、[人工测试清单](manual-test-checklist.zh-CN.md)

## 1. 产品定位与架构目标

### 1.1 产品是什么（What）

ClipRecall 是一款 macOS 剪贴板历史管理工具：记录剪贴板历史（支持纯文本、富文本、图片、文件等多种格式），随时召回到剪贴板粘贴；在此基础上提供 AI 能力（总结、翻译、润色、语义搜索等）与 E2EE 云同步。

商业模式：核心功能开源免费；云同步与 AI 内置额度为订阅制增值服务（Free / Pro / Pro+ 三档，Mac App Store 首发，后期加 Paddle 双渠道）。

### 1.2 为什么这样设计（Why）——四条架构原则

1. **本地优先（Local-first）**：设备本地数据库是数据源，云端只是加密镜像。断网时所有本地功能（采集、召回、搜索、BYOK AI）完整可用，服务端宕机不影响产品。
2. **核心与 UI 分层**：所有非 UI 逻辑放入 `ClipRecallCore`（SPM 库，零 UI 依赖），UI 层（SwiftUI）只做展示与交互。这是将来移植 iOS/iPadOS 乃至 Windows 的根基——移植代价仅限于 UI。
3. **E2EE 哑存储**：服务端只存密文信封，密钥永不出设备。剪贴板内容（密码、Token、私人信息）比笔记更敏感，"拖库不泄"是本类产品的及格线。
4. **开放核心（Open Core）**：客户端全部开源（含 E2EE 客户端，可审计即信任）；服务端闭源。免费与付费的边界由"本地能力 vs 云能力"天然划分，代码物理隔离规则见第 9 节。

## 2. 技术栈选型

### 2.1 客户端（macOS）

| 项 | 选型 | 理由 |
|---|---|---|
| 语言 / UI | Swift 6 + SwiftUI，最低 macOS 14 | 原生体验与系统集成（NSPasteboard、AX）最佳；Swift 6 严格并发 |
| 数据库 | GRDB.swift（SQLite + FTS5） | Swift 生态事实标准，DatabasePool 读写并发 |
| 加密 | CryptoKit（AES-256-GCM，硬件加速）+ libsodium 包装（Argon2id，CryptoKit 不支持） | 系统原生优先，仅补缺口 |
| OCR | Vision（VNRecognizeTextRequest） | 本机免费、离线、中英文 |
| 语义向量 | NaturalLanguage（NLEmbedding） | 本机免费语义搜索（免费档） |
| AI 客户端 | URLSession（OpenAI 兼容协议，SSE 流式） | 零第三方依赖 |
| 架构 | 无第三方依赖注入框架，构造器注入 | 单人项目控制依赖面 |

### 2.2 服务端（自建服务器）

| 项 | 选型 | 理由 |
|---|---|---|
| 语言 / 框架 | Swift + Vapor 4 | 与客户端同语言，单人全栈维护成本最低 |
| 数据库 | PostgreSQL + pgvector | 关系数据 + 向量检索一体 |
| 对象存储 | MinIO（S3 兼容） | 自托管 blob 存储 |
| 反向代理 / 证书 | Caddy | 自动 HTTPS |
| 部署 | Docker Compose | 单机可维护，将来可迁移 |

## 3. 客户端架构

### 3.1 工程结构

```
ClipRecall/                      # 开源仓库（git）
├── .gitignore                   # 忽略 closed/ 与构建产物
├── App/                         # 开源：App UI（本地功能 + BYOK，零闭源依赖）
├── ClipRecallCore/              # 开源：SPM 库（零 UI 依赖）
│   └── Sources/ClipRecallCore/
│       ├── Models/              # Clip、Format 等数据模型
│       ├── Clipboard/           # 剪贴板监听与格式捕获
│       ├── Storage/             # GRDB 仓储、大对象文件管理、保留策略
│       ├── Search/              # FTS5、OCR 索引、语义搜索
│       ├── AI/                  # Provider 抽象、AI 动作执行（BYOK）
│       ├── Sync/                # E2EE 客户端（密钥管理、信封、同步引擎）
│       └── Diagnostics/         # 结构化日志
├── docs/                        # 开源：架构、计划、测试清单
└── closed/                      # ❌ 被外层 .gitignore 忽略；内部为独立私有 git 仓库
    ├── server/                  # Vapor 服务端（auth/sync/网关/权益/账本）
    ├── configs/                 # 部署配置模板（真实密钥在 .env，不入库）
    └── README.md                # 闭源边界说明
```

### 3.2 模块职责与数据流

```
NSPasteboard ──监听──▶ ClipboardMonitor ──捕获格式包──▶ Storage（SQLite + 文件）
                                                            │
                                            ┌───────────────┼───────────────┐
                                            ▼               ▼               ▼
                                      Search 索引      Sync 引擎         UI 面板
                                      (FTS5/OCR/向量)  (E2EE 信封)   (列表/键盘/召回)
```

- **ClipboardMonitor**：轮询 `NSPasteboard.changeCount`（0.5s 间隔），变化时读取全部表示（formats）；
- **Storage**：条目元数据入 SQLite，图片 / 长 HTML 等大对象落盘；执行去重、合并、保留策略；
- **Search**：后台队列增量建索引（FTS5 全文 + OCR 文本 + 语义向量），索引与存储解耦；
- **Sync**：独立后台队列，消费存储层变更记录；网络失败静默重试、恢复续传；
- **UI**：菜单栏面板（MenuBarExtra），事件驱动读取存储层。

### 3.3 并发模型

- 主 actor 负责 UI；GRDB DatabasePool 读写分离；
- 每类后台工作一条串行队列（采集、OCR、索引、同步），避免竞争同一批数据；
- 捕获路径延迟优先（落库 < 50ms）；OCR、同步等重活全部异步，前台活跃时降速。

## 4. 数据模型

### 4.1 核心实体：Clip（剪贴板条目）

```swift
struct Clip {
  let id: UUID            // 客户端生成，同步幂等
  var capturedAt: Date
  var sourceApp: SourceApp?   // { bundleId, name }，来源应用
  var primaryType: ClipType   // text / richText / image / file / url / code / color
  var formats: [Format]       // 格式包
  var textPreview: String?    // 列表展示 + 搜索索引
  var pinned: Bool
  var tags: [String]
  var groupId: UUID?
  var updatedAt: Date         // LWW 冲突解决字段
  var isDeleted: Bool         // tombstone（软删除同步用）
}
```

### 4.2 Format：格式包（镜像系统剪贴板的多表示设计）

macOS 剪贴板一个条目天然携带多种表示（纯文本 / HTML / PNG / 文件引用），数据模型直接对齐，这是支持"丰富格式"的关键：

```swift
struct Format {
  let type: String      // UTI：public.utf8-plain-text / public.html / public.png / public.file-url …
  var payload: Payload  // .inline(Data) 小内容内联；.file(path) 大对象落盘
  var metadata: FormatMetadata  // 图片尺寸 / 文件数量 / 代码语言 …
  let version: Int      // 格式版本号，演进预留
}
```

设计要点：

- **文件条目存引用不存副本**：复制 2GB 文件只记录路径 + 名称/图标/大小元数据；文件被删后预览仍显示"文件已不存在"；
- **URL / 代码 / 颜色是派生类型**：从纯文本检测得出，复用同一条文本数据，不复制存储；
- 大对象文件目录：`Application Support/ClipRecall/blobs/{uuid}`，缩略图单独目录。

### 4.3 数据库表

| 表 | 用途 |
|---|---|
| clips | 条目主表（pinned / tags / updatedAt / tombstone） |
| formats | 格式包（一条 Clip 多个 Format） |
| fts | FTS5 虚拟表（textPreview + OCR 文本） |
| sync_state | 本地条目同步状态（pending / synced） |
| settings | 用户设置（保留策略、排除名单、快捷键） |

### 4.4 搜索索引策略

- **全文**：FTS5。中文检索注意：默认 unicode61 分词对中文按字切分，查询用短语匹配 + LIKE 兜底（T3.1 人工验证效果，必要时切换 trigram tokenizer）；
- **OCR 文本**：Vision 识别结果并入 FTS5 索引，图片内容可被搜到；
- **语义向量**：见 5.4。

## 5. AI 子系统

### 5.1 Provider 抽象（OpenAI 兼容协议）

所有供应商统一走 OpenAI 兼容 `/v1/chat/completions` 协议（SSE 流式）：

- 内置预设：OpenAI、DeepSeek、Moonshot、Ollama（`localhost:11434/v1`）、vLLM（自定义端点）、自定义（任意兼容服务）；
- BYOK：API Key 存 Keychain，客户端直连供应商，不经我方服务器；
- Ollama 自动检测：启动时 ping `localhost:11434`，检测到即显示状态并拉取已安装模型列表（`GET /api/tags`）做成下拉框；未安装则显示文档引导入口（不内嵌安装器）。

### 5.2 动作与积分定价

| 动作 | 说明 | 积分（Pro 内置额度） |
|---|---|---|
| 翻译 | 短文本 | 1 |
| 润色 / 改写语气 | 单条 | 2 |
| 解释代码 | 单条 | 2 |
| 总结 | 长文本 | 5 |
| 语义搜索 | 每次查询 | 0.5 |

数值为方向性设定，Beta 期实测人均消耗后校准；积分只按动作标价，内部按任务路由小/大模型以控制成本。

### 5.3 两条 AI 通道

```
BYOK 通道：    客户端 ──直连──▶ 用户自己的供应商（不经我方服务器，成本用户自付）
内置额度通道： 客户端 ──TLS──▶ 我方 AI 网关 ──▶ 云模型（不落盘，临时处理）
```

内置额度通道是 E2EE 承诺的显式例外：内容经用户授权后临时流经服务器，处理完即弃、不写入存储。BYOK 与内置额度的切换在设置页即时生效。

### 5.4 语义搜索架构

- **免费档**：NLEmbedding 本机向量 + 本机余弦检索（零成本、零联网，多语言效果弱于云端模型）；
- **Pro 档**：客户端本地模型（CoreML）计算 embedding → 向量作为非敏感元数据上传 → 服务端 pgvector 检索 → 返回条目 ID → 客户端解密展示。**服务端只存向量、不见原文**，与 E2EE 兼容。

### 5.5 AI 结果存储

AI 产物（总结 / 翻译等）作为该条目的**派生 Format** 保存（type: `ai-summary` 等，附 provider / model 元数据），可单独复制，不覆盖原内容。

## 6. E2EE 与同步

### 6.1 密钥层级（双包裹模型）

```
                随机生成主密钥 MK（32 字节，加密所有数据）
                    ▲              ▲
      密码派生 KEK_pw 包裹     恢复密钥派生 KEK_rk 包裹
                    │              │
        服务端存：wrapped_pw(MK) + wrapped_rk(MK) + 认证哈希
```

- **MK**：客户端生成，永不出设备；服务端只见两份 wrapped(MK)；
- **KEK_pw**：Argon2id(password, salt)，OWASP 推荐参数，加盐；密码注册时强制最低强度；
- **恢复密钥**：32 字符随机串，仅忘记密码时使用；登录后可随时重新生成（重包裹 MK、旧密钥作废），无"一次性展示丢了就完"的压力；
- **MK epoch（版本号）**：重置后递增，其他设备检测到版本变化 → 提示重新登录 → 自动重传，多设备自愈。

### 6.2 条目加密

- 每条目随机 DEK（AES-256-GCM），用 MK 包裹后随条目存储；单条目泄露不波及其他，也为将来"分享链接"（DEK 重包裹给接收方）预留；
- 信封格式（服务端所见）：

```
{ itemId, updatedAt, type, size, iv, wrappedDEK, ciphertext }
```

- 前四项是唯一明文元数据（增量同步必需），内容严格加密；此取舍在隐私声明中明示。

### 6.3 同步协议

- 服务端 = 哑存储：加密信封 + 变更记录，无任何解密能力；
- 客户端上传本地变更（新增/修改/删除 tombstone）、拉取服务端变更；
- 冲突解决：逐条目 LWW（updatedAt 最后写入胜）——剪贴板历史是追加型数据，并发改同一条目概率极低，LWW 足够，不引入完整 CRDT；
- 上传前压缩再加密；分批、断点续传；服务端保留期（如 90 天）与本地保留策略分开设置。

### 6.4 密码生命周期

| 场景 | 流程 | 数据影响 |
|---|---|---|
| 正常登录 | 密码解 MK | 无 |
| 修改密码（知道旧密码） | 新 KEK_pw 重包裹 MK | 零移动、秒级 |
| 忘记密码 + 有恢复密钥 | 恢复密钥解 MK → 设新密码 → 重包裹 | 零丢失 |
| 忘记密码 + 无恢复密钥 | 清云 + 设备全量重传（UUID 幂等） | 仅丢"只在云端"的数据，重置前明确警告 |

- Web 端（后期功能）：浏览器内 Argon2id（WASM）+ WebCrypto 解密，密钥不上传；密钥设计现在就兼容，将来零返工。

### 6.5 威胁模型与承诺

- 服务端拖库 / 入侵：只见密文信封与少量元数据，不可读内容；
- 弱密码：Argon2id 高参数 + 注册时最低强度校验（Bitwarden 同款威胁模型）；
- AI 内置额度：临时明文、授权后传输、不落盘；
- 已知取舍（明示）：服务端可见条目 id / 时间 / 类型 / 大小元数据。

## 7. 服务端架构

### 7.1 服务划分

| 服务 | 职责 |
|---|---|
| auth | 注册 / 登录 / 令牌；认证哈希 Argon2id（与加密 KEK 隔离，互不可互推） |
| sync | 信封上传 / 下载 / 变更拉取（哑存储，不可读内容） |
| ai-gateway | 订阅鉴权、模型路由、转发（不落盘）、用量上报 |
| billing | StoreKit 2 服务器校验、权益管理、订阅事件处理 |
| credits | 积分账本（事务扣减、月度结转、加油包） |
| search | pgvector 向量检索（仅向量，无原文） |

### 7.2 数据表

users / sessions / wrapped_keys / entitlements / subscriptions / credits_ledger / envelopes / vectors(pgvector)

### 7.3 部署与运维

- Docker Compose：Caddy（HTTPS）+ Vapor + PostgreSQL(pgvector) + MinIO；
- 备份：Postgres 逻辑备份 + MinIO 数据镜像（异地 / 多副本）；
- 监控：结构化日志 + 健康检查端点（单人项目不引入重型监控栈）。

### 7.4 API 概览

| 端点 | 用途 |
|---|---|
| POST /auth/register、/auth/login、/auth/refresh | 账号与令牌 |
| POST /auth/password/change | 改密码（重包裹 MK） |
| POST /auth/password/recover | 忘密码（恢复密钥路径 / 清云路径） |
| GET /sync/changes?since= | 增量拉取变更 |
| POST /sync/items、GET /sync/items/{id} | 信封批量上传 / 下载 |
| POST /ai/chat | 内置额度通道（流式，不落盘） |
| POST /search/query | 向量检索 |
| POST /billing/webhook/appstore | App Store Server Notifications V2 |

## 8. 订阅与计费

| | Free | Pro | Pro+ |
|---|---|---|---|
| 价格 | 0 | $4/月（$40/年） | $8/月（$80/年） |
| 云同步 E2EE | ❌ | ✅ | ✅ |
| AI 积分/月 | 0（BYOK 不限） | 1000 | 3000 |
| 语义搜索 | 本地（NLEmbedding） | 云端向量 + 本地 | 同 Pro |
| 额度结转 | — | 最多滚存 1 个月额度 | 同左 |

- 超额：硬停 + 一次性"额度加油包"（IAP consumable），不做自动充值（避免惊吓账单与退款纠纷）；
- 权益同步：App Store Server API + Server Notifications V2（订阅 / 续费 / 退款 / 宽限期）；后期 Paddle 进入同一张权益表；
- 积分账本服务端记账（多设备共享），扣减事务化、幂等；重度用户自然流向 BYOK，内置额度是软上限。

## 9. 开源与闭源隔离

### 9.1 边界划分

- **开源（GitHub 公开）**：客户端全部代码——App UI、采集、存储、搜索、BYOK、E2EE 客户端、AI 网关的调用协议。E2EE 代码开源是信任的根基（可审计），BYOK 开源是硬核用户的口碑引擎；
- **闭源（私有仓库）**：服务端全部（auth / sync / 网关 / 权益 / 账本）、部署配置、将来可能的闭源客户端模块（如团队版）。

内置额度通道的关键点：客户端侧只是"调用公开协议"，鉴权、模型路由、额度扣减全部在服务端，因此**客户端可以 100% 开源**——闭源代码 = 服务端 + 配置。

### 9.2 物理隔离规则（硬性约束）

1. **目录隔离**：闭源代码只允许存在于 `closed/`；`closed/` 被外层 `.gitignore` 完全忽略；
2. **版本控制**：`closed/` 内部为独立的私有 git 仓库（GitHub Private 或自建），与外层开源仓库互不引用；
3. **构建隔离**：开源代码禁止 `import` 任何闭源代码——开源仓库 clone 下来即可完整构建本地全部功能 + BYOK；内置额度通道在无订阅时优雅降级；
4. **密钥隔离**：`closed/configs/` 只放模板，真实密钥 / 证书存 `.env`（同样被忽略，任何仓库不提交）；
5. **发布检查**：开源仓库公开前执行扫描（T7.5.3）：无 `closed/` 引用残留、无硬编码凭据。

### 9.3 License 与仓库

- 开源部分：MIT；Logo 与品牌保留；
- 闭源部分：私有仓库，不授权；
- 发布策略：目录结构天然支持拆分——外层仓库直接公开即可，无需代码搬迁。

## 10. 性能与安全基线

- 面板唤起 < 100ms；捕获到落库 < 50ms；
- 轮询间隔 0.5s；前台活跃时降速 OCR / 同步等后台任务；
- 图片：原图上限 10MB + 缩略图；本地历史默认 2000 条 / 30 天（可调）；
- 安全：密码 / MK / 恢复密钥 / API Key 全部 Keychain；零硬编码凭据；公证 + Hardened Runtime；服务端认证哈希 Argon2id。

---

> 本文档随架构决策演进，任何改动需同步检查 [项目计划](project-plan.zh-CN.md) 与 [人工测试清单](manual-test-checklist.zh-CN.md) 是否受影响。
