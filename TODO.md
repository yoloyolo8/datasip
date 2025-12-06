# DataSip 项目进度跟踪

**项目名称：** 意图驱动的个人智能知识引擎
**开始日期：** 2025-12-04
**当前阶段：** Phase 1 - MVP

---

## 进度概览

| 阶段 | 状态 | 完成度 |
|------|------|--------|
| Phase 1: MVP | 🔄 进行中 | 65% |
| Phase 2: 智能化 | ⏳ 等待 | - |
| Phase 3: 生态化 | ⏳ 等待 | - |

---

## Phase 1: MVP 任务清单

### 1.1 基础设施 (Infrastructure)

| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| VPS 环境检查与准备 | ✅ 完成 | 2025-12-04 | Docker、Docker Compose 已确认 |
| 创建项目目录结构 | ✅ 完成 | 2025-12-04 | `/root/datasip/` 下的子目录 |
| 编写 `docker-compose.yml` | ✅ 完成 | 2025-12-04 | PostgreSQL + N8N |
| 配置 `.env` 文件 | ✅ 完成 | 2025-12-06 | 统一到 `/root/datasip/docker/.env` |
| PostgreSQL 容器启动 | ✅ 完成 | 2025-12-04 | 含 pgvector 扩展 |
| N8N 容器启动 | ✅ 完成 | 2025-12-04 | |
| Nginx 反向代理配置 | ⏳ 待定 | - | 暂不需要（使用域名直接访问） |
| 创建 Telegram Bot | ✅ 完成 | 2025-12-05 | Bot: @datasip_bot (8224374078) |
| 配置 Telegram Webhook URL | ✅ 完成 | 2025-12-06 | Workers: datasip.hashyolo123.workers.dev |
| 部署 Cloudflare Workers | ✅ 完成 | 2025-12-06 | 替代原计划的直接 Webhook |
| 配置 DNS (n8n.yolonote.xyz) | ✅ 完成 | 2025-12-06 | 解决 Workers 访问 N8N 问题 |

### 1.2 数据库 (Database)

| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| 启用 pgvector 扩展 | ✅ 完成 | 2025-12-04 | `CREATE EXTENSION vector;` |
| 创建 `intentions` 表 | ✅ 完成 | 2025-12-04 | 已有 9 条记录 |
| 创建 `data_inbox` 表 | ✅ 完成 | 2025-12-04 | 已有 2 条记录 |
| 创建 `source_list` 表 | ✅ 完成 | 2025-12-04 | |
| 创建 `intention_data_links` 表 | ✅ 完成 | 2025-12-04 | |
| 创建 `error_logs` 表 | ✅ 完成 | 2025-12-04 | |
| 创建 `pending_tasks` 表 | ✅ 完成 | 2025-12-04 | |
| 创建必要索引 | ✅ 完成 | 2025-12-04 | |
| 验证表结构 | ✅ 完成 | 2025-12-05 | 所有表结构正常 |

### 1.3 N8N Workflows

#### 模块 A: 意图捕获
| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| A0: Telegram Webhook 基础节点 | ✅ 完成 | 2025-12-05 | 通过 Workers 实现 |
| A0: 白名单校验节点 | ✅ 完成 | 2025-12-06 | Workers 中实现，使用 ALLOWED_USER_IDS |
| A1: Text Handler - LLM 意图提取 | ✅ 完成 | 2025-12-05 | OpenRouter/GPT-4o-mini |
| A1: Text Handler - 写入 intentions | ✅ 完成 | 2025-12-05 | 已验证，9 条记录 |
| A1: Text Handler - 回复确认消息 | ⏳ 待实现 | - | N8N 未配置回复节点 |
| A2: Link Handler - URL 检测 | ✅ 完成 | 2025-12-05 | Workers 中实现 |
| A2: Link Handler - 去重检查 | ⏳ 待实现 | - | 未配置 |
| A2: Link Handler - 网页抓取 (Jina) | 🔄 部分完成 | 2025-12-05 | Jina Reader 速率限制问题 |
| A2: Link Handler - LLM 摘要+标签+意图推理 | ✅ 完成 | 2025-12-05 | OpenRouter/GPT-4o-mini |
| A2: Link Handler - 写入 data_inbox | ✅ 完成 | 2025-12-05 | 已验证，2 条记录 |
| A2: Link Handler - 写入 intentions | ✅ 完成 | 2025-12-05 | 推测意图已保存 |
| A2: Link Handler - 回复摘要消息 | ✅ 完成 | 2025-12-05 | 已配置 Telegram 回复节点 |

