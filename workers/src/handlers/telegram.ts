import { Env, TelegramUpdate, TelegramMessage, N8NPayload } from '../types';
import { sendTelegramMessage, isUserAllowed } from '../services/telegram';
import { fetchWithJina, extractUrls } from '../services/jina';
import { sendToN8N, buildN8NPayload } from '../services/n8n';

/**
 * 处理 Telegram Webhook 请求
 */
export async function handleTelegramWebhook(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    const update: TelegramUpdate = await request.json();

    // 只处理消息
    if (!update.message) {
      return new Response('OK', { status: 200 });
    }

    const message = update.message;
    const userId = message.from.id;
    const chatId = message.chat.id;

    // 白名单校验
    if (!isUserAllowed(env, userId)) {
      console.log(`Unauthorized user: ${userId}`);
      return new Response('OK', { status: 200 });
    }

    // 处理消息
    await processMessage(env, message);

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Telegram webhook error:', error);
    return new Response('OK', { status: 200 }); // 始终返回 200 避免重试
  }
}

/**
 * 处理具体消息
 */
async function processMessage(env: Env, message: TelegramMessage): Promise<void> {
  const text = message.text || '';
  const chatId = message.chat.id;

  // 检查是否是命令
  if (text.startsWith('/')) {
    await handleCommand(env, message);
    return;
  }

  // 检查是否包含 URL
  const urls = extractUrls(text);

  if (urls.length > 0) {
    await handleUrlMessage(env, message, urls);
  } else {
    await handleTextMessage(env, message);
  }
}

/**
 * 处理命令
 */
async function handleCommand(env: Env, message: TelegramMessage): Promise<void> {
  const text = message.text || '';
  const parts = text.split(' ');
  const command = parts[0].toLowerCase().replace('/', '');
  const args = parts.slice(1).join(' ');

  const chatId = message.chat.id;

  // 直接在 Worker 处理的简单命令
  if (command === 'start') {
    await sendTelegramMessage(
      env,
      chatId,
      `欢迎使用 DataSip!\n\n` +
        `发送文本 → 记录为意图/问题\n` +
        `发送链接 → 抓取并分析内容\n\n` +
        `命令:\n` +
        `/list - 查看待解决的问题\n` +
        `/sources - 查看订阅源\n` +
        `/digest - 获取今日摘要\n` +
        `/help - 帮助信息`
    );
    return;
  }

  if (command === 'help') {
    await sendTelegramMessage(
      env,
      chatId,
      `<b>DataSip 帮助</b>\n\n` +
        `<b>基本用法:</b>\n` +
        `• 发送文本 → 记录为意图/问题\n` +
        `• 发送链接 → 抓取内容并推理意图\n\n` +
        `<b>命令:</b>\n` +
        `/list - 查看待解决的问题\n` +
        `/resolve &lt;id&gt; - 标记问题为已解决\n` +
        `/sources - 查看订阅源列表\n` +
        `/add &lt;url&gt; - 添加订阅源\n` +
        `/digest - 获取今日摘要\n` +
        `/stats - 查看统计信息`
    );
    return;
  }

  // 其他命令转发到 N8N
  const payload = buildN8NPayload('command', {
    telegram: {
      user_id: message.from.id,
      chat_id: chatId,
      message_id: message.message_id,
      username: message.from.username,
    },
    command: { name: command, args },
  });

  await sendToN8N(env, payload);
}

/**
 * 处理包含 URL 的消息
 */
async function handleUrlMessage(
  env: Env,
  message: TelegramMessage,
  urls: string[]
): Promise<void> {
  const chatId = message.chat.id;

  // 快速响应
  await sendTelegramMessage(env, chatId, '📥 收到链接，正在抓取...');

  // 抓取第一个 URL
  const url = urls[0];
  const content = await fetchWithJina(url);

  if (!content) {
    await sendTelegramMessage(env, chatId, '❌ 抓取失败，请稍后重试');
    return;
  }

  // 发送到 N8N 处理
  const payload = buildN8NPayload('url', {
    telegram: {
      user_id: message.from.id,
      chat_id: chatId,
      message_id: message.message_id,
      username: message.from.username,
    },
    url,
    content: message.text,
    fetched_content: content,
  });

  const success = await sendToN8N(env, payload);

  if (!success) {
    await sendTelegramMessage(
      env,
      chatId,
      '⚠️ 内容已抓取，但处理服务暂时不可用，稍后将自动重试'
    );
  }
}

/**
 * 处理纯文本消息 (作为意图)
 */
async function handleTextMessage(
  env: Env,
  message: TelegramMessage
): Promise<void> {
  const chatId = message.chat.id;

  // 快速响应
  await sendTelegramMessage(env, chatId, '📝 收到，正在分析...');

  // 发送到 N8N 处理
  const payload = buildN8NPayload('text', {
    telegram: {
      user_id: message.from.id,
      chat_id: chatId,
      message_id: message.message_id,
      username: message.from.username,
    },
    content: message.text,
  });

  const success = await sendToN8N(env, payload);

  if (!success) {
    await sendTelegramMessage(
      env,
      chatId,
      '⚠️ 消息已收到，但处理服务暂时不可用，稍后将自动重试'
    );
  }
}
