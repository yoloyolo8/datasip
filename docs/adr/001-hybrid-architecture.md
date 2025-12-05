# ADR-001: 混合架构决策 (Cloudflare Workers + N8N + 自托管 PostgreSQL)

**状态：** 已采纳
**日期：** 2025-12-04
**决策者：** 项目所有者

---

## 背景 (Context)

在设计 DataSip 系统的部署架构时，我们需要在以下几个方案中做出选择：

| 方案 | 编排层 | 存储层 |
|------|--------|--------|
| A: 全自托管 | N8N (Docker) | PostgreSQL (Docker) |
| B: Serverless | Cloudflare Workers | Supabase Cloud |
| C: 混合云 | N8N Cloud | Supabase Cloud |
| D: 混合架构 | Cloudflare Workers + N8N | PostgreSQL (自托管) |

## 考量因素 (Considerations)

### 1. 技术约束
- 已有 VPS (4G+ RAM)，有固定公网 IP
- Phase 2 需要向量搜索 (pgvector)
- 需要调用 LLM API（执行时间较长）
- 需要抓取 RSS、YouTube、网页内容

### 2. 优先级排序
经讨论，项目优先考虑：
1. **可视化编排**：希望用 N8N 拖拽配置复杂逻辑
2. **数据自主权**：数据存储在自己的服务器
3. **边缘加速**：利用 Cloudflare 的全球边缘网络加速数据采集
4. **低成本**：充分利用免费额度

### 3. 各方案分析

#### 方案 A: 全自托管
- ✅ 完全控制
- ✅ 无执行时间限制
- ❌ 单点故障
- ❌ 国际网络较慢

#### 方案 B: 纯 Serverless
- ✅ 零运维
- ✅ 边缘加速
- ❌ Cloudflare Workers CPU 时间限制（LLM 调用困难）
- ❌ 需要写大量代码，无可视化

#### 方案 C: 混合云
- ✅ 两边托管，省心
- ❌ 成本高 (~$45/月)

#### 方案 D: 混合架构 (最终选择)
- ✅ Cloudflare 边缘加速数据采集
- ✅ N8N 可视化编排复杂逻辑
- ✅ 数据在自己 VPS 上
- ✅ 成本低（主要是 VPS 费用 + LLM API）
- ⚠️ 需要维护两个系统的协作

## 决策 (Decision)

**采用方案 D：混合架构**

架构图：

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Cloudflare Workers (边缘层)                      │
│                                                                     │
│  【入口处理】                                                        │
│  ├── 接收 Telegram Webhook                                          │
│  ├── 白名单校验                                                      │
│  ├── 快速回复 "收到，处理中..."                                       │
│  └── 转发消息到 N8N                                                  │
│                                                                     │
│  【数据采集】(Cron Triggers)                                         │
│  ├── RSS 抓取 (每小时)                                               │
│  ├── YouTube 元数据获取                                              │
│  └── 网页内容抓取 (Jina Reader)                                      │
│                                                                     │
│  【出口处理】(可选)                                                   │
│  └── 转发 N8N 的回复到 Telegram                                      │
│                                                                     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        VPS (N8N + PostgreSQL)                        │
│                                                                     │
│  【核心处理】                                                        │
│  ├── LLM 调用 (意图提取、摘要生成、相关性判定)                         │
│  ├── 复杂业务逻辑编排                                                │
│  └── 数据库读写                                                      │
│                                                                     │
│  【存储】                                                            │
│  └── PostgreSQL + pgvector                                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 职责分配 (Responsibility Assignment)

| 任务 | 执行位置 | 原因 |
|------|----------|------|
| 接收 Telegram Webhook | **Worker** | 快速响应，边缘近 |
| 白名单校验 | **Worker** | 简单逻辑，提前拦截非法请求 |
| 快速回复"收到" | **Worker** | 提升用户体验 |
| 抓取 RSS Feed | **Worker** | I/O 密集型，边缘网络快 |
| 抓取网页内容 (Jina) | **Worker** | I/O 密集型 |
| 获取 YouTube 元数据 | **Worker** | API 调用，I/O 密集型 |
| 获取 YouTube 字幕 | **Worker** | API 调用 |
| LLM 意图提取 | **N8N** | 需要较长执行时间 |
| LLM 摘要生成 | **N8N** | 需要较长执行时间 |
| LLM 相关性判定 | **N8N** | 复杂逻辑 |
| 数据库读写 | **N8N** | 直接访问 PostgreSQL |
| 每日匹配逻辑 | **N8N** | 复杂业务逻辑 |
| 发送 Telegram 回复 | **Worker 或 N8N** | 均可，视情况选择 |

