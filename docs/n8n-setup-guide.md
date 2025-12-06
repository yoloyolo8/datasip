# N8N 配置指南

完整的 N8N 配置步骤，包括导入 Workflows、配置 Credentials 和激活。

## 前置条件

- ✅ Docker 容器已启动 (PostgreSQL + N8N)
- ✅ N8N 可访问: http://localhost:5678
- ✅ 登录凭证: admin / datasip2024
- ✅ 所有 Workflow JSON 文件已更新为 OpenRouter

## 步骤 1: 登录 N8N

1. 访问 http://localhost:5678
2. 使用凭证登录:
   - Username: `admin`
   - Password: `datasip2024`

## 步骤 2: 配置 Credentials

### 2.1 创建 PostgreSQL Credential

1. 点击左侧 **Credentials**
2. 点击 **+ Add Credential**
3. 搜索并选择 **Postgres**
4. 填写配置:
   - **Name**: `DataSip PostgreSQL`
   - **Host**: `postgres`
   - **Database**: `datasip`
   - **User**: `datasip`
   - **Password**: `datasip_pg_2024`
   - **Port**: `5432`
   - **SSL**: `disable`
5. 点击 **Save**
6. 点击 **Test** 验证连接

### 2.2 验证环境变量

N8N 容器已配置以下环境变量，无需手动设置:

- `OPENROUTER_API_KEY` - OpenRouter API Key (已验证可用)
- `TELEGRAM_BOT_TOKEN` - Telegram Bot Token
- `WEBHOOK_SECRET` - Webhook 认证密钥

可以在 Workflow 中直接使用 `{{ $env.VARIABLE_NAME }}` 访问。

## 步骤 3: 导入 Workflows

### 3.1 导入 A1 - Text Handler

1. 点击左侧 **Workflows**
2. 点击 **+ Add workflow**
3. 点击右上角 **...** → **Import from File**
4. 选择 `/root/datasip/n8n/workflows/A1-text-handler.json`
5. 导入后会看到 Workflow 结构:
   ```
   Webhook → Check Auth → Is Text? → Extract Intention (OpenRouter)
   → Insert Intention (PostgreSQL) → Send Confirmation (Telegram)
   ```
6. **配置 PostgreSQL 节点**:
   - 点击 **Insert Intention** 节点
   - 在 **Credential to connect with** 选择 `DataSip PostgreSQL`
7. 点击 **Save**

### 3.2 导入 A2 - Link Handler

1. 重复步骤 3.1，导入 `A2-link-handler.json`
2. Workflow 结构:
   ```
   Webhook → Is URL? → Analyze Content (OpenRouter) → Prepare Data
   → Insert Data (PostgreSQL) → Insert Intention (PostgreSQL) → Send Result (Telegram)
   ```
3. **配置 PostgreSQL 节点** (两个):
   - **Insert Data** 节点 → 选择 `DataSip PostgreSQL`
   - **Insert Intention** 节点 → 选择 `DataSip PostgreSQL`
4. 点击 **Save**

### 3.3 导入 C1 - Daily Matcher

1. 重复步骤 3.1，导入 `C1-daily-matcher.json`
2. Workflow 结构:
   ```
   Cron Webhook → Is Daily Match? → Get Open Intentions (PostgreSQL)
   → Search Related Data (PostgreSQL) → Has Matches? → Judge Relevance (OpenRouter)
   → Build Digest
   ```
3. **配置 PostgreSQL 节点** (两个):
   - **Get Open Intentions** 节点 → 选择 `DataSip PostgreSQL`
   - **Search Related Data** 节点 → 选择 `DataSip PostgreSQL`
4. 点击 **Save**

### 3.4 导入 D - Bot Commands

1. 导入 `/root/datasip/n8n/workflows/D-bot-commands.json`
2. 如果包含 PostgreSQL 节点，配置相同的 Credential
3. 点击 **Save**

## 步骤 4: 激活 Workflows

激活后 Workflows 将开始监听 Webhooks：

### 4.1 激活 A1 - Text Handler

1. 打开 **A1 - Text Handler** workflow
2. 点击右上角的 **Inactive** 开关 → 变为 **Active**
3. 记录 Webhook URL（在 Webhook 节点中查看）:
   ```
   http://localhost:5678/webhook/datasip-webhook
   ```

### 4.2 激活 A2 - Link Handler

1. 打开 **A2 - Link Handler** workflow
2. 激活 Workflow
3. Webhook URL:
   ```
   http://localhost:5678/webhook/datasip-link
   ```

### 4.3 激活 C1 - Daily Matcher

1. 打开 **C1 - Daily Matcher** workflow
2. 激活 Workflow
3. Webhook URL:
   ```
   http://localhost:5678/webhook/datasip-cron
   ```

