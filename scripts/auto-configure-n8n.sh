#!/bin/bash
set -e

# N8N Auto Configuration Script
# 使用 N8N CLI 和数据库直接配置

source /root/datasip/docker/.env

N8N_URL="http://localhost:5678"
N8N_USER="admin"
N8N_PASSWORD="datasip2024"

echo "=== N8N 自动配置脚本 ==="
echo ""

# 1. 创建 PostgreSQL Credential (通过数据库直接插入)
echo "Step 1: 配置 PostgreSQL Credential..."

docker exec datasip-postgres psql -U datasip -d datasip <<EOF
-- 插入 PostgreSQL Credential
-- N8N 会加密存储，这里我们插入加密后的凭证
-- 注意：需要使用 N8N 的加密密钥

-- 检查是否已存在
SELECT id, name FROM public.credentials_entity WHERE name = 'DataSip PostgreSQL' LIMIT 1;
EOF

echo ""
echo "注意：N8N Credentials 使用加密存储，无法通过数据库直接插入。"
echo "需要使用 N8N API 或手动在 UI 中创建。"
echo ""

# 2. 检查 Workflows 文件
echo "Step 2: 检查 Workflow 文件..."
for workflow in A1-text-handler A2-link-handler C1-daily-matcher D-bot-commands; do
  if [ -f "/root/datasip/n8n/workflows/${workflow}.json" ]; then
    echo "  ✅ ${workflow}.json"
  else
    echo "  ❌ ${workflow}.json (缺失)"
  fi
done

echo ""
echo "=== 建议的配置方案 ==="
echo ""
echo "方案 1: 使用 N8N API (需要先获取 API Key)"
echo "  1. 访问 N8N UI: http://localhost:5678"
echo "  2. 登录: admin / datasip2024"
echo "  3. 进入 Settings → API"
echo "  4. 创建 API Key"
echo "  5. 运行配置脚本"
echo ""
echo "方案 2: 直接导入 Workflows (推荐)"
echo "  - N8N 支持将 workflow JSON 文件放在特定目录"
echo "  - 重启 N8N 会自动导入"
echo ""

# 3. 尝试通过挂载卷导入 Workflows
echo "Step 3: 准备 Workflows 导入..."

# N8N 数据目录
N8N_DATA_DIR="/root/datasip/docker/n8n_data"

# 检查是否可以访问
if docker exec datasip-n8n ls /home/node/.n8n > /dev/null 2>&1; then
  echo "  N8N 数据目录可访问"

  # 尝试复制 workflows
  echo "  正在复制 Workflow 文件到 N8N 容器..."
  for workflow in /root/datasip/n8n/workflows/*.json; do
    filename=$(basename "$workflow")
    docker cp "$workflow" datasip-n8n:/home/node/.n8n/workflows/
    echo "    已复制: $filename"
  done

  echo ""
  echo "  ✅ Workflows 已复制到 N8N 容器"
  echo "  ⚠️  需要在 N8N UI 中手动导入或重启容器"
else
  echo "  ❌ 无法访问 N8N 数据目录"
fi

echo ""
echo "=== 配置总结 ==="
echo "1. PostgreSQL Credential: 需要在 N8N UI 中创建"
echo "2. Workflows: 已准备好 JSON 文件，需要导入"
echo "3. 环境变量: 已配置完成"
echo ""
echo "建议：在 N8N UI 中完成以下步骤："
echo "  1. 创建 PostgreSQL Credential"
echo "  2. 导入 4 个 Workflow JSON 文件"
echo "  3. 在每个 Workflow 中配置 PostgreSQL 节点使用该 Credential"
echo "  4. 激活所有 Workflows"
echo ""
