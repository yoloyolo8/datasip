# 错误处理机制 (Error Handling)

**版本：** v1.0
**更新日期：** 2025-12-04

---

## 1. 错误分类

### 1.1 错误严重级别

| 级别 | 名称 | 描述 | 处理策略 |
|------|------|------|----------|
| P0 | 致命 | 系统无法运行 | 立即告警，人工介入 |
| P1 | 严重 | 核心功能失效 | 告警 + 自动重试 |
| P2 | 中等 | 单次任务失败 | 记录日志 + 重试 |
| P3 | 轻微 | 非关键功能异常 | 静默记录 |

### 1.2 错误类型矩阵

| 错误类型 | 示例 | 级别 | 重试策略 |
|----------|------|------|----------|
| 网络超时 | 抓取网页超时 | P2 | 指数退避，最多 3 次 |
| API 限流 | LLM API 429 | P2 | 等待后重试 |
| API 认证失败 | Token 过期 | P1 | 告警，不重试 |
| 数据库连接失败 | PostgreSQL 不可用 | P0 | 立即告警 |
| 数据解析失败 | RSS 格式异常 | P2 | 记录，跳过该条目 |
| LLM 输出异常 | JSON 解析失败 | P2 | 重新调用，最多 2 次 |
| 订阅源失效 | RSS 404 | P3 | 标记 review_needed |

---

## 2. N8N Workflow 错误处理

### 2.1 全局错误处理流程

```
任意 Workflow 节点出错
        ↓
Error Trigger (全局)
        ↓
    ┌───┴───┐
    │ 分类  │
    └───┬───┘
        ├─ P0/P1 → Telegram 告警通知
        ├─ P2 → 写入 error_logs 表
        └─ P3 → 仅写日志
```

### 2.2 重试策略配置

```javascript
// N8N Function Node: 指数退避重试
const MAX_RETRIES = 3;
const BASE_DELAY = 1000; // 1秒

const retryCount = $json.retryCount || 0;

if (retryCount < MAX_RETRIES) {
  const delay = BASE_DELAY * Math.pow(2, retryCount);
  await new Promise(resolve => setTimeout(resolve, delay));
  return [{
    ...$json,
    retryCount: retryCount + 1
  }];
}

// 达到最大重试次数，进入错误处理
throw new Error(`Max retries (${MAX_RETRIES}) exceeded`);
```

### 2.3 各模块错误处理

#### 模块 A: 意图捕获

| 错误场景 | 处理方式 |
|----------|----------|
| Telegram Webhook 解析失败 | 记录原始 payload，返回 200（避免重试风暴） |
| LLM 调用失败 | 重试 2 次，失败则保存原文到待处理队列 |
| 数据库写入失败 | 告警 + 返回用户"暂时无法处理" |

#### 模块 B: 数据采集

| 错误场景 | 处理方式 |
|----------|----------|
| RSS 抓取超时 | 跳过本次，下次 Cron 重试 |
| RSS 源 404/502 | 连续 3 次失败后标记 `review_needed` |
| YouTube API 配额耗尽 | 暂停 YouTube 抓取至次日 |
| 网页内容为空 | 尝试备用抓取方案，失败则跳过 |
| LLM 摘要失败 | 存储原始内容，摘要字段留空 |

#### 模块 C: 核心匹配

| 错误场景 | 处理方式 |
|----------|----------|
| 匹配查询超时 | 缩小时间范围重试 |
| LLM 判定格式错误 | 重新调用，要求严格 JSON |
| 推送 Telegram 失败 | 重试 3 次，失败则保存到待推送队列 |

---

## 3. 数据库层错误处理

### 3.1 错误日志表

```sql
CREATE TABLE error_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 错误分类
    severity        TEXT NOT NULL,      -- 'P0' | 'P1' | 'P2' | 'P3'
    error_type      TEXT NOT NULL,      -- 'network' | 'api' | 'parse' | 'database'

    -- 错误详情
    workflow_name   TEXT,               -- N8N Workflow 名称
    node_name       TEXT,               -- 出错的节点名称
    error_message   TEXT NOT NULL,
    stack_trace     TEXT,

    -- 上下文
    input_data      JSONB,              -- 触发错误的输入数据

    -- 处理状态
    retry_count     INT DEFAULT 0,
    resolved        BOOLEAN DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    resolution_note TEXT
);

CREATE INDEX idx_error_logs_severity ON error_logs(severity);
CREATE INDEX idx_error_logs_created ON error_logs(created_at DESC);
CREATE INDEX idx_error_logs_unresolved ON error_logs(resolved) WHERE resolved = FALSE;
```

