# Portkey Configuration for N8N

Portkey 作为 LLM 网关，支持多个 LLM 提供商（包括 Gemini）。

## Portkey 配置信息

从 `.env` 文件:
- **Portkey API Key**: `GFsQ7NhPEoMEx6+HfmC6UqKjbNTE`
- **Virtual Key (Gemini)**: `hwiWZtwE4Yl3LmNUYHmP50gMeQMj`

## 在 N8N 中使用 Portkey

### 方案 1: HTTP Request 节点 (推荐)

Portkey 提供 OpenAI 兼容接口，可以直接用 HTTP Request 节点调用。

#### 配置示例

```json
{
  "method": "POST",
  "url": "https://api.portkey.ai/v1/chat/completions",
  "headers": {
    "x-portkey-api-key": "{{ $env.PORTKEY_API_KEY }}",
    "x-portkey-virtual-key": "{{ $env.PORTKEY_VIRTUAL_KEY_GEMINI }}",
    "Content-Type": "application/json"
  },
  "body": {
    "model": "gemini-1.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "你的 Prompt 内容"
      }
    ]
  }
}
```

#### 在 Workflow 中使用

替换原来的 OpenAI 节点，使用 HTTP Request 节点：

1. **节点类型**: HTTP Request
2. **Method**: POST
3. **URL**: `https://api.portkey.ai/v1/chat/completions`
4. **Headers**:
   - `x-portkey-api-key`: `={{ $env.PORTKEY_API_KEY }}`
   - `x-portkey-virtual-key`: `={{ $env.PORTKEY_VIRTUAL_KEY_GEMINI }}`
   - `Content-Type`: `application/json`
5. **Body**:
```json
{
  "model": "gemini-1.5-flash",
  "messages": [
    {
      "role": "user",
      "content": "={{ $json.prompt }}"
    }
  ]
}
```

#### 响应格式

Portkey 返回 OpenAI 兼容格式：

```json
{
  "choices": [
    {
      "message": {
        "content": "LLM 的回复内容"
      }
    }
  ]
}
```

访问回复内容: `={{ $json.choices[0].message.content }}`

### 方案 2: 使用 OpenAI 节点 + Portkey Base URL

N8N 的 OpenAI 节点支持自定义 Base URL。

1. 创建 **OpenAI** Credential
2. **API Key**: 填入 Portkey API Key
3. **Base URL**: `https://api.portkey.ai/v1`
4. 在请求时添加 `x-portkey-virtual-key` header

**注意**: 此方法需要修改 N8N OpenAI 节点代码，不推荐。

## 支持的 Gemini 模型

通过 Portkey Virtual Key，可以使用：

- `gemini-1.5-pro` - 最强大
- `gemini-1.5-flash` - 快速（推荐）
- `gemini-1.0-pro` - 基础版本

## Workflow 修改示例

### 原 A1 Workflow (OpenAI 节点)

```json
{
  "id": "extract-intention",
  "name": "Extract Intention",
  "type": "@n8n/n8n-nodes-langchain.openAi",
  "parameters": {
    "model": "gpt-4o-mini",
    "messages": {
      "values": [
        {
          "content": "你是一个意图提取助手..."
        }
      ]
    }
  }
}
```

### 修改后 (HTTP Request + Portkey)

```json
{
  "id": "extract-intention",
  "name": "Extract Intention",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "POST",
    "url": "https://api.portkey.ai/v1/chat/completions",
    "authentication": "none",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "x-portkey-api-key",
          "value": "={{ $env.PORTKEY_API_KEY }}"
        },
        {
          "name": "x-portkey-virtual-key",
          "value": "={{ $env.PORTKEY_VIRTUAL_KEY_GEMINI }}"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParameters": {
      "parameters": [
        {
          "name": "model",
          "value": "gemini-1.5-flash"
        },
        {
          "name": "messages",
          "value": "=[{\"role\": \"user\", \"content\": \"你是一个意图提取助手。从用户的文本中提取问题或意图。\\n\\n用户文本:\\n{{ $json.body.content }}\\n\\n请提取出用户想要了解或解决的核心问题。\"}]"
        }
      ]
    },
    "options": {
      "response": {
        "response": {
          "responseFormat": "json"
        }
      }
    }
  }
}
```

### 提取响应内容

在后续节点中访问 LLM 回复：

```javascript
// 原 OpenAI 节点
{{ $json.message.content }}

// 修改后 HTTP Request 节点
{{ $json.choices[0].message.content }}
```

## 测试 Portkey 连接

```bash
curl -X POST https://api.portkey.ai/v1/chat/completions \
  -H "x-portkey-api-key: GFsQ7NhPEoMEx6+HfmC6UqKjbNTE" \
  -H "x-portkey-virtual-key: hwiWZtwE4Yl3LmNUYHmP50gMeQMj" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-1.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "你好"
      }
    ]
  }'
```

预期响应:
```json
{
  "choices": [{
    "message": {
      "content": "你好！有什么我可以帮助你的吗？"
    }
  }]
}
```

## 优势

使用 Portkey 的好处：

1. **统一接口**: 所有 LLM 提供商用相同的 API 格式
2. **易于切换**: 修改 Virtual Key 即可切换模型
3. **成本优化**: Portkey 提供缓存、负载均衡等功能
4. **可观测性**: Portkey Dashboard 查看所有 LLM 调用
5. **Fallback**: 配置主备模型，主模型失败自动切换

## 下一步

1. 测试 Portkey 连接（上面的 curl 命令）
2. 修改 N8N Workflows 使用 HTTP Request 节点
3. 配置 PostgreSQL Credential
4. 激活 Workflows
5. 端到端测试

---

*配置完成后记得在 GitHub 更新此文档*
