# 项目结构与管理规范

**版本：** v1.0
**更新日期：** 2025-12-04

---

## 1. 项目目录结构

```
datasip/
│
├── PROJECT_CHARTER.md              # 项目宪章（核心文档）
├── TODO.md                         # 进度跟踪
├── README.md                       # 项目介绍（开源说明）
│
├── workers/                        # Cloudflare Workers 代码
│   ├── src/
│   │   ├── index.ts               # Worker 入口
│   │   ├── handlers/
│   │   │   ├── telegram.ts        # Telegram Webhook 处理
│   │   │   ├── rss.ts             # RSS 抓取
│   │   │   └── youtube.ts         # YouTube 抓取
│   │   ├── services/
│   │   │   ├── jina.ts            # Jina Reader 封装
│   │   │   └── n8n.ts             # N8N 通信
│   │   └── types/
│   │       └── index.ts           # TypeScript 类型
│   ├── wrangler.toml              # Cloudflare 配置
│   ├── package.json
│   └── tsconfig.json
│
├── n8n/                            # N8N Workflow 存档
│   └── workflows/
│       ├── A1-text-handler.json       # 文本处理
│       ├── A2-link-handler.json       # 链接处理
│       ├── B1-rss-processor.json      # RSS 数据处理
│       ├── B2-youtube-processor.json  # YouTube 数据处理
│       ├── C1-daily-matcher.json      # 每日匹配
│       └── D-bot-commands.json        # Bot 指令处理
│
├── prompts/                        # LLM Prompt 模板
│   ├── intention-extract.md       # 意图提取
│   ├── link-inference.md          # 链接意图推理
│   ├── summarize.md               # 内容摘要
│   ├── tagging.md                 # 自动标签
│   └── relevance-judge.md         # 相关性判定
│
├── sql/                            # 数据库脚本
│   ├── 001-init-schema.sql        # 初始化表结构
│   ├── 002-create-indexes.sql     # 创建索引
│   └── 003-enable-pgvector.sql    # 启用向量扩展 (Phase 2)
│
├── docker/                         # Docker 部署配置
│   ├── docker-compose.yml
│   ├── .env.example               # 环境变量模板
│   └── nginx/
│       └── nginx.conf
│
├── scripts/                        # 运维脚本
│   ├── backup-db.sh
│   ├── backup-n8n.sh
│   └── sync-backups.sh
│
├── docs/                           # 文档
│   ├── project-structure.md       # 本文档
│   ├── error-handling.md          # 错误处理机制
│   ├── backup-strategy.md         # 备份方案
│   └── adr/                       # 架构决策记录
│       └── 001-hybrid-architecture.md
│
└── .github/
    └── workflows/
        └── deploy-workers.yml     # Workers 自动部署
```

---

## 2. 各组件管理方式

### 2.1 Cloudflare Workers

| 项目 | 管理方式 |
|------|----------|
| 代码 | Git 版本控制，存于 `workers/` |
| 部署 | GitHub Actions 自动部署 |
| 密钥 | `wrangler secret put` 存于 Cloudflare |
| 配置 | `wrangler.toml` |

**开发流程：**
```
本地编辑 → git commit → git push → GitHub Actions → Cloudflare 部署
```

### 2.2 N8N Workflows

| 项目 | 管理方式 |
|------|----------|
| 编辑 | N8N Web UI (VPS 上) |
| 存档 | 导出 JSON，存于 `n8n/workflows/` |
| 密钥 | N8N Credentials (不导出，需手动配置) |
| 部署 | Docker Compose |

**开发流程：**
```
N8N Web UI 编辑 → 测试通过 → 导出 JSON → git commit → git push
```

**导出方法：**
1. N8N UI → 打开 Workflow
2. 右上角菜单 → Download
3. 保存到 `n8n/workflows/` 目录
4. commit 到 Git

### 2.3 Prompt 模板

| 项目 | 管理方式 |
|------|----------|
| 存储 | Markdown 文件，存于 `prompts/` |
| 使用 | N8N 中引用或直接复制 |
| 版本 | Git 版本控制 |

**设计原则：**
- 每个 Prompt 单独一个文件
- 包含用途说明、输入输出格式、示例
- 便于用户根据自己需求修改

### 2.4 数据库 Schema

| 项目 | 管理方式 |
|------|----------|
| 存储 | SQL 文件，存于 `sql/` |
| 执行 | 手动或通过脚本 |
| 迁移 | 按序号命名，增量执行 |

---

## 3. 密钥管理策略

### 3.1 密钥分布

| 密钥 | 存储位置 | 原因 |
|------|----------|------|
| `TELEGRAM_BOT_TOKEN` | Cloudflare Secrets + N8N Credentials | 两边都要用 |
| `OPENAI_API_KEY` | N8N Credentials | 只在 N8N 调用 LLM |
| `ANTHROPIC_API_KEY` | N8N Credentials | 只在 N8N 调用 LLM |
| `N8N_WEBHOOK_SECRET` | Cloudflare Secrets + N8N 环境变量 | Worker→N8N 鉴权 |
| `POSTGRES_PASSWORD` | Docker .env | 本地数据库 |
| `CLOUDFLARE_API_TOKEN` | GitHub Secrets | 用于 Actions 部署 |