### 3.2 待处理队列表

```sql
-- 用于存储因错误需要重新处理的任务
CREATE TABLE pending_tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    task_type       TEXT NOT NULL,      -- 'intention_extract' | 'content_fetch' | 'notification'
    payload         JSONB NOT NULL,     -- 原始数据

    retry_count     INT DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,

    status          TEXT DEFAULT 'pending', -- 'pending' | 'processing' | 'completed' | 'failed'
    error_message   TEXT
);
```

---

## 4. 告警机制

### 4.1 Telegram 告警模板

```
🚨 DataSip 系统告警

级别: P1 - 严重
时间: 2025-12-04 15:30:00 UTC
模块: RSS Fetcher
错误: OpenAI API authentication failed

详情:
API Key 可能已过期或被撤销

建议操作:
1. 检查 OpenAI API Key 状态
2. 更新 N8N Credentials

---
错误ID: err_abc123
```

### 4.2 告警频率控制

为避免告警风暴，实施以下策略：

```javascript
// 相同错误 30 分钟内只告警一次
const ALERT_COOLDOWN = 30 * 60 * 1000; // 30分钟

const errorKey = `${workflowName}_${errorType}`;
const lastAlert = await getLastAlertTime(errorKey);

if (!lastAlert || Date.now() - lastAlert > ALERT_COOLDOWN) {
  await sendTelegramAlert(errorMessage);
  await setLastAlertTime(errorKey, Date.now());
}
```

---

## 5. 降级策略

### 5.1 LLM 服务降级

```
正常: Claude Sonnet (推理) + GPT-4o-mini (摘要)
      ↓ Claude API 不可用
降级1: GPT-4o (推理) + GPT-4o-mini (摘要)
      ↓ OpenAI API 不可用
降级2: 跳过 AI 处理，保存原始内容，队列等待恢复
```

### 5.2 抓取服务降级

```
正常: Jina Reader API
      ↓ Jina 不可用或失败
降级: 使用 N8N HTTP Request 直接抓取
      ↓ 仍然失败
降级: 仅保存 URL 和元信息，标记待重抓
```

---

## 6. 监控指标

### 6.1 关键监控项

| 指标 | 阈值 | 告警级别 |
|------|------|----------|
| Workflow 失败率 | > 10% | P1 |
| LLM API 延迟 | > 30s | P2 |
| 数据库连接数 | > 80% | P1 |
| 待处理队列积压 | > 100 条 | P2 |
| 错误日志增长 | > 50 条/小时 | P2 |

### 6.2 健康检查

建议配置定时健康检查 Workflow：

```
Trigger: Cron (每 5 分钟)
    ↓
检查项:
├─ PostgreSQL 连接: SELECT 1
├─ N8N 内部状态: 检查执行队列
├─ Telegram Bot: getMe API
└─ LLM API: 简单测试请求
    ↓
任一失败 → P0 告警
```

---

## 7. 恢复流程

### 7.1 从错误中恢复

1. **查看错误日志**
   ```sql
   SELECT * FROM error_logs
   WHERE resolved = FALSE
   ORDER BY severity, created_at DESC;
   ```

2. **处理待处理队列**
   ```sql
   SELECT * FROM pending_tasks
   WHERE status = 'pending'
   AND next_retry_at < NOW();
   ```

3. **手动重试 Workflow**
   - N8N UI → Executions → 找到失败的执行 → Retry

### 7.2 数据一致性修复

```sql
-- 找出可能不一致的数据
-- 例：有 intention 但缺少对应的 data_inbox 记录
SELECT i.* FROM intentions i
LEFT JOIN data_inbox d ON i.source_data_id = d.id
WHERE i.source_data_id IS NOT NULL
AND d.id IS NULL;
```

---

*此文档应随系统运行情况持续更新。*
