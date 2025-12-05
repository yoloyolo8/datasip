import { Env, RSSItem } from '../types';
import { sendToN8N, buildN8NPayload } from '../services/n8n';

// 预置的 RSS 源列表 (MVP 阶段硬编码，后续从数据库读取)
const RSS_SOURCES = [
  // 在这里添加你的 RSS 源
  // { name: 'Hacker News', url: 'https://news.ycombinator.com/rss', type: 'rss' },
  // { name: 'TechCrunch', url: 'https://techcrunch.com/feed/', type: 'rss' },
];

/**
 * 定时抓取 RSS 源
 */
export async function fetchRSSFeeds(env: Env): Promise<void> {
  console.log('Starting RSS fetch job...');

  for (const source of RSS_SOURCES) {
    try {
      await fetchSingleRSS(env, source);
    } catch (error) {
      console.error(`Failed to fetch RSS from ${source.name}:`, error);
    }
  }

  console.log('RSS fetch job completed');
}

/**
 * 抓取单个 RSS 源
 */
async function fetchSingleRSS(
  env: Env,
  source: { name: string; url: string; type: string }
): Promise<void> {
  const response = await fetch(source.url, {
    headers: {
      'User-Agent': 'DataSip RSS Fetcher/1.0',
    },
  });

  if (!response.ok) {
    console.error(`RSS fetch failed for ${source.name}: ${response.status}`);
    return;
  }

  const xml = await response.text();
  const items = parseRSSItems(xml);

  console.log(`Fetched ${items.length} items from ${source.name}`);

  // 只处理最新的 5 条 (避免首次抓取太多)
  const recentItems = items.slice(0, 5);

  for (const item of recentItems) {
    const payload = buildN8NPayload('rss_item', {
      source: {
        name: source.name,
        url: source.url,
        type: source.type,
      },
      url: item.link,
      content: item.description || item.content,
      fetched_content: {
        title: item.title,
        text: item.description || item.content || '',
        url: item.link,
        fetched_at: new Date().toISOString(),
      },
    });

    await sendToN8N(env, payload);
  }
}

/**
 * 简单的 RSS XML 解析
 */
function parseRSSItems(xml: string): RSSItem[] {
  const items: RSSItem[] = [];

  // 匹配 <item> 标签
  const itemRegex = /<item[^>]*>([\s\S]*?)<\/item>/gi;
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const itemXml = match[1];

    const title = extractTag(itemXml, 'title');
    const link = extractTag(itemXml, 'link');
    const pubDate = extractTag(itemXml, 'pubDate');
    const description = extractTag(itemXml, 'description');
    const content = extractTag(itemXml, 'content:encoded');

    if (title && link) {
      items.push({
        title: decodeHtmlEntities(title),
        link,
        pubDate,
        description: description ? decodeHtmlEntities(description) : undefined,
        content: content ? decodeHtmlEntities(content) : undefined,
      });
    }
  }

  return items;
}

/**
 * 提取 XML 标签内容
 */
function extractTag(xml: string, tagName: string): string | undefined {
  // 处理 CDATA
  const cdataRegex = new RegExp(
    `<${tagName}[^>]*>\\s*<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>\\s*</${tagName}>`,
    'i'
  );
  const cdataMatch = xml.match(cdataRegex);
  if (cdataMatch) {
    return cdataMatch[1].trim();
  }

  // 普通标签
  const regex = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'i');
  const match = xml.match(regex);
  return match ? match[1].trim() : undefined;
}

/**
 * 解码 HTML 实体
 */
function decodeHtmlEntities(text: string): string {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}
