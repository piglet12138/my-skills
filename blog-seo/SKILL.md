---
name: blog-seo
description: 为 sg.yaoyuheng2001.me 独立博客发布新文章时执行的完整流程，包括 Astro 源码页面生成、SEO 元数据、站点级更新、构建部署。以 focus-whitepaper 为写作标准。
version: 2.0.0
tags: [seo, blog, astro, deployment, nginx]
triggers:
  - /blog-seo
---

# /blog-seo — 博客文章发布 & SEO 清单 v2

## 重要：服务器优先工作流

**所有操作直接在服务器上执行**（SSH root@167.71.197.117），不在本地修改后覆盖服务器。

```
编辑 → 服务器上 src/pages/ 修改 Astro 源码
构建 → 服务器上 npx astro build
同步 → 服务器上 git add + commit + push
```

## 站点基本信息

- **域名**: sg.yaoyuheng2001.me
- **服务器**: DigitalOcean Droplet, SSH pubkey auth, IP 167.71.197.117
- **博客源码**: `/root/blog/` (Astro v6+ 项目)
- **构建输出**: `/root/blog/dist/` (Nginx 直接 serve)
- **Node.js**: `export NVM_DIR=/root/.nvm && source /root/.nvm/nvm.sh`
- **GitHub**: https://github.com/piglet12138/blog.git

## 写作标准：参照 focus-whitepaper

所有新文章必须是 **Astro 源码文件** (`.astro`)，放在 `src/pages/posts/POST_SLUG/index.astro`。以 `/posts/focus-whitepaper/index.astro` 为标准模板。

### 页面类型

| 类型 | 字数 | 布局 | 参考 |
|------|------|------|------|
| 短文/博客 | < 5000 字 | `.page` 布局，无侧边栏 | `claude-ai-harness/index.astro` |
| 白皮书/长文 | > 5000 字 | `.page` + `toc-sidebar` 侧边栏目录 | `focus-whitepaper/index.astro` |
| 交互/可视化 | 不限 | 自定义全屏布局 | `latent-space/index.astro`, `warp-social-media/index.astro` |

### Astro 源码结构（必须遵循）

```astro
---
import Analytics from "../../../components/Analytics.astro";
const title = "文章标题";
const description = "50-160 字描述";
const url = "https://sg.yaoyuheng2001.me/posts/POST_SLUG/";
const datePublished = "YYYY-MM-DD";

// 长文需要 TOC 数据
const toc = [
  { id: "s0", label: "序言", part: null },
  { id: "s1", label: "第一章　标题", part: "第一部分　大标题" },
  // ...
];

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": title,
  "description": description,
  "url": url,
  "datePublished": datePublished,
  "inLanguage": "zh-CN",
  "author": {"@type":"Person","name":"Yao Yuheng","url":"https://sg.yaoyuheng2001.me/"},
  "mainEntityOfPage": url,
  "keywords": "关键词1, 关键词2"
};
---
```

### CSS 设计系统

两种样式体系，选其一：

#### A. 暖羊皮纸风格（短文/技术博客）

来自 `claude-ai-harness/index.astro`，适合技术文章：

```css
body { background:#f4efe7; color:#2a2118; font-family: "DM Sans", -apple-system, sans-serif; line-height:1.75; }
h1 { font-family: Georgia, serif; font-size:clamp(28px,5vw,42px); font-weight:500; }
h2 { font-family: Georgia, serif; font-size:22px; font-weight:500; margin:36px 0 14px; padding-top:24px; border-top:1px solid #e4d7c6; }
a { color:#96432a; }
blockquote { border-left:3px solid #d4c8b6; padding-left:16px; color:#5a4f44; font-style:italic; }
pre { background:#1e1a16; color:#e8dfd2; padding:16px; border-radius:10px; }
p code { background:#f0e8dc; padding:2px 6px; border-radius:4px; }
.tag { background:rgba(192,90,50,0.1); color:#96432a; border-radius:999px; padding:3px 10px; font-size:12px; }
```

#### B. 白皮书/严肃风格（长文/思想类）

来自 `focus-whitepaper/index.astro`，适合白皮书：

```css
:root {
  --bg: #fbf9f4; --text: #2a2a2a; --muted: #888;
  --accent: #b15724; --accent-soft: #fff7ee;
  --border: #e2dccf; --card: #fff;
}
body { font-family: -apple-system, "PingFang SC", sans-serif; background: var(--bg); line-height: 1.8; }
h1 { font-size: 28px; letter-spacing: 1px; }
h2 { font-size: 20px; border-bottom: 1px solid var(--border); }
em { color: var(--accent); font-style: normal; font-weight: 500; }  /* 用于强调，不是斜体 */
blockquote { border-left: 3px solid var(--accent); background: var(--accent-soft); color: #7c3a10; }
```

