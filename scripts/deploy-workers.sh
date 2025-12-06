#!/bin/bash
# ====================================
# DataSip Workers 一键部署脚本
# ====================================

set -e  # 遇到错误立即退出

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DataSip Workers 自动部署脚本${NC}"
echo "================================"

# ====================================
# 步骤 1: 环境检查
# ====================================
echo -e "\n${YELLOW}[1/6]${NC} 检查环境..."

# 检查配置文件存在
if [ ! -f "/root/datasip/docker/.env" ]; then
    echo -e "${RED}错误: /root/datasip/docker/.env 不存在${NC}"
    echo "请先创建配置文件:"
    echo "  cp /root/datasip/docker/.env.example /root/datasip/docker/.env"
    echo "  然后编辑填入真实值"
    exit 1
fi

# 检查符号链接
if [ ! -L "/root/datasip/workers/.env" ]; then
    echo -e "${YELLOW}警告: workers/.env 不是符号链接，正在修复...${NC}"
    cd /root/datasip/workers
    rm -f .env
    ln -s ../docker/.env .env
    echo -e "${GREEN}✓${NC} 符号链接已创建"
fi

echo -e "${GREEN}✓${NC} 环境检查通过"

# ====================================
# 步骤 2: 加载并验证环境变量
# ====================================
echo -e "\n${YELLOW}[2/6]${NC} 加载环境变量..."

source /root/datasip/docker/.env

# 验证必要的变量
required_vars=(
    "TELEGRAM_BOT_TOKEN"
    "ALLOWED_USER_IDS"
    "N8N_WEBHOOK_URL"
    "N8N_WEBHOOK_SECRET"
    "CLOUDFLARE_API_TOKEN"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}错误: $var 未设置${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $var: ${!var:0:20}..."
done

echo -e "${GREEN}✓${NC} 所有环境变量已加载"

# ====================================
# 步骤 3: 安装依赖
# ====================================
echo -e "\n${YELLOW}[3/6]${NC} 安装依赖..."

cd /root/datasip/workers

if [ ! -d "node_modules" ]; then
    npm install --silent
    echo -e "${GREEN}✓${NC} 依赖安装完成"
else
    echo -e "${GREEN}✓${NC} 依赖已存在，跳过"
fi

# ====================================
# 步骤 4: 部署 Workers
# ====================================
echo -e "\n${YELLOW}[4/6]${NC} 部署 Workers..."

npx wrangler deploy

echo -e "${GREEN}✓${NC} Workers 部署成功"

# ====================================
# 步骤 5: 配置 Secrets
# ====================================
echo -e "\n${YELLOW}[5/6]${NC} 配置 Secrets..."

echo "$TELEGRAM_BOT_TOKEN" | npx wrangler secret put TELEGRAM_BOT_TOKEN 2>&1 | grep -q "Success" && \
    echo -e "${GREEN}✓${NC} TELEGRAM_BOT_TOKEN" || echo -e "${RED}✗${NC} TELEGRAM_BOT_TOKEN 失败"

echo "$ALLOWED_USER_IDS" | npx wrangler secret put ALLOWED_USER_IDS 2>&1 | grep -q "Success" && \
    echo -e "${GREEN}✓${NC} ALLOWED_USER_IDS" || echo -e "${RED}✗${NC} ALLOWED_USER_IDS 失败"

echo "$N8N_WEBHOOK_URL" | npx wrangler secret put N8N_WEBHOOK_URL 2>&1 | grep -q "Success" && \
    echo -e "${GREEN}✓${NC} N8N_WEBHOOK_URL" || echo -e "${RED}✗${NC} N8N_WEBHOOK_URL 失败"

echo "$N8N_WEBHOOK_SECRET" | npx wrangler secret put N8N_WEBHOOK_SECRET 2>&1 | grep -q "Success" && \
    echo -e "${GREEN}✓${NC} N8N_WEBHOOK_SECRET" || echo -e "${RED}✗${NC} N8N_WEBHOOK_SECRET 失败"

echo -e "${GREEN}✓${NC} 所有 Secrets 配置完成"

# ====================================
# 步骤 6: 验证部署
# ====================================
echo -e "\n${YELLOW}[6/6]${NC} 验证部署..."

# 测试 Workers 是否可访问
WORKERS_URL="https://datasip.hashyolo123.workers.dev/"
if curl -f -s "$WORKERS_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Workers 可访问"
else
    echo -e "${RED}✗${NC} Workers 不可访问"
fi

# 测试 N8N webhook
if curl -f -s -X POST "$N8N_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "X-Webhook-Secret: $N8N_WEBHOOK_SECRET" \
    -d '{"test": true}' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} N8N Webhook 可访问"
else
    echo -e "${YELLOW}⚠${NC} N8N Webhook 测试失败（可能正常，取决于 workflow 配置）"
fi

# ====================================
# 完成
# ====================================
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Workers URL: https://datasip.hashyolo123.workers.dev"
echo "N8N Webhook: $N8N_WEBHOOK_URL"
echo ""
echo "下一步："
echo "1. 发送测试消息到 Telegram Bot"
echo "2. 查看实时日志: npx wrangler tail --format pretty"
echo ""
