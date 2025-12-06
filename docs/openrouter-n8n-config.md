# OpenRouter + N8N 配置指南

使用 OpenRouter 作为统一 LLM 网关，支持多个模型（包括免费的 Gemini）。

## 验证结果

✅ OpenRouter API Key 已验证成功
✅ Gemini 2.0 Flash (免费) 测试通过

测试响应:
```json
{
  "choices": [{
    "message": {
      "content": "你好！"
    }
  }],
  "usage": {
    "total_tokens": 10,
    "cost": 0
  }
}
```

## OpenRouter 配置

### 环境变量

已在 `/root/datasip/docker/.env` 配置:
```bash
OPENROUTER_API_KEY=your_openrouter_api_key_here
```

### 支持的免费模型

- `google/gemini-2.0-flash-exp:free` - 最新 Gemini 2.0 (免费)
- `google/gemini-flash-1.5` - Gemini 1.5 Flash (付费但便宜)
- `meta-llama/llama-3.2-3b-instruct:free` - Llama 3.2 (免费)

完整模型列表: https://openrouter.ai/models

## N8N HTTP Request 节点配置

### 方法 1: 直接配置 (推荐)

在 N8N 中使用 HTTP Request 节点:

```json
{
  "method": "POST",
  "url": "https://openrouter.ai/api/v1/chat/completions",
  "authentication": "predefinedCredentialType",
  "nodeCredentialType": "httpHeaderAuth",
  "sendHeaders": true,
  "headerParameters": {
    "parameters": [
      {
        "name": "Authorization",
        "value": "=Bearer {{ $env.OPENROUTER_API_KEY }}"
      },
      {
        "name": "Content-Type",
        "value": "application/json"
      }
    ]
  },
  "sendBody": true,
  "bodyParameters": {
    "parameters": []
  },
  "specifyBody": "json",
  "jsonBody": "={{ JSON.stringify({\n  model: 'google/gemini-2.0-flash-exp:free',\n  messages: [\n    {\n      role: 'user',\n      content: $json.prompt || '默认提示'\n    }\n  ]\n}) }}",
  "options": {
    "response": {
      "response": {
        "responseFormat": "json"
      }
    }
  }
}
```

### 方法 2: 使用 Credential

1. 在 N8N 中创建 **Header Auth** Credential
2. Header Name: `Authorization`
3. Header Value: `Bearer {{ $env.OPENROUTER_API_KEY }}`

然后在 HTTP Request 节点中选择该 Credential。

## Workflow 示例配置

### A1: Text Handler (意图提取)

```javascript
// HTTP Request 节点 Body (JSON)
{
  "model": "google/gemini-2.0-flash-exp:free",
  "messages": [
    {
      "role": "user",
      "content": `你是一个意图提取助手。从用户的文本中提取问题或意图。

用户文本:
${$json.body.content}

请提取出用户想要了解或解决的核心问题。`
    }
  ]
}

// 后续节点访问 LLM 回复
{{ $json.choices[0].message.content }}
```

### A2: Link Handler (内容总结)

```javascript
// HTTP Request 节点 Body
{
  "model": "google/gemini-2.0-flash-exp:free",
  "messages": [
    {
      "role": "user",
      "content": `总结以下内容的主要信息:

标题: ${$json.title}
内容: ${$json.text}

请用 1-3 句话概括核心要点。`
    }
  ]
}
```

### C1: Daily Matcher (意图匹配)

```javascript
// HTTP Request 节点 Body
{
  "model": "google/gemini-2.0-flash-exp:free",
  "messages": [
    {
      "role": "user",
      "content": `判断以下内容是否能回答用户的问题:

用户问题: ${$json.intention}

内容标题: ${$json.data_title}
内容摘要: ${$json.data_summary}

如果相关，回复 "YES"；否则回复 "NO"。`
    }
  ]
}
```

## 响应格式

OpenRouter 返回 OpenAI 兼容格式:

```json
{
  "choices": [
    {
      "message": {
        "content": "LLM 的回复内容"
      }
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 20,
    "total_tokens": 30,
    "cost": 0
  }
}
```

在 N8N 中访问回复:
```javascript
{{ $json.choices[0].message.content }}
```

## 成本控制

### 免费模型
- `google/gemini-2.0-flash-exp:free` - 每分钟 10 请求
- `meta-llama/llama-3.2-3b-instruct:free` - 每分钟 20 请求

### 付费模型 (备用)
- `google/gemini-flash-1.5` - $0.0002/1K tokens
- `anthropic/claude-3-haiku` - $0.0025/1K tokens

## 测试命令

```bash
curl -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemini-2.0-flash-exp:free",
    "messages": [{"role": "user", "content": "你好"}]
  }'
```

## 优势

1. **免费模型**: Gemini 2.0 Flash 完全免费
2. **统一接口**: OpenAI 兼容格式
3. **多模型支持**: 一个 API Key 访问所有模型
4. **自动负载均衡**: OpenRouter 处理请求分发
5. **监控面板**: https://openrouter.ai/activity 查看使用情况

## 下一步

1. ✅ 验证 OpenRouter API Key
2. 更新 `docker-compose.yml` 添加 OPENROUTER_API_KEY 环境变量
3. 重启 N8N 容器
4. 修改 Workflows 使用 OpenRouter HTTP Request 节点
5. 测试端到端流程

---

*配置完成，准备修改 Workflows*
