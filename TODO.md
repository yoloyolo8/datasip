# DataSip 项目进度跟踪

**项目名称：** 意图驱动的个人智能知识引擎
**开始日期：** 2025-12-04
**当前阶段：** Phase 1 - MVP

---

## 进度概览

| 阶段 | 状态 | 完成度 |
|------|------|--------|
| Phase 1: MVP | 🔄 进行中 | 0% |
| Phase 2: 智能化 | ⏳ 等待 | - |
| Phase 3: 生态化 | ⏳ 等待 | - |

---

## Phase 1: MVP 任务清单

### 1.1 基础设施 (Infrastructure)

| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| VPS 环境检查与准备 | ⬜ TODO | | 确认 Docker、Docker Compose 已安装 |
| 创建项目目录结构 | ⬜ TODO | | `/root/datasip/` 下的子目录 |
| 编写 `docker-compose.yml` | ⬜ TODO | | PostgreSQL + N8N + Nginx |
| 配置 `.env` 文件 | ⬜ TODO | | 所有环境变量 |
| PostgreSQL 容器启动 | ⬜ TODO | | 含 pgvector 扩展 |
| N8N 容器启动 | ⬜ TODO | | |
| Nginx 反向代理配置 | ⬜ TODO | | HTTPS 证书 |
| 创建 Telegram Bot | ⬜ TODO | | 通过 @BotFather |
| 配置 Webhook URL | ⬜ TODO | | N8N Webhook 节点 |

### 1.2 数据库 (Database)

| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| 启用 pgvector 扩展 | ⬜ TODO | | `CREATE EXTENSION vector;` |
| 创建 `intentions` 表 | ⬜ TODO | | |
| 创建 `data_inbox` 表 | ⬜ TODO | | |
| 创建 `source_list` 表 | ⬜ TODO | | |
| 创建 `intention_data_links` 表 | ⬜ TODO | | |
| 创建 `error_logs` 表 | ⬜ TODO | | |
| 创建 `pending_tasks` 表 | ⬜ TODO | | |
| 创建必要索引 | ⬜ TODO | | |
| 验证表结构 | ⬜ TODO | | |

### 1.3 N8N Workflows

#### 模块 A: 意图捕获
| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| A0: Telegram Webhook 基础节点 | ⬜ TODO | | 接收所有消息 |
| A0: 白名单校验节点 | ⬜ TODO | | 过滤未授权用户 |
| A1: Text Handler - LLM 意图提取 | ⬜ TODO | | 调用 OpenAI/Claude |
| A1: Text Handler - 写入 intentions | ⬜ TODO | | |
| A1: Text Handler - 回复确认消息 | ⬜ TODO | | |
| A2: Link Handler - URL 检测 | ⬜ TODO | | |
| A2: Link Handler - 去重检查 | ⬜ TODO | | |
| A2: Link Handler - 网页抓取 (Jina) | ⬜ TODO | | |
| A2: Link Handler - LLM 摘要+标签+意图推理 | ⬜ TODO | | |
| A2: Link Handler - 写入 data_inbox | ⬜ TODO | | |
| A2: Link Handler - 写入 intentions | ⬜ TODO | | |
| A2: Link Handler - 回复摘要消息 | ⬜ TODO | | |

#### 模块 B: 数据采集
| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| B1: RSS Fetcher - Cron 触发器 | ⬜ TODO | | 每小时 |
| B1: RSS Fetcher - 读取 source_list | ⬜ TODO | | |
| B1: RSS Fetcher - 抓取 RSS | ⬜ TODO | | N8N RSS 节点 |
| B1: RSS Fetcher - 过滤新条目 | ⬜ TODO | | |
| B1: RSS Fetcher - 抓取全文 | ⬜ TODO | | |
| B1: RSS Fetcher - LLM 处理 | ⬜ TODO | | |
| B1: RSS Fetcher - 写入 data_inbox | ⬜ TODO | | |
| B2: YouTube Fetcher - Cron 触发器 | ⬜ TODO | | 每 2 小时 |
| B2: YouTube Fetcher - 获取频道视频列表 | ⬜ TODO | | YouTube API |
| B2: YouTube Fetcher - 获取字幕/转录 | ⬜ TODO | | yt-dlp 或 API |
| B2: YouTube Fetcher - LLM 处理 | ⬜ TODO | | |
| B2: YouTube Fetcher - 写入 data_inbox | ⬜ TODO | | |

