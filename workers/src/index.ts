/**
 * DataSip Cloudflare Worker
 *
 * 职责:
 * 1. 接收 Telegram Webhook，快速响应并转发到 N8N
 * 2. 定时抓取 RSS/YouTube
 * 3. 使用 Jina Reader 抓取网页内容
 */

import { Env } from './types';
import { handleTelegramWebhook } from './handlers/telegram';
import { handleScheduled } from './handlers/cron';

export default {
  /**
   * 处理 HTTP 请求
   */
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // 健康检查
    if (url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'ok',
          timestamp: new Date().toISOString(),
          version: '1.0.0',
        }),
        {
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Telegram Webhook
    // 路径格式: /webhook/telegram 或 /telegram
    if (
      url.pathname === '/webhook/telegram' ||
      url.pathname === '/telegram'
    ) {
      if (request.method !== 'POST') {
        return new Response('Method Not Allowed', { status: 405 });
      }
      return handleTelegramWebhook(request, env);
    }

    // 手动触发 (调试用)
    if (url.pathname === '/trigger/rss' && env.ENVIRONMENT !== 'production') {
      const { fetchRSSFeeds } = await import('./handlers/rss');
      ctx.waitUntil(fetchRSSFeeds(env));
      return new Response('RSS fetch triggered', { status: 200 });
    }

    // 404
    return new Response('Not Found', { status: 404 });
  },

  /**
   * 处理定时任务
   */
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(handleScheduled(event, env));
  },
};
