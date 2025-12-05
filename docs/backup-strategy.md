# 数据备份方案 (Backup Strategy)

**版本：** v1.0
**更新日期：** 2025-12-04

---

## 1. 备份范围

### 1.1 需要备份的数据

| 数据类型 | 位置 | 重要性 | 备份频率 |
|----------|------|--------|----------|
| PostgreSQL 数据库 | Docker Volume | **关键** | 每日 |
| N8N Workflow 配置 | Docker Volume | **重要** | 每周 + 变更后 |
| N8N Credentials | Docker Volume | **关键** | 每周 |
| Docker Compose 配置 | `/root/datasip/` | 重要 | Git 管理 |
| Nginx 配置 | `/root/datasip/nginx/` | 一般 | Git 管理 |
| 环境变量 | `.env` 文件 | **关键** | 加密备份 |

### 1.2 不需要备份的数据

- Docker 镜像（可从 Docker Hub 重新拉取）
- N8N 执行历史（可选择性保留最近 7 天）
- 临时日志文件

---

## 2. PostgreSQL 备份

### 2.1 自动每日备份脚本

创建备份脚本 `/root/datasip/scripts/backup-db.sh`:

```bash
#!/bin/bash
set -e

# 配置
BACKUP_DIR="/root/datasip/backups/postgres"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/datasip_${DATE}.sql.gz"

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 执行备份 (通过 Docker)
docker exec datasip-postgres pg_dump -U datasip -d datasip | gzip > ${BACKUP_FILE}

# 验证备份
if [ -s "${BACKUP_FILE}" ]; then
    echo "[$(date)] Backup successful: ${BACKUP_FILE}"
    echo "Size: $(du -h ${BACKUP_FILE} | cut -f1)"
else
    echo "[$(date)] ERROR: Backup failed or empty!"
    exit 1
fi

# 清理旧备份
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "[$(date)] Cleaned up backups older than ${RETENTION_DAYS} days"

# 可选：上传到远程存储
# aws s3 cp ${BACKUP_FILE} s3://your-bucket/datasip/postgres/
# rclone copy ${BACKUP_FILE} remote:datasip/backups/
```

### 2.2 设置 Cron 定时任务

```bash
# 编辑 crontab
crontab -e

# 添加每日凌晨 3 点执行备份
0 3 * * * /root/datasip/scripts/backup-db.sh >> /root/datasip/logs/backup.log 2>&1
```

### 2.3 手动备份命令

```bash
# 完整备份
docker exec datasip-postgres pg_dump -U datasip -d datasip > backup.sql

# 仅备份数据（不含 schema）
docker exec datasip-postgres pg_dump -U datasip -d datasip --data-only > data_only.sql

# 备份特定表
docker exec datasip-postgres pg_dump -U datasip -d datasip -t intentions -t data_inbox > core_tables.sql
```

### 2.4 恢复数据库

```bash
# 停止相关服务
docker-compose stop n8n

# 恢复数据库
gunzip -c /path/to/backup.sql.gz | docker exec -i datasip-postgres psql -U datasip -d datasip

# 或者先删除重建数据库
docker exec datasip-postgres psql -U datasip -c "DROP DATABASE IF EXISTS datasip_restore;"
docker exec datasip-postgres psql -U datasip -c "CREATE DATABASE datasip_restore;"
gunzip -c backup.sql.gz | docker exec -i datasip-postgres psql -U datasip -d datasip_restore

# 重启服务
docker-compose start n8n
```

---

## 3. N8N 备份

### 3.1 导出 Workflow

**方法 1：通过 N8N UI**
- 进入 N8N → Settings → Export → All workflows

**方法 2：通过 API**
```bash
# 获取所有 Workflow
curl -X GET "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: your-api-key" \
  > workflows_backup.json
```

**方法 3：直接备份 Volume**
```bash
#!/bin/bash
# /root/datasip/scripts/backup-n8n.sh

BACKUP_DIR="/root/datasip/backups/n8n"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p ${BACKUP_DIR}

# 备份 N8N 数据目录
docker run --rm \
  -v datasip_n8n_data:/source:ro \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/n8n_${DATE}.tar.gz -C /source .

echo "[$(date)] N8N backup completed: n8n_${DATE}.tar.gz"
```

