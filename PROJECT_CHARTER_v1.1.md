# Project Charter：意图驱动的个人智能知识引擎 (DataSip)

**版本号：** v1.1
**更新日期：** 2025-12-04
**变更说明：** 基于架构审查，补充技术决策、数据结构约定、交互设计

---

## 0. 关键决策摘要 (Key Decisions)

| 决策项 | 选择 | 备注 |
|--------|------|------|
| 部署方式 | **全自托管** | VPS (4G+ RAM) + Docker Compose |
| 存储层 | **PostgreSQL (自托管)** | 不用 Supabase Cloud，直接用 PostgreSQL + pgvector |
| 编排层 | **N8N (自托管)** | Docker 部署 |
| LLM API | **混用策略** | 摘要/标签用便宜模型，推理用强模型 |
| 链接语义 | **资料+意图** | 发链接同时存 data_inbox 和推理 intention |
| MVP 数据源 | **手动 + 订阅** | 支持 RSS 和 YouTube 订阅自动抓取 |
| YouTube 抓取 | **含字幕/转录** | 需要提取视频文字内容 |
| 主动搜索 | **Phase 2** | MVP 不做 Google Search |

---

## 1. 项目背景与核心哲学 (Background & Philosophy)

### 1.1 核心痛点
传统的数据收集工具（如 RSS 阅读器、稀后读软件）是被动的"仓库"，缺乏"问题导向"。用户希望从单纯的信息囤积（Hoarding）转向**以解决问题为导向的知识生产**。

### 1.2 设计哲学：双循环矩阵 (The Dual-Loop Matrix)
系统运作基于两个维度的交叉：
1. **意图维度 (Intent Dimension):**
   - **显性意图 (Explicit):** 用户明确提出的疑问（如日记中的思考）
   - **隐性意图 (Implicit):** 用户行为折射出的兴趣（如分享链接意味着关注该话题）
2. **获取维度 (Acquisition Dimension):**
   - **存量 (Stock):** 已沉淀在数据库中的历史知识
   - **增量 (Flow):** 外部世界产生的新信息
3. **主动性维度 (Initiative):**
   - **被动订阅 (Passive):** 无论有没有意图，都在持续监听的信息流
   - **主动搜索 (Active):** 只有产生意图时，才触发的定向挖掘 *(Phase 2)*

---

## 2. 系统架构 (System Architecture)

### 2.1 部署架构图
```
┌─────────────────────────────────────────────────────────────────┐
│                         VPS (4G+ RAM)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  N8N        │  │ PostgreSQL  │  │  其他服务               │ │
│  │  (编排层)   │◄─┤ + pgvector  │  │  - Nginx (反向代理)     │ │
│  │  Port:5678  │  │  (存储层)   │  │  - youtube-dl/yt-dlp    │ │
│  └──────┬──────┘  └─────────────┘  └─────────────────────────┘ │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │ Webhook
          ▼
┌─────────────────┐         ┌─────────────────┐
│  Telegram API   │         │  LLM APIs       │
│  (用户交互)     │         │  - OpenAI       │
└─────────────────┘         │  - Anthropic    │
                            └─────────────────┘
```

### 2.2 双漏斗模型
```
   【左漏斗：意图工厂】                    【右漏斗：存量工厂】

   ┌──────────────────┐              ┌──────────────────┐
   │ 用户日记/文本    │              │ RSS 订阅源       │
   │ 用户分享的链接   │              │ YouTube 频道     │
   └────────┬─────────┘              │ 手动投喂内容     │
            │                        └────────┬─────────┘
            ▼                                 ▼
   ┌──────────────────┐              ┌──────────────────┐
   │   LLM 提取/推理  │              │   抓取 & 清洗    │
   │   Question       │              │   Summarize      │
   └────────┬─────────┘              └────────┬─────────┘
            │                                 │
            ▼                                 ▼
   ┌──────────────────┐              ┌──────────────────┐
   │   intentions     │◄────────────►│   data_inbox     │
   │   (意图库)       │  Match Loop  │   (存量库)       │
   └──────────────────┘              └──────────────────┘
```

---

## 3. 数据库设计 (Database Schema)

### 3.1 表：`intentions` (意图库)
```sql
CREATE TABLE intentions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 核心内容
    content         TEXT NOT NULL,              -- 意图的具体内容
    intent_type     TEXT DEFAULT 'explicit',    -- 'explicit' | 'implicit'
    source_type     TEXT NOT NULL,              -- 'text' | 'link_inference' | 'diary'
    source_context  TEXT,                       -- 来源描述
    source_data_id  UUID REFERENCES data_inbox(id), -- 若从链接推理而来

    -- 状态管理
    status          TEXT DEFAULT 'open',        -- 'open' | 'resolved' | 'archived'
    priority        INT DEFAULT 5,              -- 1-10, 数值越大越重要

    -- 解决信息
    resolved_at     TIMESTAMPTZ,
    solution_summary TEXT,                      -- AI 生成的解决摘要

    -- Phase 2: 向量搜索
    embedding       vector(1536)
);

CREATE INDEX idx_intentions_status ON intentions(status);
CREATE INDEX idx_intentions_created ON intentions(created_at DESC);
```