### 长文必备组件

#### 侧边栏 TOC（桌面端显示）

```astro
<aside class="toc-sidebar" aria-label="目录">
  <div class="toc-sidebar-title">目录 · TOC</div>
  <ul>
    {toc.map(item => (
      <>
        {item.part && <li class="part">{item.part}</li>}
        <li><a href={`#${item.id}`} data-toc-link>{item.label}</a></li>
      </>
    ))}
  </ul>
</aside>
```

配合 CSS：
- 桌面 `position: fixed; left: max(20px, calc(50% - 600px)); width: 220px;`
- `@media (max-width: 1100px) { .toc-sidebar { display: none; } }` 隐藏
- `@media (min-width: 1101px) { .toc-inline { display: none; } }` 互斥

配合 JS（滚动高亮当前章节）：

```javascript
// TOC scroll spy
(function () {
  var links = document.querySelectorAll('[data-toc-link]');
  var ids = Array.from(links).map(a => a.getAttribute('href').slice(1));
  function update() {
    var current = '';
    ids.forEach(id => {
      var el = document.getElementById(id);
      if (el && el.getBoundingClientRect().top < 120) current = id;
    });
    links.forEach(a => {
      a.classList.toggle('active', a.getAttribute('href') === '#' + current);
    });
  }
  window.addEventListener('scroll', update, { passive: true });
  update();
})();
```

#### 内联 TOC（移动端显示）

```html
<div class="toc-inline">
  <div class="toc-inline-title">目录</div>
  <ul>
    <li class="part">第一部分　标题</li>
    <li><a href="#s1">第一章　标题</a></li>
    ...
  </ul>
</div>
```

#### 下载卡片（如有 PDF/DOCX）

```astro
<div class="download-card">
  <div class="dl-title">📥 完整版下载</div>
  <div class="dl-name">文档标题 <span>(约 N 字 · 含附录)</span></div>
  <div class="dl-buttons">
    <a class="dl-btn" href={pdfUrl} target="_blank" rel="noopener">下载 PDF</a>
    <a class="dl-btn secondary" href={docxUrl} target="_blank" rel="noopener">下载 DOCX</a>
  </div>
</div>
```

### 内容格式规范

- **标题层级**：h1 仅用于文章大标题，h2 章节标题（带 `id` 锚点），h3 小节，h4 子小节
- **强调**：用 `<em>` 标记（CSS 渲染为橙色加粗，非斜体），表达核心论点
- **引用**：`<blockquote>` 用于金句/核心原则，橙色左边框 + 暖色背景
- **表格**：用于对比、诊断、分类，`th` 暖色背景，整体 14px 字体
- **代码**：行内 `<code>` 暖灰背景，代码块 `<pre>` 深色背景
- **列表**：`<ul>`/`<ol>` 标准缩进，`li` 间距 6px

### 中英双语（如需要）

- 中文版：`/posts/POST_SLUG/index.astro`
- 英文版：`/posts/POST_SLUG/en.astro`
- 顶栏加语言切换：

```html
<div class="lang-switch">
  <a href="/posts/POST_SLUG/" class="current" hreflang="zh-CN">中文</a>
  <span>/</span>
  <a href="/posts/POST_SLUG/en/" hreflang="en">English</a>
</div>
```

- `<head>` 中加 `hreflang` 交叉引用：

```html
<link rel="alternate" hreflang="zh-CN" href="https://sg.yaoyuheng2001.me/posts/POST_SLUG/" />
<link rel="alternate" hreflang="en" href="https://sg.yaoyuheng2001.me/posts/POST_SLUG/en/" />
<link rel="alternate" hreflang="x-default" href="https://sg.yaoyuheng2001.me/posts/POST_SLUG/" />
```

### 页面底部必备元素

#### 作者卡片

```html
<div class="author-card" style="margin:40px 0 0;padding:24px;border:1px solid #e4d7c6;border-radius:12px;background:#fffaf2;font-size:14px;line-height:1.8;color:#3f342a">
  <p style="font-weight:600;margin-bottom:8px;color:#2a2118;font-size:15px">Yao Yuheng / 姚钰珩</p>
  <p style="margin-bottom:12px;color:#5a4f44;font-size:13px">NTU Data Science 硕士。专注：AI Agent 系统工程、Eval 驱动开发、LLM 应用。</p>
  <p style="font-size:13px">本文首发于 <a href="https://sg.yaoyuheng2001.me/" style="color:#96432a">sg.yaoyuheng2001.me</a>，转载请注明出处。</p>
  <p style="font-size:13px;margin-top:8px">
    <a href="https://sg.yaoyuheng2001.me/" style="color:#96432a">Blog</a> ·
    <a href="https://github.com/piglet12138" style="color:#96432a">GitHub</a> ·
    <a href="https://juejin.cn/user/3159377279190218/posts" style="color:#96432a">掘金</a> ·
    <a href="https://piglet12138.substack.com/" style="color:#96432a">Substack</a> ·
    <a href="https://sg.yaoyuheng2001.me/rss.xml" style="color:#96432a">RSS</a>
  </p>
