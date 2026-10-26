import { defineI18nUI } from 'fumadocs-ui/i18n';

const zhUi = {
  displayName: '中文',
  'Choose a language(language switcher)': '选择语言',
  'Choose a language(language switcher)(aria-label)': '选择语言',
  'Search(search dialog)': '搜索',
  'Search(search trigger)': '搜索',
  'Open Search(search trigger)(aria-label)': '打开搜索',
  'Close Search(search dialog)(aria-label)': '关闭搜索',
  'No results found(search dialog)': '没有结果',
  'Search failed(search dialog)': '搜索失败',
  'Search failed, showing results for {query}(search dialog)': '搜索失败，正在显示“{query}”的结果',
  'On this page(table of contents)': '本页目录',
  'Table of Contents(inline table of contents)': '目录',
  'No Headings(table of contents)': '没有标题',
  'Next Page(pagination)': '下一页',
  'Previous Page(pagination)': '上一页',
  'Edit on GitHub(edit page)': '在 GitHub 上编辑',
  'Last updated on(page footer)': '更新于',
  'Toggle Theme(theme switcher)(aria-label)': '切换主题',
  'Light(theme switcher)(aria-label)': '浅色',
  'Dark(theme switcher)(aria-label)': '深色',
  'System(theme switcher)(aria-label)': '跟随系统',
  'Open Sidebar(sidebar)(aria-label)': '打开侧栏',
  'Close Sidebar(sidebar)(aria-label)': '关闭侧栏',
  'Close Sidebar(aria-label)': '关闭侧栏',
  'Collapse Sidebar(sidebar)(aria-label)': '收起侧栏',
  'Hide Sidebar(sidebar)': '隐藏侧栏',
  'Show Sidebar(sidebar)': '显示侧栏',
  'Toggle Menu(mobile menu)(aria-label)': '打开菜单',
  'Page Not Found(404 page)': '找不到页面',
  'Back to Home(404 page)': '回到首页',
  'The page you are looking for might have been removed, had its name changed, or is temporarily unavailable.(404 page)':
    '页面可能已删除、改名，或暂时无法打开。',
};

export const i18n = defineI18nUI(
  {
    defaultLanguage: 'en',
    languages: ['en', 'zh'],
    hideLocale: 'default-locale',
    parser: 'dot',
    fallbackLanguage: 'en',
  },
  {
    en: { displayName: 'English' },
    zh: zhUi,
  },
);

export type Locale = (typeof i18n.languages)[number];
