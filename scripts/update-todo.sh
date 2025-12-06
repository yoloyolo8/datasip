#!/bin/bash
# ====================================
# TODO.md 更新助手
# ====================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}📝 TODO.md 更新助手${NC}"
echo "================================"
echo ""

# 获取今天的日期
TODAY=$(date +%Y-%m-%d)

echo "添加新的变更日志条目："
echo -e "${YELLOW}日期:${NC} $TODAY"
echo ""
echo -n "请输入变更描述: "
read CHANGE_DESC

if [ -z "$CHANGE_DESC" ]; then
    echo "❌ 描述不能为空"
    exit 1
fi

# 在 TODO.md 的变更日志部分添加新条目
# 查找变更日志的最后一行，在其上方插入新条目
sed -i "/^| 2025-12-06 | Git 同步/a| $TODAY | $CHANGE_DESC |" /root/datasip/TODO.md

echo ""
echo -e "${GREEN}✅ 已添加到 TODO.md 变更日志${NC}"
echo ""

# 显示最近的变更日志
echo "最近的变更日志："
echo "---"
grep "^| 2025-" /root/datasip/TODO.md | tail -5
echo ""

# 询问是否需要提交
read -p "是否立即提交此更改? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd /root/datasip
    git add TODO.md
    git commit -m "Update TODO.md: $CHANGE_DESC"
    echo ""
    echo -e "${GREEN}✅ TODO.md 已提交${NC}"
else
    echo "提示：记得手动提交 TODO.md"
fi
