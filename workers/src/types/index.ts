// Cloudflare Worker 环境变量类型
export interface Env {
  // Telegram
  TELEGRAM_BOT_TOKEN: string;
  ALLOWED_USER_IDS: string; // 逗号分隔的 User IDs

  // N8N 通信
  N8N_WEBHOOK_URL: string;
  N8N_WEBHOOK_SECRET: string;

  // 环境
  ENVIRONMENT: string;
}

// Telegram 消息类型
export interface TelegramUpdate {
  update_id: number;
  message?: TelegramMessage;
}

export interface TelegramMessage {
  message_id: number;
  from: {
    id: number;
    is_bot: boolean;
    first_name: string;
    username?: string;
  };
  chat: {
    id: number;
    type: string;
  };
  date: number;
  text?: string;
  entities?: TelegramEntity[];
}

export interface TelegramEntity {
  type: string; // 'url', 'text_link', 'bot_command', etc.
  offset: number;
  length: number;
  url?: string;
}

// 发送到 N8N 的消息类型
export interface N8NPayload {
  type: 'text' | 'url' | 'command' | 'rss_item' | 'youtube_item' | 'cron_trigger';
  timestamp: string;
  telegram?: {
    user_id: number;
    chat_id: number;
    message_id: number;
    username?: string;
  };
  content?: string;
  url?: string;
  fetched_content?: FetchedContent;
  command?: {
    name: string;
    args: string;
  };
  source?: {
    name: string;
    url: string;
    type: string;
  };
}

// 抓取的内容
export interface FetchedContent {
  title?: string;
  text?: string;
  html?: string;
  url: string;
  fetched_at: string;
  word_count?: number;
}

// RSS Feed 条目
export interface RSSItem {
  title: string;
  link: string;
  pubDate?: string;
  description?: string;
  content?: string;
}
