import { Env } from '../types';
import { fetchRSSFeeds } from './rss';
import { sendToN8N, buildN8NPayload } from '../services/n8n';

/**
 * 处理定时任务
 */
export async function handleScheduled(
  event: ScheduledEvent,
  env: Env
): Promise<void> {
  const cron = event.cron;
  console.log(`Cron triggered: ${cron}`);

  switch (cron) {
    case '0 * * * *':
      // 每小时: RSS 抓取
      await fetchRSSFeeds(env);
      break;

    case '0 */2 * * *':
      // 每 2 小时: YouTube 抓取 (待实现)
      console.log('YouTube fetch not yet implemented');
      break;

    case '0 20 * * *':
      // 每天 20:00: 触发 N8N 的每日匹配
      await triggerDailyMatch(env);
      break;

    default:
      console.log(`Unknown cron: ${cron}`);
  }
}

/**
 * 触发 N8N 的每日匹配任务
 */
async function triggerDailyMatch(env: Env): Promise<void> {
  const payload = buildN8NPayload('cron_trigger', {
    content: 'daily_match',
  });

  const success = await sendToN8N(env, payload);

  if (success) {
    console.log('Daily match triggered successfully');
  } else {
    console.error('Failed to trigger daily match');
  }
}