### 3.2 表：`data_inbox` (存量库)
```sql
CREATE TABLE data_inbox (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 基础信息
    url             TEXT UNIQUE,                -- 原始链接，唯一约束
    title           TEXT,
    content_type    TEXT NOT NULL,              -- 'blog' | 'youtube' | 'tweet' | 'manual'

    -- 核心资产：原始数据
    raw_content     JSONB NOT NULL,             -- 完整抓取结果，结构见下方约定

    -- AI 处理结果
    summary         TEXT,                       -- AI 摘要
    tags            TEXT[],                     -- 自动标签
    language        TEXT,                       -- 'zh' | 'en' | etc.

    -- 来源追踪
    source_id       UUID REFERENCES source_list(id), -- 来自哪个订阅源
    is_manual       BOOLEAN DEFAULT FALSE,      -- 是否手动投喂

    -- Phase 2: 向量搜索
    embedding       vector(1536)
);

CREATE INDEX idx_data_inbox_created ON data_inbox(created_at DESC);
CREATE INDEX idx_data_inbox_content_type ON data_inbox(content_type);
CREATE INDEX idx_data_inbox_tags ON data_inbox USING GIN(tags);
```

### 3.3 表：`intention_data_links` (关联表) **[新增]**
```sql
-- 记录"哪些数据帮助解决了哪个意图"
CREATE TABLE intention_data_links (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    intention_id    UUID NOT NULL REFERENCES intentions(id) ON DELETE CASCADE,
    data_id         UUID NOT NULL REFERENCES data_inbox(id) ON DELETE CASCADE,

    relevance_score FLOAT,                      -- LLM 判定的相关度 0-1
    is_solution     BOOLEAN DEFAULT FALSE,      -- 是否是最终解决方案
    user_feedback   TEXT,                       -- 'helpful' | 'not_helpful' | NULL

    UNIQUE(intention_id, data_id)
);
```

### 3.4 表：`source_list` (订阅源管理)
```sql
CREATE TABLE source_list (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 源信息
    name            TEXT NOT NULL,
    url             TEXT NOT NULL UNIQUE,       -- RSS URL 或 YouTube Channel ID
    source_type     TEXT NOT NULL,              -- 'rss' | 'youtube' | 'newsletter'

    -- 管理
    status          TEXT DEFAULT 'active',      -- 'active' | 'paused' | 'review_needed'
    weight          INT DEFAULT 5,              -- 1-10 权重
    fetch_interval  INT DEFAULT 60,             -- 抓取间隔（分钟）

    -- 追踪
    last_fetched_at TIMESTAMPTZ,
    last_item_at    TIMESTAMPTZ,                -- 最新条目的发布时间
    total_items     INT DEFAULT 0,              -- 累计抓取条目数
    matched_items   INT DEFAULT 0               -- 被匹配/引用的条目数 (用于源治理)
);
```

### 3.5 `raw_content` JSON 结构约定 **[新增]**

#### Blog/RSS 类型
```json
{
  "schema_version": "1.0",
  "fetched_at": "2025-12-04T10:00:00Z",
  "source": {
    "feed_url": "https://example.com/feed.xml",
    "site_name": "Example Blog"
  },
  "content": {
    "title": "Article Title",
    "url": "https://example.com/article",
    "author": "Author Name",
    "published_at": "2025-12-03T08:00:00Z",
    "html": "<article>...</article>",
    "text": "Plain text version...",
    "word_count": 1500
  },
  "meta": {
    "og_image": "https://...",
    "description": "..."
  }
}
```

#### YouTube 类型
```json
{
  "schema_version": "1.0",
  "fetched_at": "2025-12-04T10:00:00Z",
  "source": {
    "channel_id": "UC...",
    "channel_name": "Channel Name"
  },
  "content": {
    "video_id": "dQw4w9WgXcQ",
    "title": "Video Title",
    "url": "https://youtube.com/watch?v=...",
    "published_at": "2025-12-03T08:00:00Z",
    "duration_seconds": 600,
    "description": "Video description...",
    "transcript": {
      "language": "en",
      "text": "Full transcript text...",
      "segments": [
        {"start": 0.0, "end": 5.0, "text": "Hello..."}
      ]
    }
  },
  "meta": {
    "view_count": 10000,
    "like_count": 500,
    "thumbnail": "https://..."
  }
}
```

