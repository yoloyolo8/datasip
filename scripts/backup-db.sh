#!/bin/bash
set -e

# DataSip PostgreSQL 备份脚本

BACKUP_DIR="/root/datasip/backups/postgres"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/datasip_${DATE}.sql.gz"

# 创建备份目录
mkdir -p ${BACKUP_DIR}

# 执行备份
echo "[$(date)] Starting PostgreSQL backup..."
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