#### 模块 B: 数据采集
| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| B1: RSS Fetcher - Cron 触发器 | ✅ 完成 | 2025-12-06 | Workers cron: 0 * * * * |
| B1: RSS Fetcher - 读取 source_list | ⏳ 待实现 | - | |
| B1: RSS Fetcher - 抓取 RSS | ⏳ 待实现 | - | N8N RSS 节点 |
| B1: RSS Fetcher - 过滤新条目 | ⏳ 待实现 | - | |
| B1: RSS Fetcher - 抓取全文 | ⏳ 待实现 | - | |
| B1: RSS Fetcher - LLM 处理 | ⏳ 待实现 | - | |
| B1: RSS Fetcher - 写入 data_inbox | ⏳ 待实现 | - | |
| B2: YouTube Fetcher - Cron 触发器 | ✅ 完成 | 2025-12-06 | Workers cron: 0 */2 * * * |
| B2: YouTube Fetcher - 获取频道视频列表 | ⏳ 待实现 | - | YouTube API |
| B2: YouTube Fetcher - 获取字幕/转录 | ⏳ 待实现 | - | yt-dlp 或 API |
| B2: YouTube Fetcher - LLM 处理 | ⏳ 待实现 | - | |
| B2: YouTube Fetcher - 写入 data_inbox | ⏳ 待实现 | - | |

#### 模块 C: 核心匹配
| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| C1: Daily Match - Cron 触发器 | ✅ 完成 | 2025-12-06 | Workers cron: 0 20 * * * |
| C1: Daily Match - 读取 open intentions | 🔄 部分完成 | 2025-12-05 | N8N workflow 已配置，但有错误 |
| C1: Daily Match - 关键词搜索 | 🔄 部分完成 | 2025-12-05 | N8N workflow 已配置，但有错误 |
| C1: Daily Match - LLM 相关性判定 | 🔄 部分完成 | 2025-12-05 | N8N workflow 已配置，但有错误 |
| C1: Daily Match - 写入关联 | ⏳ 待实现 | - | |
| C1: Daily Match - 生成日报 | ⏳ 待实现 | - | |
| C1: Daily Match - 推送 Telegram | ⏳ 待实现 | - | |

#### 模块 D: Bot 指令
| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| D: /start 命令 | 🔄 部分完成 | 2025-12-05 | Workers 中已实现基础版本 |
| D: /help 命令 | 🔄 部分完成 | 2025-12-05 | Workers 中已实现基础版本 |
| D: /list 命令 | ⏳ 待实现 | - | 列出 open intentions |
| D: /resolve 命令 | ⏳ 待实现 | - | 标记 intention 为已解决 |
| D: /sources 命令 | ⏳ 待实现 | - | 列出订阅源 |
| D: /add 命令 | ⏳ 待实现 | - | 添加订阅源 |
| D: /digest 命令 | ⏳ 待实现 | - | 手动触发日报 |

### 1.4 运维 (Operations)

| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| 配置数据库自动备份脚本 | ⏳ 待实现 | - | Cron |
| 配置 N8N 备份脚本 | ⏳ 待实现 | - | |
| 配置远程备份同步 | ⏳ 待实现 | - | Rclone |
| 设置全局错误处理 Workflow | ⏳ 待实现 | - | |
| 设置健康检查 Workflow | ⏳ 待实现 | - | |
| 项目文件 Git 初始化 | ✅ 完成 | 2025-12-04 | 已初始化 Git 仓库 |
| **整理敏感数据与 Git 安全配置** | ⬜ TODO | - | **配置 .gitignore，防止私钥泄露** |

### 1.5 测试 (Testing)

