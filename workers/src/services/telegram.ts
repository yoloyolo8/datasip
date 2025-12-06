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
    const url = `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`;
    const payload = {
      chat_id: chatId,
      text: text,
      parse_mode: parseMode,
    };

    console.log('Sending to Telegram:', { url: url.substring(0, 50) + '...', chatId, textLength: text.length });

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const responseText = await response.text();

    if (!response.ok) {
      console.error('Telegram API error:', responseText);
      return false;
    }

    console.log('Telegram API success');
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
  console.log('Checking user authorization:', {
    userId,
    userIdType: typeof userId,
    rawAllowedIds: env.ALLOWED_USER_IDS,
  });

  const allowedIds = env.ALLOWED_USER_IDS.split(',').map((id) =>
    parseInt(id.trim(), 10)
  );

  console.log('Parsed allowed IDs:', allowedIds);
  console.log('Is user allowed?', allowedIds.includes(userId));

  return allowedIds.includes(userId);
}