### 3.2 备份 Credentials（加密）

N8N 的 Credentials 存储在数据库中，已包含在 PostgreSQL 备份中。但如果单独备份：

```bash
# 导出 credentials（需要 N8N 的加密密钥才能解密）
docker exec datasip-postgres pg_dump -U datasip -d n8n -t credentials_entity > credentials.sql
```

**重要：** 恢复 Credentials 需要保持相同的 `N8N_ENCRYPTION_KEY` 环境变量。

### 3.3 恢复 N8N

```bash
# 停止 N8N
docker-compose stop n8n

# 恢复数据卷
docker run --rm \
  -v datasip_n8n_data:/target \
  -v /root/datasip/backups/n8n:/backup \
  alpine sh -c "rm -rf /target/* && tar xzf /backup/n8n_YYYYMMDD_HHMMSS.tar.gz -C /target"

# 启动 N8N
docker-compose start n8n
```

---

## 4. 配置文件备份（Git）

### 4.1 Git 初始化

```bash
cd /root/datasip
git init
```

### 4.2 .gitignore 配置

```gitignore
# 敏感文件
.env
*.key
*.pem

# 备份文件（太大）
backups/

# 日志
logs/
*.log

# Docker volumes（由 Docker 管理）
volumes/

# 临时文件
*.tmp
*.swp
.DS_Store
```

### 4.3 推送到远程仓库

```bash
# 添加远程仓库（使用私有仓库！）
git remote add origin git@github.com:yourusername/datasip-config.git

# 首次推送
git add .
git commit -m "Initial project setup"
git push -u origin main
```

---

## 5. 环境变量备份

### 5.1 加密备份 .env

```bash
#!/bin/bash
# /root/datasip/scripts/backup-env.sh

BACKUP_DIR="/root/datasip/backups/env"
DATE=$(date +%Y%m%d)
BACKUP_FILE="${BACKUP_DIR}/env_${DATE}.enc"

mkdir -p ${BACKUP_DIR}

# 使用 GPG 加密
gpg --symmetric --cipher-algo AES256 -o ${BACKUP_FILE} /root/datasip/.env

echo "[$(date)] .env encrypted backup: ${BACKUP_FILE}"
```

### 5.2 恢复 .env

```bash
gpg --decrypt /path/to/env_YYYYMMDD.enc > /root/datasip/.env
```

---

## 6. 远程备份同步

### 6.1 使用 Rclone 同步到云存储

```bash
# 安装 rclone
curl https://rclone.org/install.sh | sudo bash

# 配置远程存储（例如 S3、Google Drive、Backblaze B2）
rclone config

# 同步备份目录
rclone sync /root/datasip/backups remote:datasip-backups --progress
```

### 6.2 自动化远程同步脚本

```bash
#!/bin/bash
# /root/datasip/scripts/sync-backups.sh

# 同步到远程存储
rclone sync /root/datasip/backups remote:datasip-backups \
  --transfers 4 \
  --checkers 8 \
  --log-file /root/datasip/logs/rclone.log \
  --log-level INFO

# 验证
if [ $? -eq 0 ]; then
    echo "[$(date)] Remote sync completed successfully"
else
    echo "[$(date)] ERROR: Remote sync failed!"
    # 可选：发送告警
fi
```

### 6.3 Cron 配置

```bash
# 每日凌晨 4 点同步（在本地备份完成后）
0 4 * * * /root/datasip/scripts/sync-backups.sh >> /root/datasip/logs/sync.log 2>&1
```

---

## 7. 完整备份流程

### 7.1 主备份脚本

