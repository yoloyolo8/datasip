#!/bin/bash
# ====================================
# Git Hooks 安装脚本
# ====================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 安装 Git Hooks...${NC}"
echo "================================"

HOOKS_DIR="/root/datasip/.git/hooks"

# 确保 hooks 目录存在
mkdir -p "$HOOKS_DIR"

# 设置可执行权限
chmod +x "$HOOKS_DIR/pre-commit" 2>/dev/null || true
chmod +x "$HOOKS_DIR/post-commit" 2>/dev/null || true
chmod +x "$HOOKS_DIR/pre-push" 2>/dev/null || true

echo -e "${GREEN}✓${NC} pre-commit:  运行安全检查"
echo -e "${GREEN}✓${NC} post-commit: 提醒更新 TODO.md"
echo -e "${GREEN}✓${NC} pre-push:    检查 TODO.md 状态"

echo ""
echo -e "${GREEN}✅ Git Hooks 安装完成！${NC}"
echo ""
echo "说明："
echo "  - 每次提交前会自动运行安全检查"
echo "  - 提交后会提醒更新 TODO.md"
echo "  - 推送前会检查 TODO.md 是否已更新"
echo ""
