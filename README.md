# DataSip - 意图驱动的个人智能知识引擎

DataSip 是一个帮助你从"信息囤积"转向"问题驱动知识生产"的工具。

## 核心理念

- **意图驱动**: 记录你的问题和兴趣，系统帮你找答案
- **双向匹配**: 新问题匹配旧内容，新内容匹配旧问题
- **自动化**: RSS/YouTube 订阅自动抓取，定时匹配推送

## 架构

```
Cloudflare Workers (边缘层)
├── 接收 Telegram 消息
├── 抓取 RSS/网页内容
└── 转发到 N8N 处理
        ↓
N8N + PostgreSQL (VPS)
├── LLM 意图提取/摘要生成
├── 数据存储
└── 每日匹配推送
```

## 快速开始

### 1. 部署 VPS 服务

```bash
# 克隆仓库
git clone https://github.com/yourusername/datasip.git
cd datasip

# 配置环境变量
cp docker/.env.example docker/.env
# 编辑 docker/.env 填写密码

# 启动服务
cd docker && docker compose up -d

# 初始化数据库
docker exec datasip-postgres psql -U datasip -d datasip -f /docker-entrypoint-initdb.d/001-init-schema.sql
```

### 2. 部署 Cloudflare Workers

```bash
cd workers
npm install

# 配置 secrets
wrangler secret put TELEGRAM_BOT_TOKEN
wrangler secret put N8N_WEBHOOK_URL
wrangler secret put N8N_WEBHOOK_SECRET
wrangler secret put ALLOWED_USER_IDS

# 部署
wrangler deploy
```

### 3. 配置 Telegram Bot

1. 通过 @BotFather 创建 Bot
2. 设置 Webhook: `https://your-worker.workers.dev/telegram`
3. 获取你的 User ID (发消息给 @userinfobot)

### 4. 配置 N8N

1. 访问 N8N: `http://your-vps-ip:5678`
2. 导入 `n8n/workflows/` 下的 JSON 文件
3. 配置 Credentials (OpenAI API Key, PostgreSQL)
4. 激活 Workflows

## 使用方式

### Telegram 命令

| 命令 | 功能 |
|------|------|
| 发送文本 | 记录为问题/意图 |
| 发送链接 | 抓取内容并推理意图 |
| `/list` | 查看待解决问题 |
| `/resolve <id>` | 标记问题已解决 |
| `/sources` | 查看订阅源 |
| `/stats` | 查看统计 |

## 项目结构

```
datasip/
├── workers/          # Cloudflare Workers 代码
├── n8n/workflows/    # N8N Workflow JSON
├── prompts/          # LLM Prompt 模板
├── sql/              # 数据库脚本
├── docker/           # Docker 配置
└── docs/             # 文档
```

## 文档

- [项目宪章](PROJECT_CHARTER_v1.1.md) - 完整设计文档
- [架构决策](docs/adr/001-hybrid-architecture.md)
- [错误处理](docs/error-handling.md)
- [备份策略](docs/backup-strategy.md)
- [项目结构](docs/project-structure.md)

## 技术栈

- **边缘层**: Cloudflare Workers (TypeScript)
- **编排层**: N8N (自托管)
- **存储层**: PostgreSQL + pgvector
- **交互层**: Telegram Bot
- **智能层**: OpenAI / Anthropic API

## License

MIT
