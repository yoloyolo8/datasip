import { Env } from '../types';

/**
 * 发送 Telegram 消息
 */
export async function sendTelegramMessage(
  env: Env,
  chatId: number,
  text: string,
  parseMode: 'HTML' | 'Markdown' = 'HTML'
): Promise<boolean> {
  try {
    const response = await fetch(
      `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: text,
          parse_mode: parseMode,
        }),
      }
    );

    if (!response.ok) {
      console.error('Telegram API error:', await response.text());
      return false;
    }

    return true;
  } catch (error) {
    console.error('Failed to send Telegram message:', error);
    return false;
  }
}

/**
 * 检查用户是否在白名单中
 */
export function isUserAllowed(env: Env, userId: number): boolean {
  const allowedIds = env.ALLOWED_USER_IDS.split(',').map((id) =>
    parseInt(id.trim(), 10)
  );
  return allowedIds.includes(userId);
}
