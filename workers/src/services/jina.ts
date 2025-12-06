import { FetchedContent } from '../types';

/**
 * 使用 Jina Reader 抓取网页内容（带重试机制）
 * Jina Reader API: https://r.jina.ai/{url}
 */
export async function fetchWithJina(url: string): Promise<FetchedContent | null> {
  const maxRetries = 3;
  const retryDelays = [1000, 3000, 5000]; // 1s, 3s, 5s 指数退避

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const jinaUrl = `https://r.jina.ai/${encodeURIComponent(url)}`;

      console.log(`Fetching ${url} with Jina (attempt ${attempt + 1}/${maxRetries})...`);

      const response = await fetch(jinaUrl, {
        headers: {
          Accept: 'text/plain',
          'User-Agent': 'DataSip/1.0 (https://github.com/yourusername/datasip)',
        },
      });

      // 429 速率限制 - 重试
      if (response.status === 429) {
        if (attempt < maxRetries - 1) {
          const delay = retryDelays[attempt];
          console.log(`Jina 速率限制 (429)，${delay}ms 后重试 (${attempt + 1}/${maxRetries})...`);
          await sleep(delay);
          continue;
        } else {
          console.error(`Jina Reader 达到最大重试次数，放弃抓取: ${url}`);
          return null;
        }
      }

      // 其他错误状态
      if (!response.ok) {
        console.error(`Jina fetch failed for ${url}: ${response.status} ${response.statusText}`);
        // 非 429 错误不重试，直接返回
        return null;
      }

      // 成功获取内容
      const text = await response.text();

      // 尝试从 Jina 返回的 Markdown 中提取标题
      const titleMatch = text.match(/^#\s+(.+)$/m);
      const title = titleMatch ? titleMatch[1] : undefined;

      console.log(`Successfully fetched ${url} (${text.length} chars)`);

      return {
        url,
        title,
        text,
        fetched_at: new Date().toISOString(),
        word_count: text.split(/\s+/).length,
      };

    } catch (error) {
      console.error(`Failed to fetch ${url} with Jina (attempt ${attempt + 1}):`, error);

      // 如果是最后一次尝试，返回 null
      if (attempt === maxRetries - 1) {
        return null;
      }

      // 否则等待后重试
      const delay = retryDelays[attempt];
      console.log(`Waiting ${delay}ms before retry...`);
      await sleep(delay);
    }
  }

  return null;
}

/**
 * 辅助函数：延迟执行
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 简单的 URL 验证
 */
export function isValidUrl(text: string): boolean {
  try {
    const url = new URL(text);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * 从文本中提取 URL
 */
export function extractUrls(text: string): string[] {
  const urlRegex = /https?:\/\/[^\s<>"{}|\\^`[\]]+/g;
  return text.match(urlRegex) || [];
}