#### 模块 C: 核心匹配
| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| C1: Daily Match - Cron 触发器 | ⬜ TODO | | 每天 20:00 |
| C1: Daily Match - 读取 open intentions | ⬜ TODO | | |
| C1: Daily Match - 关键词搜索 | ⬜ TODO | | Phase 1 用关键词 |
| C1: Daily Match - LLM 相关性判定 | ⬜ TODO | | |
| C1: Daily Match - 写入关联 | ⬜ TODO | | |
| C1: Daily Match - 生成日报 | ⬜ TODO | | |
| C1: Daily Match - 推送 Telegram | ⬜ TODO | | |

#### 模块 D: Bot 指令
| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| D: /start 命令 | ⬜ TODO | | |
| D: /help 命令 | ⬜ TODO | | |
| D: /list 命令 | ⬜ TODO | | 列出 open intentions |
| D: /resolve 命令 | ⬜ TODO | | 标记 intention 为已解决 |
| D: /sources 命令 | ⬜ TODO | | 列出订阅源 |
| D: /add 命令 | ⬜ TODO | | 添加订阅源 |
| D: /digest 命令 | ⬜ TODO | | 手动触发日报 |

### 1.4 运维 (Operations)

| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| 配置数据库自动备份脚本 | ⬜ TODO | | Cron |
| 配置 N8N 备份脚本 | ⬜ TODO | | |
| 配置远程备份同步 | ⬜ TODO | | Rclone |
| 设置全局错误处理 Workflow | ⬜ TODO | | |
| 设置健康检查 Workflow | ⬜ TODO | | |
| 项目文件 Git 初始化 | ⬜ TODO | | |

### 1.5 测试 (Testing)

| 任务 | 状态 | 负责 | 备注 |
|------|------|------|------|
| 测试：发送文本消息 | ⬜ TODO | | |
| 测试：发送 URL | ⬜ TODO | | |
| 测试：RSS 抓取 | ⬜ TODO | | |
| 测试：YouTube 抓取 | ⬜ TODO | | |
| 测试：每日匹配 | ⬜ TODO | | |
| 测试：各 Bot 指令 | ⬜ TODO | | |
| 端到端流程测试 | ⬜ TODO | | |

---

## Phase 2: 智能化 (待 Phase 1 完成)

| 任务 | 状态 | 备注 |
|------|------|------|
| 配置 Embedding 生成 | ⏳ | OpenAI text-embedding-3-small |
| 为 intentions 生成 embedding | ⏳ | |
| 为 data_inbox 生成 embedding | ⏳ | |
| 升级 C1 使用向量相似度 | ⏳ | |
| 添加主动搜索模块 (B2-Search) | ⏳ | DuckDuckGo 或 Google |
| 用户反馈循环 | ⏳ | helpful / not_helpful |

---

## Phase 3: 生态化 (待 Phase 2 完成)

| 任务 | 状态 | 备注 |
|------|------|------|
| 源治理模块 D1 | ⏳ | 统计引用率，建议删除低质源 |
| 人工投喂 → 订阅建议 | ⏳ | |
| 交互式日报（按钮） | ⏳ | Telegram Inline Keyboard |
| 数据导出功能 | ⏳ | |
| 仪表盘/统计页面 | ⏳ | 可选 |

---

## 待解决问题 (Blockers & Questions)

| 问题 | 状态 | 备注 |
|------|------|------|
| YouTube 字幕获取方案验证 | ⬜ | yt-dlp vs youtube-transcript-api |
| VPS 是否已安装 Docker | ⬜ | 需确认 |
| 域名/HTTPS 证书 | ⬜ | 是否有域名？用 Let's Encrypt? |

---

## 变更日志 (Changelog)

| 日期 | 变更内容 |
|------|----------|
| 2025-12-04 | 创建项目文档 v1.0 |
| 2025-12-04 | 完善文档至 v1.1，添加详细设计 |
| 2025-12-04 | 添加 error-handling.md, backup-strategy.md |
| 2025-12-04 | 创建 TODO.md 跟踪进度 |

---

## 状态图例

- ⬜ TODO - 待开始
- 🔄 进行中 - 正在进行
- ✅ 完成 - 已完成
- ⏳ 等待 - 等待前置任务
- ❌ 阻塞 - 遇到问题

---

*此文档随项目进展持续更新。每完成一项任务，请将状态改为 ✅。*
