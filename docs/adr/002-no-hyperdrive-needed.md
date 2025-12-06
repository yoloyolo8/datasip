# ADR-002: Workers 不需要直连 PostgreSQL 或使用 Hyperdrive

**状态：** 已采纳
**日期：** 2025-12-04
**决策者：** 项目所有者 + AI 架构师

---

## 背景 (Context)

在配置 Cloudflare Workers 时，用户提出疑问：

> "Workers 连接 PostgreSQL 和 Hyperdrive 连接哪种方案更好？"

这促使我们重新审视架构中的数据流和职责分配。

---

## 问题分析

### 技术选项对比

| 方案 | 描述 | 优点 | 缺点 |
|------|------|------|------|
| **直连 PostgreSQL** | Worker 通过 TCP Socket 直连数据库 | 简单直接 | 每次请求重新建连，延迟高 (295ms+) |
| **使用 Hyperdrive** | Cloudflare 的连接池服务 | 性能优秀，延迟低，免费 | 增加配置复杂度 |
| **不连接数据库** | Worker 只调用 N8N，由 N8N 操作数据库 | 职责清晰，架构简洁 | 无 |

---

## 当前架构审查

### 数据流分析

```
┌─────────────┐
│   用户      │
└──────┬──────┘
       │ 发消息
       ▼
┌─────────────┐
│  Telegram   │
└──────┬──────┘
       │ Webhook
       ▼
┌─────────────────────────────────────┐
│  Cloudflare Workers (边缘层)        │
│  职责:                              │
│  ✓ 接收 Telegram Webhook            │
│  ✓ 抓取 RSS/网页 (Jina Reader)      │
│  ✓ 快速响应用户                      │
│  ✓ 转发数据到 N8N (HTTP)            │
└──────┬──────────────────────────────┘
       │ HTTP POST
       ▼
┌─────────────────────────────────────┐
│  VPS (N8N + PostgreSQL)             │
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │    N8N      │  │ PostgreSQL   │ │
│  │  职责:      │  │              │ │
│  │  ✓ LLM 调用 ├─►│ localhost:   │ │
│  │  ✓ 数据库   │  │ 5432         │ │
│  │    CRUD     │  │ (本地连接)   │ │
│  └─────────────┘  └──────────────┘ │
└─────────────────────────────────────┘
```

### 关键发现

1. **Worker 无需访问数据库**
   - Worker 的职责是：快速响应、数据采集、转发
   - 所有数据库操作由 N8N 处理

2. **N8N 和 PostgreSQL 在同一 VPS**
   - N8N 通过 `localhost:5432` 连接
   - 延迟 < 1ms，无需跨网络连接池

3. **架构分层清晰**
   - 边缘层 (Worker): I/O 密集，无状态
   - 处理层 (N8N): 业务逻辑，有状态
   - 存储层 (PostgreSQL): 数据持久化

---

## 决策 (Decision)

**Worker 不连接 PostgreSQL，不使用 Hyperdrive。**

### 理由

1. **职责分离原则**
   - Worker: 边缘快速响应
   - N8N: 集中处理逻辑和数据

2. **性能最优**
   - Worker → N8N: HTTP 请求（边缘 → VPS）
   - N8N → PostgreSQL: 本地连接（< 1ms）
   - 总延迟最小化

3. **架构简洁**
   - 减少配置复杂度
   - 降低维护成本
   - 更容易调试

4. **安全性**
   - PostgreSQL 不暴露公网
   - 仅 N8N 本地访问

---

## 技术参考

### Hyperdrive 性能数据 (来自 Cloudflare 官方)

> "Enabling Hyperdrive eliminated 295 ms of latency for the user in Los Angeles."
>
> Source: [How Hyperdrive speeds up database access](https://blog.cloudflare.com/how-hyperdrive-speeds-up-database-access/)

### 直连 vs Hyperdrive (Cloudflare 官方建议)

> "You will almost always want Hyperdrive. Raw TCP sockets don't do any kind of connection pooling and the Worker would have to reconnect to the database on every request."
>
> Source: [Cloudflare Community](https://community.cloudflare.com/t/does-postgres-connection-in-worked-require-hyperdrive/680159)

**但我们的架构不需要 Worker 连接数据库，因此无需选择。**

---

## 替代方案记录 (Rejected Alternatives)

### 方案 A：Worker 通过 Hyperdrive 连 PostgreSQL

**为什么拒绝？**
1. 增加配置复杂度（需配置 Hyperdrive）
2. PostgreSQL 需暴露公网或配置 Cloudflare Tunnel
3. 违背职责分离原则
4. N8N 的优势（可视化编排）无法发挥

### 方案 B：Worker 直连 PostgreSQL

**为什么拒绝？**
1. 性能极差（每次请求重建连接）
2. 安全风险（数据库暴露公网）
3. Worker 需要处理数据库逻辑，违背"轻量化"原则

---

## 后果 (Consequences)

### 正面影响
- ✅ 架构清晰，职责明确
- ✅ N8N 和 PostgreSQL 本地连接，性能最优
- ✅ 配置简化，降低维护成本
- ✅ PostgreSQL 不暴露公网，更安全

### 负面影响 (可接受)
- ⚠️ Worker 和 N8N 之间需要网络通信（但延迟可接受）
- ⚠️ N8N 成为单点（通过 VPS 备份和监控缓解）

---

## 未来演进路径

如果项目规模扩大，可考虑：

1. **N8N 高可用**
   - 迁移到 N8N Cloud
   - 或自建多实例 + 负载均衡

2. **PostgreSQL 高可用**
   - 迁移到 Supabase Cloud
   - 或自建主从复制

3. **Worker 直连数据库（仅在必要时）**
   - 如需极低延迟的查询（< 50ms）
   - 此时才引入 Hyperdrive

---

## 参考资料

- [Cloudflare Hyperdrive Overview](https://developers.cloudflare.com/hyperdrive/)
- [Connect to databases - Cloudflare Workers](https://developers.cloudflare.com/workers/databases/connecting-to-databases/)
- [Does postgres connection require hyperdrive? - Community](https://community.cloudflare.com/t/does-postgres-connection-in-worked-require-hyperdrive/680159)
- [How Hyperdrive speeds up database access](https://blog.cloudflare.com/how-hyperdrive-speeds-up-database-access/)

---

*此决策帮助我们明确了架构边界，避免了不必要的复杂度。*
