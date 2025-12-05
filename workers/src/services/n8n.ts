import { Env, N8NPayload } from '../types';

/**
 * 发送数据到 N8N Webhook
 */
export async function sendToN8N(
  env: Env,
  payload: N8NPayload
): Promise<boolean> {
  try {
    const response = await fetch(env.N8N_WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Secret': env.N8N_WEBHOOK_SECRET,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.error('N8N webhook error:', response.status, await response.text());
      return false;
    }

    return true;
  } catch (error) {
    console.error('Failed to send to N8N:', error);
    return false;
  }
}

/**
 * 构建标准的 N8N Payload
 */
export function buildN8NPayload(
  type: N8NPayload['type'],
  options: Partial<N8NPayload>
): N8NPayload {
  return {
    type,
    timestamp: new Date().toISOString(),
    ...options,
  };
}