</div>
```

#### Analytics 组件

```astro
<Analytics />
```

（需在 frontmatter 中 `import Analytics from "../../../components/Analytics.astro";`）

## 发布完整流程

### Phase 1: 创建 Astro 源码

1. 在本地 `/tmp/` 写好 `.astro` 文件
2. `scp` 到服务器 `src/pages/posts/POST_SLUG/index.astro`

### Phase 2: 更新站点级数据（均在服务器 src 文件上操作）

#### 首页文章列表 (`src/pages/index.astro`)

在 `const posts = [` 数组中按日期插入：

```javascript
{ url: '/posts/POST_SLUG', title: { zh: '中文标题', en: 'English Title' }, date: 'YYYY-MM-DD' },
```

#### RSS Feed (`src/pages/rss.xml.ts`)

在 `posts` 数组最前面插入：

```javascript
{
  url: '/posts/POST_SLUG/',
  title: '文章标题',
  date: 'YYYY-MM-DD',
  description: '文章摘要',
},
```

### Phase 3: 构建 & 部署

```bash
ssh root@167.71.197.117
cd /root/blog
export NVM_DIR=/root/.nvm && source /root/.nvm/nvm.sh
npx astro build
```

Astro 会自动更新 `dist/`（包括 sitemap.xml）。

### Phase 4: Git 同步

```bash
cd /root/blog
git add -A
git commit -m "feat: add POST_SLUG blog post (YYYY-MM-DD)"
git push
```

### Phase 5: 验证

```bash
# 页面可访问
curl -sI https://sg.yaoyuheng2001.me/posts/POST_SLUG/ | head -3

# 首页有新条目
curl -s https://sg.yaoyuheng2001.me/ | grep -o 'POST_SLUG'

# RSS 有新条目
curl -s https://sg.yaoyuheng2001.me/rss.xml | grep 'POST_SLUG'

# Sitemap 有新条目
curl -s https://sg.yaoyuheng2001.me/sitemap.xml | grep 'POST_SLUG'
```

## 站点已有的 SEO 基础设施

| 资源 | 路径 | 用途 |
|------|------|------|
| Sitemap | `/sitemap.xml` | Astro 自动生成 |
| RSS Feed | `/rss.xml` | `@astrojs/rss`，需手动更新 posts 数组 |
| robots.txt | `/robots.txt` | 允许所有爬虫 + 指向 sitemap |
| llms.txt | `/llms.txt` | LLM 友好的站点描述 |
| 聚合页 | `/links/` | 放到各平台 bio 的统一入口 |
| 资源页 | `/resources/` | 公开资料分享 |
| Analytics | 每页 `<Analytics />` 组件 | 自建匿名流量统计 |
| 邮件订阅 | 首页 subscribe 区块 | follow.it 集成 |
| 作者卡片 | 每篇文章底部 | 首发声明 + 跨平台导流 |

## 跨平台分发注意事项

1. **发文顺序**: 先发独立博客 → 等 Google 索引 → 再同步到其他平台
2. **Canonical 声明**:
   - Substack: Settings → SEO → Canonical URL 填博客原文 URL
   - 掘金: 正文开头加「本文首发于 sg.yaoyuheng2001.me」
3. **导流**: 每篇文章底部有作者卡片，包含所有平台链接

## 已知 Gotchas

- **服务器是唯一 source of truth**，绝不用本地文件覆盖服务器
- RSS feed (`src/pages/rss.xml.ts`) 需要手动更新 posts 数组，不会自动检测新文章
- Astro CSS scoping 会给元素加 `data-astro-cid-*` 属性，如果 CSS 不生效，用 `<style is:inline>` 或 `<style is:global>`
- 长文的侧边栏 TOC 需要 JS scroll spy 脚本配合 `data-toc-link` 属性
- `em` 标签在白皮书风格中是橙色加粗（非斜体），用于标记核心论点
