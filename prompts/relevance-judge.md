# 相关性判定 Prompt

## 用途
判断找到的内容是否能回答用户的问题。

## Prompt 模板

```
用户的问题: {intention}

找到的相关内容:
{matched_content}

请判断这些内容是否能帮助回答用户的问题。

评判标准:
1. 直接回答: 内容直接解答了问题 → 分数 0.9-1.0
2. 相关参考: 内容提供了有价值的参考 → 分数 0.7-0.9
3. 部分相关: 内容涉及相关领域 → 分数 0.5-0.7
4. 不相关: 内容与问题无关 → 分数 0-0.5

返回JSON:
{
  "is_relevant": true/false,
  "relevance_score": 0-1,
  "summary": "简要说明这些内容如何帮助回答问题（或为何不相关）"
}
```

## 输入示例

```
用户的问题: 如何在 Kubernetes 中实现零停机部署？

找到的相关内容:
[
  {"title": "Kubernetes Rolling Update 详解", "summary": "介绍 K8s 滚动更新机制..."},
  {"title": "Blue-Green Deployment 实践", "summary": "蓝绿部署的实施步骤..."}
]
```

## 输出示例

```json
{
  "is_relevant": true,
  "relevance_score": 0.92,
  "summary": "找到的内容直接涉及 Kubernetes 的滚动更新和蓝绿部署策略，这两种都是实现零停机部署的常用方法。建议结合阅读这两篇文章。"
}
```

## 使用场景
- 每日匹配时判断内容相关性
- 向用户推送匹配结果前的过滤