## 数据流设计

### 场景 1：用户发送文本消息

```
用户 → Telegram → Worker
                    │
                    ├─ 1. 校验白名单 ✓
                    ├─ 2. 回复 "收到，正在分析..."
                    └─ 3. POST 到 N8N Webhook
                              │
                              ▼
                           N8N
                            │
                            ├─ 4. 调用 LLM 提取意图
                            ├─ 5. 写入 PostgreSQL (intentions)
                            └─ 6. 调用 Telegram API 发送结果
```

### 场景 2：用户发送链接

```
用户 → Telegram → Worker
                    │
                    ├─ 1. 校验白名单 ✓
                    ├─ 2. 回复 "收到，正在抓取..."
                    ├─ 3. 调用 Jina Reader 抓取网页内容
                    └─ 4. POST 到 N8N Webhook (含抓取结果)
                              │
                              ▼
                           N8N
                            │
                            ├─ 5. 调用 LLM 生成摘要 + 推理意图
                            ├─ 6. 写入 PostgreSQL
                            └─ 7. 调用 Telegram API 发送结果
```

### 场景 3：定时 RSS 抓取

```
Cron (每小时) → Worker
                  │
                  ├─ 1. 获取订阅源列表 (KV 或环境变量)
                  ├─ 2. 遍历每个 RSS 源
                  │     ├─ fetch RSS XML
                  │     ├─ 解析新条目
                  │     └─ 对每个新条目: POST 到 N8N
                  └─ (完成)
                              │
                              ▼
                           N8N (收到多个 Webhook 请求)
                            │
                            ├─ 调用 LLM 生成摘要
                            └─ 写入 PostgreSQL (data_inbox)
```

## 安全设计

### Worker → N8N 通信安全

```javascript
// Worker 发送请求时带上 secret
const response = await fetch(env.N8N_WEBHOOK_URL, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Webhook-Secret': env.WEBHOOK_SECRET
  },
  body: JSON.stringify(payload)
});
```

```javascript
// N8N 入口节点校验 secret
if ($json.headers['x-webhook-secret'] !== process.env.WEBHOOK_SECRET) {
  return []; // 拒绝
}
```

### 可选：限制 N8N 只接受 Cloudflare IP

通过 Nginx 配置只允许 Cloudflare IP 段访问 N8N Webhook 路径。

## 成本估算

| 组件 | 月成本 | 备注 |
|------|--------|------|
| VPS | $5-20 | 取决于配置 |
| Cloudflare Workers | $0-5 | 免费额度 10万次/天，大概率够用 |
| LLM API | $5-30 | 取决于使用量 |
| 域名 | ~$1 | 年费分摊 |
| **合计** | **$10-55** | |

## 替代方案记录 (Rejected Alternatives)

### 为什么不用纯 Cloudflare (D1 + Workers)?
- D1 是 SQLite，不支持 pgvector
- Phase 2 的向量搜索无法实现

### 为什么不用 N8N Cloud?
- 免费版只有 5 个活跃 Workflow
- 付费版 $20/月，叠加 Supabase 后成本较高

### 为什么不把 LLM 调用放在 Worker?
- LLM API 调用通常需要 2-30 秒
- Worker 免费版 CPU 时间限制 10ms（虽然 I/O 等待不算）
- 即使付费版 30s 限制，复杂场景可能不够
- N8N 无此限制，更安全

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| Worker 和 N8N 通信失败 | Worker 可将消息写入 Queue，重试机制 |
| VPS 单点故障 | 定期备份，考虑未来迁移到云数据库 |
| Cloudflare 免费额度用完 | 监控用量，升级付费版仅 $5/月 |

## 后续演进路径

1. **MVP 阶段**：按此架构实施
2. **如需高可用**：PostgreSQL 迁移到 Supabase Cloud
3. **如需更强边缘能力**：扩展 Worker 职责
4. **如 VPS 不稳定**：考虑 N8N Cloud

## 参考资料

- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [N8N 自托管文档](https://docs.n8n.io/hosting/)
- [pgvector 文档](https://github.com/pgvector/pgvector)

---

*此文档记录了架构决策的背景和理由，供未来回顾参考。*