#### 手动投喂类型
```json
{
  "schema_version": "1.0",
  "fetched_at": "2025-12-04T10:00:00Z",
  "source": {
    "type": "manual",
    "telegram_message_id": 12345
  },
  "content": {
    "url": "https://...",
    "title": "Extracted or provided title",
    "html": "...",
    "text": "..."
  }
}
```

---

## 4. Telegram Bot 交互设计 **[新增]**

### 4.1 支持的消息类型

| 输入类型 | 处理方式 |
|----------|----------|
| 纯文本 | LLM 提取意图 → 存入 `intentions` |
| URL | 抓取内容 → 存入 `data_inbox` + 推理意图 → 存入 `intentions` |
| 图片/文件/语音 | MVP 阶段回复"暂不支持，请发送文字或链接" |

### 4.2 Bot 指令

| 指令 | 功能 | 示例 |
|------|------|------|
| `/start` | 初始化/欢迎信息 | |
| `/help` | 显示帮助 | |
| `/list` | 查看 Open 状态的意图 | 返回最近 10 条 |
| `/resolve <id>` | 手动标记意图为已解决 | `/resolve abc123` |
| `/sources` | 查看订阅源列表 | |
| `/add <url>` | 添加新的订阅源 | `/add https://blog.com/feed.xml` |
| `/pause <id>` | 暂停某订阅源 | |
| `/digest` | 获取今日摘要（匹配到的内容） | |
| `/stats` | 查看统计信息 | |

### 4.3 交互流程示例

**场景 1：用户发送文本**
```
用户: 如何在 Kubernetes 中实现零停机部署？

Bot: 已记录问题 ✓
     ID: int_7f3a
     状态: 待解决

     我会持续关注相关内容，找到答案后通知你。
```

**场景 2：用户发送链接**
```
用户: https://martinfowler.com/articles/microservices.html

Bot: 正在分析...

     ✓ 已保存文章
     标题: Microservices - Martin Fowler
     摘要: 本文介绍了微服务架构的核心概念...
     标签: #architecture #microservices #distributed-systems

     🔍 推测你关注: 如何设计微服务架构？
     已创建隐性意图 (ID: int_8b2c)
```

**场景 3：每日摘要推送**
```
Bot: 📬 今日知识摘要

     你的问题「如何实现零停机部署」可能已找到答案：

     📄 Zero-Downtime Deployments with Kubernetes
        来源: DevOps Weekly (RSS)
        相关度: 92%
        摘要: 本文详细介绍了使用 Rolling Update...

     回复 /resolve int_7f3a 标记为已解决
     回复 /more int_7f3a 查看更多相关内容
```

---

## 5. N8N Workflow 模块设计

### 模块 A：意图捕获 (Intention Capture)

#### A1: Text Handler
```
Trigger: Telegram Webhook (text message)
    ↓
Check: Telegram User ID in whitelist?
    ↓ Yes
LLM Call: Extract question/intention from text
    ↓
Insert: intentions table
    ↓
Reply: Confirmation message
```

#### A2: Link Handler
```
Trigger: Telegram Webhook (URL detected)
    ↓
Check: Telegram User ID in whitelist?
    ↓ Yes
Check: URL exists in data_inbox?
    ↓ No (新内容)
Fetch: Web scraping (Jina Reader / Firecrawl / 自建)
    ↓
LLM Call:
  1. Generate summary
  2. Extract tags
  3. Infer implicit intention
    ↓
Insert: data_inbox + intentions (if intention inferred)
    ↓
Reply: Summary + inferred intention
```

### 模块 B：数据采集 (Data Ingest)

#### B1: RSS Fetcher
```
Trigger: Cron (每小时)
    ↓
Query: source_list WHERE source_type='rss' AND status='active'
    ↓
For each source:
  ├─ Fetch RSS feed
  ├─ Parse items
  ├─ Filter: published_at > last_item_at
  ├─ For each new item:
  │   ├─ Check URL uniqueness
  │   ├─ Fetch full content
  │   ├─ LLM: Summarize + Tag
  │   └─ Insert data_inbox
  └─ Update source_list.last_fetched_at
```

#### B2: YouTube Fetcher
```
Trigger: Cron (每 2 小时)
    ↓
Query: source_list WHERE source_type='youtube' AND status='active'
    ↓
For each channel:
  ├─ YouTube API: Get recent videos
  ├─ Filter new videos
  ├─ For each video:
  │   ├─ Fetch transcript (youtube-transcript-api / yt-dlp)
  │   ├─ LLM: Summarize + Tag
  │   └─ Insert data_inbox
  └─ Update source_list
```

### 模块 C：核心匹配 (The Matcher)