| 任务 | 状态 | 完成时间 | 备注 |
|------|------|---------|------|
| 测试：发送文本消息 | ✅ 完成 | 2025-12-06 | 已验证完整流程，数据正常入库 |
| 测试：发送 URL | 🔄 部分完成 | 2025-12-05 | Jina Reader 速率限制问题 |
| 测试：RSS 抓取 | ⏳ 待实现 | - | |
| 测试：YouTube 抓取 | ⏳ 待实现 | - | |
| 测试：每日匹配 | ⏳ 待实现 | - | C1 workflow 有错误 |
| 测试：各 Bot 指令 | 🔄 部分完成 | 2025-12-05 | /start 和 /help 已测试 |
| 端到端流程测试 | ✅ 完成 | 2025-12-06 | Telegram → Workers → N8N → PostgreSQL |

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

## 当前重点任务 (Current Focus - 2025-12-06)

### 🔴 高优先级（必须完成）

1. **整理敏感数据与 Git 安全配置**
   - 配置 `.gitignore` 防止私钥、token 泄露到 GitHub
   - 创建 `.env.example` 模板文件
   - 审查代码中的硬编码敏感信息
   - **状态**: ⬜ TODO

2. **解决 Jina Reader 速率限制问题**
   - URL 抓取功能受限（429 错误）
   - 可选方案：重试逻辑、备用 API、自建爬虫
   - **状态**: ⬜ TODO

### 🟡 中优先级（尽快完成）

3. **调试 C1 Daily Matcher Workflow**
   - 查看执行错误日志
   - 修复 workflow 问题
   - **状态**: ⬜ TODO

4. **完善 A1 Text Handler 回复功能**
   - 添加 Telegram 回复确认消息节点
   - **状态**: ⬜ TODO

### 🟢 低优先级（可选）

5. **实现 Bot 高级指令**
   - `/list`, `/resolve`, `/sources`, `/add`, `/digest`
   - **状态**: ⏳ 待定

6. **实现 RSS/YouTube 数据采集**
   - B1: RSS Fetcher 完整实现
   - B2: YouTube Fetcher 完整实现
   - **状态**: ⏳ 待定

---

## 待解决问题 (Blockers & Questions)

| 问题 | 状态 | 解决时间 | 备注 |
|------|------|---------|------|
| YouTube 字幕获取方案验证 | ⏳ 待验证 | - | yt-dlp vs youtube-transcript-api |
| VPS 是否已安装 Docker | ✅ 已确认 | 2025-12-04 | 已安装 Docker 和 Docker Compose |
| 域名/HTTPS 证书 | ✅ 已解决 | 2025-12-06 | 使用 n8n.yolonote.xyz，DNS Only 模式 |
| Jina Reader 速率限制 (429) | ❌ 阻塞中 | - | URL 抓取功能受限 |
| Cloudflare Workers 访问 VPS IP 被拦截 | ✅ 已解决 | 2025-12-06 | 使用域名访问替代 IP |

---

## 变更日志 (Changelog)

| 日期 | 变更内容 |
|------|----------|
| 2025-12-04 | 创建项目文档 v1.0 |
| 2025-12-04 | 完善文档至 v1.1，添加详细设计 |
| 2025-12-04 | 添加 error-handling.md, backup-strategy.md |
| 2025-12-04 | 创建 TODO.md 跟踪进度 |
| 2025-12-04 | 完成基础设施搭建（Docker, PostgreSQL, N8N） |
| 2025-12-04 | 完成数据库表结构创建 |
| 2025-12-05 | 完成 N8N A1/A2 workflows 配置和测试 |
| 2025-12-05 | 切换 LLM 模型从 Gemini 到 GPT-4o-mini (OpenRouter) |
| 2025-12-06 | 完成 Cloudflare Workers 部署 |
| 2025-12-06 | 配置 DNS (n8n.yolonote.xyz) 解决网络访问问题 |
| 2025-12-06 | 统一环境配置文件到 /root/datasip/docker/.env |
| 2025-12-06 | 完成端到端测试（文本消息流程验证成功） |
| 2025-12-06 | 更新 TODO.md v2.0，添加完成时间戳 |
| 2025-12-06 | 生成会议纪要 (session-summary-2025-12-06.md) |

---

## 状态图例

- ⬜ TODO - 待开始
- 🔄 进行中 - 正在进行
- ✅ 完成 - 已完成
- ⏳ 等待 - 等待前置任务
- ❌ 阻塞 - 遇到问题

---

*此文档随项目进展持续更新。每完成一项任务，请将状态改为 ✅。*