```bash
#!/bin/bash
# /root/datasip/scripts/full-backup.sh

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/root/datasip/logs/backup_${TIMESTAMP}.log"

echo "========================================" | tee -a ${LOG_FILE}
echo "[$(date)] Starting full backup" | tee -a ${LOG_FILE}
echo "========================================" | tee -a ${LOG_FILE}

# 1. PostgreSQL 备份
echo "[$(date)] Step 1: Backing up PostgreSQL..." | tee -a ${LOG_FILE}
/root/datasip/scripts/backup-db.sh >> ${LOG_FILE} 2>&1

# 2. N8N 备份
echo "[$(date)] Step 2: Backing up N8N..." | tee -a ${LOG_FILE}
/root/datasip/scripts/backup-n8n.sh >> ${LOG_FILE} 2>&1

# 3. 环境变量备份
echo "[$(date)] Step 3: Backing up .env..." | tee -a ${LOG_FILE}
/root/datasip/scripts/backup-env.sh >> ${LOG_FILE} 2>&1

# 4. 同步到远程
echo "[$(date)] Step 4: Syncing to remote..." | tee -a ${LOG_FILE}
/root/datasip/scripts/sync-backups.sh >> ${LOG_FILE} 2>&1

echo "========================================" | tee -a ${LOG_FILE}
echo "[$(date)] Full backup completed!" | tee -a ${LOG_FILE}
echo "========================================" | tee -a ${LOG_FILE}
```

### 7.2 推荐的 Cron 配置汇总

```bash
# /etc/cron.d/datasip-backup

# PostgreSQL 每日备份 (凌晨 3:00)
0 3 * * * root /root/datasip/scripts/backup-db.sh >> /root/datasip/logs/backup.log 2>&1

# N8N 每周备份 (周日凌晨 3:30)
30 3 * * 0 root /root/datasip/scripts/backup-n8n.sh >> /root/datasip/logs/backup.log 2>&1

# 远程同步 (凌晨 4:00)
0 4 * * * root /root/datasip/scripts/sync-backups.sh >> /root/datasip/logs/sync.log 2>&1

# 日志清理 (每周一凌晨 5:00)
0 5 * * 1 root find /root/datasip/logs -name "*.log" -mtime +30 -delete
```

---

## 8. 灾难恢复检查清单

### 8.1 恢复前确认

- [ ] 确认备份文件完整性（检查大小、能否解压）
- [ ] 确认 `.env` 文件中的密钥（特别是 `N8N_ENCRYPTION_KEY`）
- [ ] 确认服务器环境（Docker、Docker Compose 已安装）

### 8.2 完整恢复步骤

```bash
# 1. 准备目录
mkdir -p /root/datasip
cd /root/datasip

# 2. 克隆配置仓库
git clone git@github.com:yourusername/datasip-config.git .

# 3. 恢复 .env
gpg --decrypt /path/to/env_backup.enc > .env

# 4. 启动数据库容器
docker-compose up -d postgres

# 5. 等待数据库就绪
sleep 10

# 6. 恢复数据库
gunzip -c /path/to/datasip_backup.sql.gz | docker exec -i datasip-postgres psql -U datasip -d datasip

# 7. 恢复 N8N 数据卷
docker run --rm \
  -v datasip_n8n_data:/target \
  -v /path/to/backups:/backup \
  alpine sh -c "tar xzf /backup/n8n_backup.tar.gz -C /target"

# 8. 启动所有服务
docker-compose up -d

# 9. 验证
curl http://localhost:5678/healthz
docker exec datasip-postgres psql -U datasip -d datasip -c "SELECT COUNT(*) FROM intentions;"
```

### 8.3 恢复后验证

- [ ] N8N Web UI 可访问
- [ ] 所有 Workflow 存在且可执行
- [ ] Credentials 可正常解密使用
- [ ] Telegram Bot 响应正常
- [ ] 数据库数据完整（检查关键表行数）

---

## 9. 备份监控

### 9.1 备份完成通知

在备份脚本末尾添加 Telegram 通知：

```bash
# 发送备份完成通知
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${ADMIN_CHAT_ID}" \
  -d text="✅ DataSip 备份完成
时间: $(date)
PostgreSQL: $(du -h ${PG_BACKUP_FILE} | cut -f1)
N8N: $(du -h ${N8N_BACKUP_FILE} | cut -f1)"
```

### 9.2 备份失败告警

```bash
# 在脚本开头设置错误处理
set -e
trap 'send_alert "Backup failed at step: $BASH_COMMAND"' ERR

send_alert() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${ADMIN_CHAT_ID}" \
    -d text="🚨 DataSip 备份失败
$1"
}
```

---

*此文档应在每次备份策略变更时更新。*