#### C1: Daily Match
```
Trigger: Cron (每天 20:00)
    ↓
Query: intentions WHERE status='open'
    ↓
For each intention:
  ├─ Phase 1: Keyword search in data_inbox (last 7 days)
  ├─ Phase 2: Vector similarity search (when enabled)
  ├─ LLM: Evaluate relevance (0-1 score)
  ├─ If score > 0.7:
  │   ├─ Insert intention_data_links
  │   └─ Add to digest queue
  └─ Continue
    ↓
Compose: Daily digest message
    ↓
Send: Telegram notification
```

### 模块 D：Bot 指令处理 (Command Handler)
```
Trigger: Telegram Webhook (message starts with /)
    ↓
Parse: Extract command and arguments
    ↓
Switch:
  ├─ /list → Query intentions, format, reply
  ├─ /resolve <id> → Update intention status, reply
  ├─ /sources → Query source_list, format, reply
  ├─ /add <url> → Validate URL, insert source_list, reply
  ├─ /digest → Trigger C1 manually, reply
  └─ default → Reply help message
```

---

## 6. LLM 使用策略 **[新增]**

| 任务 | 推荐模型 | 原因 |
|------|----------|------|
| 文本摘要 | GPT-4o-mini / Claude Haiku | 高频任务，成本敏感 |
| 标签提取 | GPT-4o-mini | 结构化输出稳定 |
| 意图提取 | GPT-4o / Claude Sonnet | 需要理解上下文 |
| 隐性意图推理 | Claude Sonnet | 推理能力强 |
| 相关性判定 | GPT-4o | 需要精确判断 |
| 解决方案总结 | Claude Sonnet / GPT-4o | 综合能力 |

**Prompt 模板存储：** 建议在 N8N 中使用环境变量或专门的配置节点存储 Prompt 模板，便于迭代优化。

---

## 7. 安全与权限 **[新增]**

### 7.1 Telegram 白名单
```javascript
// N8N Function Node 示例
const ALLOWED_USER_IDS = [123456789, 987654321]; // 你的 Telegram User ID

const userId = $json.message.from.id;
if (!ALLOWED_USER_IDS.includes(userId)) {
  return []; // 不处理未授权用户
}
return [$json];
```

### 7.2 Secrets 管理
所有敏感信息存储在 N8N Credentials 或环境变量中：
- `TELEGRAM_BOT_TOKEN`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `POSTGRES_CONNECTION_STRING`
- `YOUTUBE_API_KEY` (可选)

### 7.3 网络安全
- N8N 通过 Nginx 反向代理，启用 HTTPS
- PostgreSQL 仅监听 localhost
- Webhook URL 使用随机路径而非可预测路径

---

## 8. 实施路线图 (Roadmap)

### Phase 1: MVP (2-3 周工作量)

**Week 1: 基础设施**
- [ ] VPS 环境准备，Docker Compose 配置
- [ ] PostgreSQL + pgvector 安装
- [ ] N8N 部署与基础配置
- [ ] Telegram Bot 创建与 Webhook 配置

**Week 2: 核心流程**
- [ ] 模块 A1: Text Handler
- [ ] 模块 A2: Link Handler
- [ ] 模块 D: 基础指令 (/start, /list, /help)
- [ ] 数据库表创建

**Week 3: 订阅与匹配**
- [ ] 模块 B1: RSS Fetcher
- [ ] 模块 B2: YouTube Fetcher (基础版)
- [ ] 模块 C1: Daily Match (关键词版)
- [ ] 每日摘要推送

### Phase 2: 智能化 (Phase 1 完成后)

- [ ] 启用 pgvector，配置 Embedding 生成
- [ ] 升级 C1 使用向量相似度搜索
- [ ] 添加主动搜索模块 (Google/DuckDuckGo)
- [ ] 用户反馈循环（helpful / not_helpful）

### Phase 3: 生态化 (Phase 2 完成后)

- [ ] 源治理模块 D1
- [ ] 人工投喂 → 自动订阅建议
- [ ] 交互式日报（按钮操作）
- [ ] 数据导出与备份自动化

---

## 9. 待解决/待验证事项

1. **YouTube 字幕获取**：需验证 `yt-dlp` 或 `youtube-transcript-api` 在 VPS 上的可用性
2. **网页抓取方案**：评估 Jina Reader API vs Firecrawl vs 自建 (Playwright)
3. **N8N 性能**：验证 4G 内存是否足够运行所有 Workflow
4. **LLM 成本估算**：基于预期使用频率估算月度 API 费用

---

## 附录 A：Docker Compose 参考配置

```yaml
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    environment:
      POSTGRES_USER: datasip
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: datasip
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"

  n8n:
    image: n8nio/n8n:latest
    restart: always
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${N8N_HOST}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=datasip
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
    ports:
      - "127.0.0.1:5678:5678"
    depends_on:
      - postgres

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./certs:/etc/nginx/certs
    depends_on:
      - n8n

volumes:
  postgres_data:
  n8n_data:
```

---

*文档结束。此文档应随项目迭代持续更新。*
