# DataSip 自动化脚本说明

本目录包含 DataSip 项目的各种自动化脚本。

## 📋 脚本列表

### 1. 部署相关

#### `deploy-workers.sh`
**用途**：一键部署 Cloudflare Workers

**功能**：
- 检查环境配置
- 安装依赖
- 部署 Workers
- 配置 Secrets
- 验证部署

**使用方法**：
```bash
cd /root/datasip
./scripts/deploy-workers.sh
```

**前置条件**：
- 已配置 `/root/datasip/docker/.env`
- 已设置 CLOUDFLARE_API_TOKEN

---

### 2. N8N 配置

#### `configure-n8n.sh`
**用途**：配置 N8N Credentials（交互式）

**功能**：
- 创建 PostgreSQL Credential
- 创建 OpenRouter API Credential
- 验证连接

**使用方法**：
```bash
./scripts/configure-n8n.sh
```

#### `auto-configure-n8n.sh`
**用途**：自动化配置 N8N（非交互式）

**使用方法**：
```bash
./scripts/auto-configure-n8n.sh
```

---

### 3. 安全检查

#### `security-check.sh`
**用途**：检测代码库中的敏感信息泄露

**检查项**：
- API Keys 和 Tokens
- .gitignore 配置
- Git 历史中的敏感文件
- 未跟踪的 .env 文件
- wrangler.toml 配置

**使用方法**：
```bash
./scripts/security-check.sh
```

**自动化**：
- 在每次 `git commit` 前自动运行（通过 pre-commit hook）
- 如果检测到问题，会阻止提交

---

### 4. Git 工作流

#### `setup-git-hooks.sh`
**用途**：安装和配置 Git Hooks

**安装的 Hooks**：
- **pre-commit**: 运行安全检查
- **post-commit**: 提醒更新 TODO.md
- **pre-push**: 检查 TODO.md 是否已更新

**使用方法**：
```bash
./scripts/setup-git-hooks.sh
```

#### `update-todo.sh`
**用途**：快速更新 TODO.md 变更日志

**功能**：
- 交互式添加变更日志条目
- 可选自动提交

**使用方法**：
```bash
./scripts/update-todo.sh
```

**示例流程**：
```bash
# 完成了一些工作后
./scripts/update-todo.sh
# 输入: 完成 Jina Reader 优化
# 选择: 是否立即提交 (y/N): y
```

---

## 🔄 推荐工作流

### 日常开发流程

1. **开发代码**
   ```bash
   # 修改代码...
   ```

2. **运行安全检查**（可选，commit 时会自动运行）
   ```bash
   ./scripts/security-check.sh
   ```

3. **提交代码**
   ```bash
   git add .
   git commit -m "你的提交信息"
   # ✅ pre-commit hook 自动运行安全检查
   # 📝 post-commit hook 提醒更新 TODO.md
   ```

4. **更新 TODO.md**
   ```bash
   ./scripts/update-todo.sh
   # 或手动编辑 TODO.md
   ```

5. **推送到远程**
   ```bash
   git push origin main
   # 🚀 pre-push hook 检查 TODO.md 状态
   ```

### 部署 Workers 流程

```bash
# 1. 确保环境配置正确
cat /root/datasip/docker/.env

# 2. 运行部署脚本
./scripts/deploy-workers.sh

# 3. 验证部署
curl https://datasip.hashyolo123.workers.dev/

# 4. 查看实时日志
cd /root/datasip/workers
npx wrangler tail --format pretty
```

### 初次设置流程

```bash
# 1. 安装 Git Hooks
./scripts/setup-git-hooks.sh

# 2. 配置 N8N
./scripts/configure-n8n.sh

# 3. 部署 Workers
./scripts/deploy-workers.sh

# 4. 运行安全检查
./scripts/security-check.sh
```

---

## 🛡️ 安全提示

1. **永远不要提交敏感信息**
   - API Keys、Tokens、密码应该在 `.env` 文件中
   - `.env` 文件已配置在 `.gitignore` 中
   - 使用模板文件（`.env.example`, `.env.template`）

2. **使用 pre-commit hook**
   - 自动运行安全检查
   - 如果发现问题会阻止提交

3. **定期运行安全检查**
   ```bash
   ./scripts/security-check.sh
   ```

4. **Cloudflare Workers Secrets**
   - 敏感变量通过 `wrangler secret put` 设置
   - 不要在 `wrangler.toml` 中硬编码

---

## 📝 维护说明

### 添加新脚本

1. 创建脚本文件：`scripts/your-script.sh`
2. 添加文件头注释
3. 设置可执行权限：`chmod +x scripts/your-script.sh`
4. 更新本 README

### 修改 Git Hooks

Git Hooks 位于 `.git/hooks/` 目录：
- `pre-commit` - 提交前运行
- `post-commit` - 提交后运行
- `pre-push` - 推送前运行

修改后运行 `./scripts/setup-git-hooks.sh` 重新安装。

---

## 🆘 故障排除

### 脚本权限问题

```bash
chmod +x scripts/*.sh
```

### Git Hooks 不生效

```bash
./scripts/setup-git-hooks.sh
```

### 安全检查误报

编辑 `scripts/security-check.sh`，在 `grep` 命令中添加 `--exclude` 参数。

---

**维护者**: DataSip Team
**最后更新**: 2025-12-06