### 3.2 环境变量模板

项目提供 `.env.example`，用户复制为 `.env` 后填写：

```bash
# docker/.env.example

# PostgreSQL
POSTGRES_USER=datasip
POSTGRES_PASSWORD=your_password_here
POSTGRES_DB=datasip

# N8N
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_password_here
N8N_ENCRYPTION_KEY=your_random_key_here
N8N_HOST=n8n.yourdomain.com
WEBHOOK_SECRET=your_webhook_secret_here

# 注意：LLM API Keys 在 N8N Credentials 中配置，不在此处
```

---

## 4. 开源部署指南

### 4.1 用户部署流程

```
1. Fork 仓库
      ↓
2. 配置 Cloudflare
   - 创建 API Token
   - 添加 GitHub Secret: CLOUDFLARE_API_TOKEN
   - 设置 Workers Secrets: wrangler secret put ...
      ↓
3. 部署 Workers
   - Push 触发 GitHub Actions
   - 或手动: wrangler deploy
      ↓
4. 部署 VPS
   - 复制 docker/.env.example → docker/.env
   - 填写配置
   - docker-compose up -d
      ↓
5. 初始化数据库
   - 执行 sql/*.sql
      ↓
6. 配置 N8N
   - 访问 N8N Web UI
   - 导入 n8n/workflows/*.json
   - 配置 Credentials (API Keys)
   - 修改 Webhook URL
      ↓
7. 配置 Telegram Bot
   - @BotFather 创建 Bot
   - 设置 Webhook 指向 Worker
      ↓
8. 定制 Prompts (可选)
   - 修改 prompts/*.md
   - 在 N8N 中更新
      ↓
9. 完成！
```

### 4.2 用户需要修改的内容

| 类别 | 需要修改 | 说明 |
|------|----------|------|
| 密钥 | 所有 API Keys | 必须 |
| 域名 | Webhook URL | 必须 |
| Prompts | `prompts/*.md` | 可选，按需定制 |
| 订阅源 | N8N 或数据库 | 可选，添加自己的 RSS/YouTube |
| Telegram ID | 白名单 | 必须，改成自己的 |

---

## 5. 版本发布规范

### 5.1 版本号

采用语义化版本：`MAJOR.MINOR.PATCH`

- MAJOR: 不兼容的架构变更
- MINOR: 新功能（向后兼容）
- PATCH: Bug 修复

### 5.2 发布检查清单

- [ ] 所有 N8N Workflows 已导出为最新 JSON
- [ ] Prompts 已更新
- [ ] SQL 迁移脚本完整
- [ ] `.env.example` 包含所有必要变量
- [ ] README 更新
- [ ] CHANGELOG 更新

### 5.3 Git 分支策略

```
main        # 稳定版本，可直接部署
  └── dev   # 开发分支，功能开发
       └── feature/xxx  # 具体功能分支
```

---

## 6. 协作开发规范

### 6.1 Commit 信息格式

```
<type>: <description>

类型:
- feat: 新功能
- fix: Bug 修复
- docs: 文档更新
- refactor: 重构
- chore: 构建/工具变更
```

示例：
```
feat: add YouTube transcript fetching in Worker
fix: handle RSS parsing error for empty feeds
docs: update deployment guide
```

### 6.2 N8N Workflow 命名规范

```
<模块号>-<功能描述>.json

示例:
A1-text-handler.json
B1-rss-processor.json
C1-daily-matcher.json
```

---

## 7. 架构关系图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            GitHub Repository                            │
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │  workers/   │  │    n8n/     │  │  prompts/   │  │    sql/     │   │
│  │  (代码)     │  │  (JSON)     │  │  (模板)     │  │  (Schema)   │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
└─────────┼────────────────┼────────────────┼────────────────┼───────────┘
          │                │                │                │
          ▼                │                │                │
┌─────────────────┐        │                │                │
│   Cloudflare    │        │                │                │
│    Workers      │        │                │                │
│  (自动部署)     │        │                │                │
└────────┬────────┘        │                │                │
         │                 ▼                ▼                ▼
         │        ┌─────────────────────────────────────────────┐
         │        │                    VPS                       │
         │        │  ┌─────────────┐  ┌─────────────────────┐   │
         │        │  │    N8N      │  │    PostgreSQL       │   │
         └───────►│  │  (导入JSON) │  │    (执行SQL)        │   │
                  │  │  (引用Prompt)│  │                     │   │
                  │  └─────────────┘  └─────────────────────┘   │
                  └─────────────────────────────────────────────┘
```

---

*此文档定义了项目的组织结构和管理规范，便于协作开发和开源维护。*