### 4.4 激活 D - Bot Commands

1. 打开 **D - Bot Commands** workflow
2. 激活 Workflow

## 步骤 5: 测试 Workflows

### 5.1 测试 PostgreSQL 连接

在 N8N 中创建一个测试 Workflow:

1. 添加 **Postgres** 节点
2. Operation: **Execute Query**
3. Query:
   ```sql
   SELECT * FROM intentions LIMIT 1;
   ```
4. 选择 Credential: `DataSip PostgreSQL`
5. 点击 **Execute Node**

预期结果: 显示数据库表结构（可能为空）

### 5.2 测试 OpenRouter

在 N8N 中创建测试 Workflow:

1. 添加 **HTTP Request** 节点
2. 配置:
   - Method: POST
   - URL: `https://openrouter.ai/api/v1/chat/completions`
   - Headers:
     - `Authorization`: `=Bearer {{ $env.OPENROUTER_API_KEY }}`
     - `Content-Type`: `application/json`
   - Body (JSON):
     ```json
     {
       "model": "google/gemini-2.0-flash-exp:free",
       "messages": [{"role": "user", "content": "测试"}]
     }
     ```
3. 点击 **Execute Node**

预期结果:
```json
{
  "choices": [{
    "message": {
      "content": "..."
    }
  }],
  "usage": {
    "total_tokens": 10
  }
}
```

### 5.3 测试完整 Webhook Flow

使用 curl 测试 A1 Workflow:

```bash
curl -X POST http://localhost:5678/webhook/datasip-webhook \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: m4Kioy2UDSslsJqf0QOJ4pJFvv8QQ6fU" \
  -d '{
    "type": "text",
    "content": "如何学习机器学习？",
    "telegram": {
      "chat_id": "123456789",
      "username": "test_user",
      "user_id": "123456789"
    }
  }'
```

预期结果:
- N8N Workflow 执行成功
- PostgreSQL `intentions` 表插入一条记录
- 返回 Telegram 确认消息（如果 Telegram Bot Token 有效）

## 步骤 6: 监控和调试

### 6.1 查看 Workflow 执行历史

1. 在 Workflow 页面，点击 **Executions** 标签
2. 查看每次执行的详细信息
3. 如有错误，点击查看错误详情

### 6.2 常见错误和解决方案

#### 错误 1: "Credential not found"
- 原因: PostgreSQL Credential 未配置
- 解决: 按步骤 2.1 创建 PostgreSQL Credential

#### 错误 2: "relation 'intentions' does not exist"
- 原因: 数据库表未初始化
- 解决: 运行 SQL 初始化脚本 `/root/datasip/sql/001-init-schema.sql`

#### 错误 3: "OPENROUTER_API_KEY is undefined"
- 原因: N8N 容器环境变量未加载
- 解决: 重启 N8N 容器 `docker compose restart n8n`

#### 错误 4: OpenRouter 返回 401
- 原因: API Key 无效
- 解决: 检查 `.env` 文件中的 `OPENROUTER_API_KEY` 是否正确

## 步骤 7: 与 Cloudflare Workers 集成

Cloudflare Workers 将通过 HTTP 调用 N8N Webhooks。

### 7.1 配置 Workers 环境变量

在 Cloudflare Workers 中设置:

```bash
N8N_WEBHOOK_URL=http://YOUR_VPS_IP:5678/webhook/datasip-webhook
N8N_LINK_WEBHOOK_URL=http://YOUR_VPS_IP:5678/webhook/datasip-link
```

### 7.2 测试 Workers → N8N 连接

从 Workers 调用:

```typescript
await fetch(env.N8N_WEBHOOK_URL, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'x-webhook-secret': env.WEBHOOK_SECRET
  },
  body: JSON.stringify({
    type: 'text',
    content: message,
    telegram: { ... }
  })
});
```

## 配置状态检查清单

- [ ] N8N 可访问 (http://localhost:5678)
- [ ] PostgreSQL Credential 已创建并测试通过
- [ ] 4 个 Workflows 已导入
- [ ] 所有 PostgreSQL 节点已配置 Credential
- [ ] 所有 Workflows 已激活
- [ ] 环境变量已加载 (OPENROUTER_API_KEY, TELEGRAM_BOT_TOKEN)
- [ ] OpenRouter 测试通过
- [ ] PostgreSQL 连接测试通过
- [ ] Webhook 端到端测试通过

## 下一步

1. 配置 Cloudflare Workers 环境变量
2. 设置 Telegram Bot Webhook 指向 Workers
3. 端到端测试完整流程
4. 配置 RSS/YouTube 订阅源

---

*配置完成后，系统即可开始接收和处理消息*
