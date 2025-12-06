#!/bin/bash
# ====================================
# DataSip 安全检查脚本
# ====================================
# 功能：检查代码库中是否有敏感信息泄露

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 DataSip 安全检查${NC}"
echo "================================"

# 切换到项目根目录
cd /root/datasip

# ====================================
# 检查 1: 查找可能的 API Keys
# ====================================
echo -e "\n${YELLOW}[1/5]${NC} 检查 API Keys..."

# 常见的 API Key 前缀
patterns=(
    "sk-[a-zA-Z0-9]{20,}"        # OpenAI style keys
    "gsk_[a-zA-Z0-9]{20,}"       # Gemini keys
    "xai-[a-zA-Z0-9]{20,}"       # xAI keys
    "AIza[a-zA-Z0-9]{20,}"       # Google API keys
    "[0-9]{10}:[A-Za-z0-9_-]{35}" # Telegram bot tokens
    "sk-or-v1-[a-f0-9]{64}"      # OpenRouter keys
)

found_issues=0

for pattern in "${patterns[@]}"; do
    # 排除 .env 文件（已在 .gitignore 中）和模板文件
    results=$(grep -rP "$pattern" \
        --exclude-dir=node_modules \
        --exclude-dir=.git \
        --exclude-dir=.wrangler \
        --exclude="*.env" \
        --exclude="*.example" \
        --exclude="*.template" \
        --exclude="security-check.sh" \
        . 2>/dev/null || true)

    if [ -n "$results" ]; then
        echo -e "${RED}✗ 发现可能的 API Key:${NC}"
        echo "$results"
        found_issues=$((found_issues + 1))
    fi
done

if [ $found_issues -eq 0 ]; then
    echo -e "${GREEN}✓${NC} 未发现 API Keys"
else
    echo -e "${RED}警告: 发现 $found_issues 个可能的敏感信息${NC}"
fi

# ====================================
# 检查 2: .env 文件是否在 .gitignore 中
# ====================================
echo -e "\n${YELLOW}[2/5]${NC} 检查 .gitignore 配置..."

if grep -q "^\.env$" .gitignore && \
   grep -q "^docker/\.env$" .gitignore && \
   grep -q "^workers/\.env$" .gitignore; then
    echo -e "${GREEN}✓${NC} .env 文件已正确配置在 .gitignore"
else
    echo -e "${RED}✗${NC} .gitignore 配置不完整"
    found_issues=$((found_issues + 1))
fi

# ====================================
# 检查 3: Git 历史中是否有 .env 文件
# ====================================
echo -e "\n${YELLOW}[3/5]${NC} 检查 Git 历史..."

if git log --all --full-history --source -- '*.env' 2>/dev/null | grep -q "commit"; then
    echo -e "${RED}✗ Git 历史中发现 .env 文件${NC}"
    echo "建议使用 git filter-branch 或 BFG Repo-Cleaner 清理"
    found_issues=$((found_issues + 1))
else
    echo -e "${GREEN}✓${NC} Git 历史中未发现 .env 文件"
fi

# ====================================
# 检查 4: 未跟踪的敏感文件
# ====================================
echo -e "\n${YELLOW}[4/5]${NC} 检查未跟踪的敏感文件..."

# 检查是否有 .env 文件未被 ignore
untracked_env=$(git status --porcelain 2>/dev/null | grep "\.env$" || true)

if [ -n "$untracked_env" ]; then
    echo -e "${YELLOW}⚠ 发现未跟踪的 .env 文件:${NC}"
    echo "$untracked_env"
    echo "确保这些文件在 .gitignore 中"
else
    echo -e "${GREEN}✓${NC} 没有未跟踪的 .env 文件"
fi

# ====================================
# 检查 5: wrangler.toml 中的敏感信息
# ====================================
echo -e "\n${YELLOW}[5/5]${NC} 检查 wrangler.toml..."

if grep -q "secret" workers/wrangler.toml && \
   ! grep -qP "(sk-|token.*=.*\w{20})" workers/wrangler.toml; then
    echo -e "${GREEN}✓${NC} wrangler.toml 配置正确（使用 secrets）"
elif grep -qP "(sk-|token.*=.*\w{20})" workers/wrangler.toml; then
    echo -e "${RED}✗${NC} wrangler.toml 中可能包含硬编码 secrets"
    found_issues=$((found_issues + 1))
else
    echo -e "${GREEN}✓${NC} wrangler.toml 未发现问题"
fi

# ====================================
# 总结
# ====================================
echo -e "\n${BLUE}================================${NC}"

if [ $found_issues -eq 0 ]; then
    echo -e "${GREEN}✅ 安全检查通过！${NC}"
    echo -e "${GREEN}未发现敏感信息泄露${NC}"
    exit 0
else
    echo -e "${RED}⚠️  发现 $found_issues 个安全问题${NC}"
    echo -e "${YELLOW}请修复以上问题后再提交代码${NC}"
    exit 1
fi
