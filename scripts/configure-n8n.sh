#!/bin/bash
set -e

# N8N Configuration Script
# 使用 N8N API 自动配置 Credentials 和 Workflows

source /root/datasip/docker/.env

N8N_URL="http://localhost:5678"
N8N_USER="admin"
N8N_PASSWORD="datasip2024"

echo "=== Configuring N8N ==="

# 1. 获取 API Key (需要先登录)
echo "Step 1: Getting API Key..."
# 注意：需要在 N8N UI 中手动创建 API Key，或使用已有的 API Key

# 2. 创建 PostgreSQL Credential
echo "Step 2: Creating PostgreSQL Credential..."
curl -X POST "${N8N_URL}/api/v1/credentials" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DataSip PostgreSQL",
    "type": "postgres",
    "data": {
      "host": "postgres",
      "database": "datasip",
      "user": "datasip",
      "password": "'"${POSTGRES_PASSWORD}"'",
      "port": 5432,
      "ssl": "disable"
    }
  }'

# 3. 创建 Portkey Credential (用于 LLM 调用)
echo "Step 3: Creating Portkey Credential..."
# Portkey 作为 OpenAI 兼容接口，使用 HTTP Request 节点

echo "=== Configuration Complete ==="
echo "Please verify in N8N UI and activate workflows manually"
