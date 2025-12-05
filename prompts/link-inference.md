# 链接意图推理 Prompt

## 用途
从用户保存的链接内容中推理用户的隐性意图。

## Prompt 模板

```
分析以下网页内容，生成:
1. 一句话摘要 (不超过100字)
2. 3-5个标签 (用逗号分隔)
3. 推测用户保存这篇文章的意图/关注点 (一个问题)

标题: {title}

内容:
{content}

请按以下JSON格式返回:
{
  "summary": "文章的核心内容概述",
  "tags": ["tag1", "tag2", "tag3"],
  "inferred_intention": "用户可能想了解的问题"
}
```

## 输入示例

```
标题: How to Design a Rate Limiter

内容: Rate limiting is a technique used to control the rate of requests...
```

## 输出示例

```json
{
  "summary": "本文介绍了限流器的设计原理，包括令牌桶、滑动窗口等算法的实现方式",
  "tags": ["系统设计", "限流", "分布式", "算法"],
  "inferred_intention": "如何设计一个高性能的限流系统？"
}
```

## 使用场景
- 用户发送 URL 时
- 处理手动投喂的内容
