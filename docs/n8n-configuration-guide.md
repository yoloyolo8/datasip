# N8N Configuration Guide

## 访问 N8N

- URL: http://n8n.yolonote.xyz:5678 (或 http://your-vps-ip:5678)
- 用户名: `admin`
- 密码: (见 docker/.env 中的 N8N_PASSWORD)

## 配置步骤

### 1. 导入状态 ✅

已成功导入 4 个工作流:
- ✅ A1 - Text Handler
- ✅ A2 - Link Handler
- ✅ C1 - Daily Matcher
- ✅ D - Bot Commands

### 2. 配置 Credentials (必须手动完成)

#### 2.1 PostgreSQL Credential

1. 在 N8N UI 中，点击右上角用户头像 → **Credentials**
2. 点击 **Add Credential**
3. 搜索并选择 **Postgres**
4. 填写以下信息:
   - **Name**: `DataSip PostgreSQL`
   - **Host**: `postgres`
   - **Database**: `datasip`
   - **User**: `datasip`
   - **Password**: (见 docker/.env 中的 POSTGRES_PASSWORD)
   - **Port**: `5432`
   - **SSL**: `Disable`
5. 点击 **Save** 并 **Test** 连接

#### 2.2 OpenAI API Credential

1. 点击 **Add Credential**
2. 搜索并选择 **OpenAI**
3. 填写以下信息:
   - **Name**: `OpenAI API`
   - **API Key**: `<你的 OpenAI API Key>`
4. 点击 **Save**

**注意**: 如果你没有 OpenAI API Key，可以:
- 访问 https://platform.openai.com/api-keys 创建
- 或使用兼容 OpenAI 格式的其他服务 (如 Azure OpenAI, Anthropic)

#### 2.3 验证环境变量

已配置的环境变量 (无需手动配置):
- ✅ `WEBHOOK_SECRET`: (已在 docker/.env 中配置)
- ✅ `TELEGRAM_BOT_TOKEN`: (已在 docker/.env 中配置)

这些变量可以在工作流中通过 `{{ $env.VARIABLE_NAME }}` 访问。

### 3. 激活工作流

配置完 Credentials 后，依次激活工作流:

1. 打开 **Workflows** 页面
2. 对每个工作流:
   - 点击工作流名称打开
   - 点击右上角的 **Inactive** 开关 → 变为 **Active**
   - 确认 Webhook URL 已生成

工作流激活顺序:
1. **A1 - Text Handler** (处理文本意图)
2. **A2 - Link Handler** (处理链接)
3. **D - Bot Commands** (处理 Bot 命令)
4. **C1 - Daily Matcher** (每日匹配 - cron 触发)

### 4. 获取 Webhook URLs

激活工作流后，记录以下 Webhook URLs:

- **A1 Text Handler**: `http://66.80.0.175:5678/webhook/datasip-webhook`
- **A2 Link Handler**: `http://66.80.0.175:5678/webhook/datasip-link`
- **D Bot Commands**: `http://66.80.0.175:5678/webhook/datasip-command`
- **C1 Cron Handler**: `http://66.80.0.175:5678/webhook/datasip-cron`

### 5. 更新 Workers 配置 (如果 Webhook URL 不同)

如果 N8N 生成的 Webhook URL 与预期不同，需要更新 Workers 代码:

```bash
# 编辑 workers/src/services/n8n.ts
# 更新 webhookUrl 变量
```

### 6. 测试连接

配置完成后，在命令行测试:

```bash
# 测试 Text Handler Webhook
curl -X POST http://66.80.0.175:5678/webhook/datasip-webhook \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: m4Kioy2UDSslsJqf0QOJ4pJFvv8QQ6fU" \
  -d '{
    "type": "text",
    "content": "如何学习 Rust 编程语言？",
    "telegram": {
      "user_id": 1653558222,
      "chat_id": 1653558222,
      "username": "testuser"
    }
  }'
```

预期响应: HTTP 200，无错误。

### 7. 端到端测试

最后，通过 Telegram Bot 测试完整流程:

1. 发送消息给 @datasippp_bot
2. 检查是否收到确认消息
3. 发送 `/list` 命令查看已记录的意图
4. 检查 N8N 执行日志

## Troubleshooting

### Credentials 无法连接 PostgreSQL

**问题**: "Connection refused" 或 "timeout"

**解决**:
- 确认 Host 是 `postgres` (容器名，不是 localhost)
- 确认 PostgreSQL 容器正在运行: `docker ps`
- 查看 N8N 日志: `docker logs datasip-n8n`

### OpenAI API 调用失败

**问题**: "Invalid API Key" 或 "Rate limit exceeded"

**解决**:
- 验证 API Key 是否正确
- 检查 API Key 额度: https://platform.openai.com/usage
- 考虑切换到其他 LLM 服务

### Webhook 返回 403

**问题**: Worker 调用 Webhook 返回 403

**原因**:
- `x-webhook-secret` header 不匹配
- 工作流中的认证逻辑检查失败

**解决**:
- 确认 Worker 和 N8N 使用相同的 WEBHOOK_SECRET
- 检查工作流中的 "Check Auth" 节点

### 工作流无法激活

**问题**: "Missing credentials" 或 "Invalid node configuration"

**解决**:
- 确保所有 Credentials 已正确配置并保存
- 打开工作流，检查红色错误标记的节点
- 点击节点，查看具体错误信息

## 下一步

配置完成后:
1. 返回终端告知 Claude Code
2. 继续测试 Telegram Bot 功能
3. 调试任何剩余问题
