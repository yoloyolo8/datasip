import { FetchedContent } from '../types';

/**
 * 使用 Jina Reader 抓取网页内容
 * Jina Reader API: https://r.jina.ai/{url}
 */
export async function fetchWithJina(url: string): Promise<FetchedContent | null> {
  try {
    const jinaUrl = `https://r.jina.ai/${encodeURIComponent(url)}`;

    const response = await fetch(jinaUrl, {
      headers: {
        Accept: 'text/plain',
      },
    });

    if (!response.ok) {
      console.error(`Jina fetch failed for ${url}: ${response.status}`);
      return null;
    }

    const text = await response.text();

    // 尝试从 Jina 返回的 Markdown 中提取标题
    const titleMatch = text.match(/^#\s+(.+)$/m);
    const title = titleMatch ? titleMatch[1] : undefined;

    return {
      url,
      title,
      text,
      fetched_at: new Date().toISOString(),
      word_count: text.split(/\s+/).length,
    };
  } catch (error) {
    console.error(`Failed to fetch ${url} with Jina:`, error);
    return null;
  }
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
