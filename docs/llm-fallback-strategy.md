# LLM Fallback 策略配置

多 LLM 提供商配置，确保系统高可用性。

## 当前可用的 API Keys

从 `.env` 文件配置的提供商:

1. **OpenRouter** (主选)
   - 环境变量: `OPENROUTER_API_KEY`
   - 支持多个模型（Gemini 免费）
   - 状态: ✅ 已验证成功

2. **Claude** (备选)
   - 环境变量: `CLAUDE_API_KEY`
   - 直接调用 Anthropic API
   - 状态: ⏳ 待验证

3. **Portkey** (网关)
   - 环境变量: `PORTKEY_API_KEY_user`, `PORTKEY_API_KEY_service`
   - 需要配置 Virtual Keys
   - 状态: ⚠️ 需要在 Dashboard 配置

## Fallback 策略

### 策略 1: N8N 内部 Fallback (推荐)

在 N8N Workflow 中配置多个 LLM 调用节点，当主节点失败时自动切换。

```
┌─────────────────┐
│ Try OpenRouter  │
│ (Gemini Free)   │
└────────┬────────┘
         │
    成功?├─────────> 继续处理
         │
         └──> ┌────────────────┐
              │ Try Claude API │
              └────────┬───────┘
                       │
                  成功?├─────> 继续处理
                       │
                       └──> 返回错误
```

### 策略 2: Portkey 自动 Fallback

在 Portkey Dashboard 中配置 Fallback Chain，Portkey 自动处理切换。

```
主模型失败 → Portkey 自动切换 → 备用模型
```

## 实现方案

### 方案 A: N8N 手动 Fallback (简单)

在每个需要 LLM 的 Workflow 中:

1. 主 HTTP Request 节点 → OpenRouter (Gemini 免费)
2. 设置 "Continue On Fail" = true
3. 添加 IF 节点判断是否成功
4. 失败时调用备用 HTTP Request 节点 → Claude API

#### 优点:
- 无需额外配置
- 可以看到哪个 API 被使用
- 完全掌控 fallback 逻辑

#### 缺点:
- 每个 Workflow 都需要重复配置
- Workflow 会变得复杂

### 方案 B: Portkey 托管 Fallback (推荐)

使用 Portkey 作为统一网关，在 Portkey Dashboard 配置 Fallback。

#### 步骤:

1. **在 Portkey Dashboard 创建 Virtual Keys**:
   - Virtual Key 1: OpenRouter (Primary)
   - Virtual Key 2: Claude (Fallback)

2. **创建 Portkey Config**:
```json
{
  "strategy": {
    "mode": "fallback"
  },
  "targets": [
    {
      "virtual_key": "openrouter_virtual_key_id",
      "weight": 1
    },
    {
      "virtual_key": "claude_virtual_key_id",
      "weight": 1
    }
  ]
}
```

3. **在 N8N 中使用**:
```javascript
// HTTP Request 节点
{
  "url": "https://api.portkey.ai/v1/chat/completions",
  "headers": {
    "x-portkey-api-key": "={{ $env.PORTKEY_API_KEY_service }}",
    "x-portkey-config": "config_id_from_dashboard",
    "Content-Type": "application/json"
  },
  "body": {
    "messages": [...]
  }
}
```

#### 优点:
- 自动 fallback，无需修改 Workflow
- Portkey Dashboard 可视化监控
- 支持负载均衡、缓存等高级功能

#### 缺点:
- 需要在 Portkey Dashboard 配置
- 增加一层网络调用

## 推荐配置

### 当前建议: 混合方案

1. **主选**: OpenRouter (免费 Gemini)
   - 直接调用，无中间层
   - 免费额度用完再切换

2. **备选**: Claude API
   - 在 N8N Workflow 中配置简单的 IF 判断
   - OpenRouter 失败时调用

3. **未来**: 配置 Portkey
   - 当需要更多高级功能时
   - 需要多模型负载均衡时

## 立即可用的配置

### OpenRouter (主选)

```bash
# API Endpoint
https://openrouter.ai/api/v1/chat/completions

# Headers
Authorization: Bearer {{ $env.OPENROUTER_API_KEY }}

# Body
{
  "model": "google/gemini-2.0-flash-exp:free",
  "messages": [...]
}
```

### Claude API (备选)

```bash
# API Endpoint
https://api.anthropic.com/v1/messages

# Headers
x-api-key: {{ $env.CLAUDE_API_KEY }}
anthropic-version: 2023-06-01

# Body
{
  "model": "claude-3-5-haiku-20241022",
  "messages": [...]
}
```

## N8N Workflow Fallback 实现示例

### 节点结构:

```
Webhook Trigger
    ↓
[HTTP Request: Try OpenRouter]
  - Continue On Fail: true
    ↓
[IF: Check Success]
  - Condition: {{ $json.choices }}
    ↓ (false)
    └──> [HTTP Request: Try Claude]
           ↓
         [IF: Check Success]
           ↓
         继续处理或返回错误
```

### HTTP Request 节点配置

#### OpenRouter 节点:
```json
{
  "method": "POST",
  "url": "https://openrouter.ai/api/v1/chat/completions",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $env.OPENROUTER_API_KEY }}"
      }
    ]
  },
  "options": {
    "response": {
      "response": {
        "fullResponse": false,
        "neverError": true
      }
    }
  }
}
```

#### Claude 节点:
```json
{
  "method": "POST",
  "url": "https://api.anthropic.com/v1/messages",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "x-api-key",
        "value": "={{ $env.CLAUDE_API_KEY }}"
      },
      {
        "name": "anthropic-version",
        "value": "2023-06-01"
      }
    ]
  }
}
```

## 下一步

1. 验证 Claude API Key 是否有效
2. 决定使用哪种 Fallback 策略
3. 实现选定的策略
4. 测试 Fallback 流程

---

*建议先验证 Claude API 是否可用，然后决定策略*
