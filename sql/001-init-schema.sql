-- DataSip Database Schema
-- Version: 1.0
-- Date: 2025-12-04

-- Enable pgvector extension (for Phase 2)
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- Table: intentions (意图库)
-- ============================================
CREATE TABLE IF NOT EXISTS intentions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 核心内容
    content         TEXT NOT NULL,
    intent_type     TEXT DEFAULT 'explicit',    -- 'explicit' | 'implicit'
    source_type     TEXT NOT NULL,              -- 'text' | 'link_inference' | 'diary'
    source_context  TEXT,
    source_data_id  UUID,                       -- 关联到 data_inbox

    -- 状态管理
    status          TEXT DEFAULT 'open',        -- 'open' | 'resolved' | 'archived'
    priority        INT DEFAULT 5,              -- 1-10

    -- 解决信息
    resolved_at     TIMESTAMPTZ,
    solution_summary TEXT,

    -- Phase 2: 向量搜索
    embedding       vector(1536)
);

CREATE INDEX IF NOT EXISTS idx_intentions_status ON intentions(status);
CREATE INDEX IF NOT EXISTS idx_intentions_created ON intentions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_intentions_source_data ON intentions(source_data_id);

-- ============================================
-- Table: source_list (订阅源管理)
-- ============================================
CREATE TABLE IF NOT EXISTS source_list (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 源信息
    name            TEXT NOT NULL,
    url             TEXT NOT NULL UNIQUE,
    source_type     TEXT NOT NULL,              -- 'rss' | 'youtube' | 'newsletter'

    -- 管理
    status          TEXT DEFAULT 'active',      -- 'active' | 'paused' | 'review_needed'
    weight          INT DEFAULT 5,              -- 1-10
    fetch_interval  INT DEFAULT 60,             -- 分钟

    -- 追踪
    last_fetched_at TIMESTAMPTZ,
    last_item_at    TIMESTAMPTZ,
    total_items     INT DEFAULT 0,
    matched_items   INT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_source_list_status ON source_list(status);
CREATE INDEX IF NOT EXISTS idx_source_list_type ON source_list(source_type);

-- ============================================
-- Table: data_inbox (存量库)
-- ============================================
CREATE TABLE IF NOT EXISTS data_inbox (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    -- 基础信息
    url             TEXT UNIQUE,
    title           TEXT,
    content_type    TEXT NOT NULL,              -- 'blog' | 'youtube' | 'tweet' | 'manual'

    -- 核心资产
    raw_content     JSONB NOT NULL,

    -- AI 处理结果
    summary         TEXT,
    tags            TEXT[],
    language        TEXT,

    -- 来源追踪
    source_id       UUID REFERENCES source_list(id) ON DELETE SET NULL,
    is_manual       BOOLEAN DEFAULT FALSE,

    -- Phase 2: 向量搜索
    embedding       vector(1536)
);

CREATE INDEX IF NOT EXISTS idx_data_inbox_created ON data_inbox(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_data_inbox_content_type ON data_inbox(content_type);
CREATE INDEX IF NOT EXISTS idx_data_inbox_tags ON data_inbox USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_data_inbox_source ON data_inbox(source_id);

-- Add foreign key to intentions after data_inbox exists
ALTER TABLE intentions
    ADD CONSTRAINT fk_intentions_source_data
    FOREIGN KEY (source_data_id)
    REFERENCES data_inbox(id)
    ON DELETE SET NULL;

-- ============================================
-- Table: intention_data_links (关联表)
-- ============================================
CREATE TABLE IF NOT EXISTS intention_data_links (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    intention_id    UUID NOT NULL REFERENCES intentions(id) ON DELETE CASCADE,
    data_id         UUID NOT NULL REFERENCES data_inbox(id) ON DELETE CASCADE,

    relevance_score FLOAT,
    is_solution     BOOLEAN DEFAULT FALSE,
    user_feedback   TEXT,                       -- 'helpful' | 'not_helpful' | NULL

    UNIQUE(intention_id, data_id)
);

CREATE INDEX IF NOT EXISTS idx_links_intention ON intention_data_links(intention_id);
CREATE INDEX IF NOT EXISTS idx_links_data ON intention_data_links(data_id);

-- ============================================
-- Table: error_logs (错误日志)
-- ============================================
CREATE TABLE IF NOT EXISTS error_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    severity        TEXT NOT NULL,              -- 'P0' | 'P1' | 'P2' | 'P3'
    error_type      TEXT NOT NULL,              -- 'network' | 'api' | 'parse' | 'database'

    workflow_name   TEXT,
    node_name       TEXT,
    error_message   TEXT NOT NULL,
    stack_trace     TEXT,

    input_data      JSONB,

    retry_count     INT DEFAULT 0,
    resolved        BOOLEAN DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    resolution_note TEXT
);

CREATE INDEX IF NOT EXISTS idx_error_logs_severity ON error_logs(severity);
CREATE INDEX IF NOT EXISTS idx_error_logs_created ON error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_unresolved ON error_logs(resolved) WHERE resolved = FALSE;

-- ============================================
-- Table: pending_tasks (待处理队列)
-- ============================================
CREATE TABLE IF NOT EXISTS pending_tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    task_type       TEXT NOT NULL,              -- 'intention_extract' | 'content_fetch' | 'notification'
    payload         JSONB NOT NULL,

    retry_count     INT DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,

    status          TEXT DEFAULT 'pending',     -- 'pending' | 'processing' | 'completed' | 'failed'
    error_message   TEXT
);

CREATE INDEX IF NOT EXISTS idx_pending_tasks_status ON pending_tasks(status);
CREATE INDEX IF NOT EXISTS idx_pending_tasks_next_retry ON pending_tasks(next_retry_at);

-- ============================================
-- Function: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_intentions_updated_at
    BEFORE UPDATE ON intentions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Initial data: Sample sources (optional)
-- ============================================
-- INSERT INTO source_list (name, url, source_type) VALUES
--     ('Hacker News', 'https://news.ycombinator.com/rss', 'rss'),
--     ('TechCrunch', 'https://techcrunch.com/feed/', 'rss');

COMMENT ON TABLE intentions IS '意图库 - 存储用户的问题和隐性意图';
COMMENT ON TABLE data_inbox IS '存量库 - 存储抓取的内容';
COMMENT ON TABLE source_list IS '订阅源管理 - RSS/YouTube 等订阅源';
COMMENT ON TABLE intention_data_links IS '关联表 - 记录意图与数据的匹配关系';
COMMENT ON TABLE error_logs IS '错误日志 - 记录系统错误';
COMMENT ON TABLE pending_tasks IS '待处理队列 - 失败重试队列';
