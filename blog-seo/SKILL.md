---
name: blog-seo
description: "把一篇博客草稿（来自 blog-content skill 的 manifest，或用户手写的 .astro）打包成上线版本。负责：Astro 模板渲染、完整 SEO meta（og:、article:、twitter:、hreflang）、JSON-LD（BlogPosting + FAQPage）、站点级更新（首页 posts 列表、RSS）、构建、commit/push、IndexNow ping。不负责内容写作或插图生成 —— 那是 blog-content 的事。"
type: skill
version: 3.0.0
tags: [seo, geo, blog, astro, deployment, publish, jsonld]
triggers:
  - /blog-seo
---

# /blog-seo — 排版 + SEO/GEO + 发布

**v3 重大变化（2026-05-22）**：从「一站式写+发」拆分。本 skill 现在专注**排版+SEO/GEO+发布**，内容写作和插图生成交给 [blog-content](../blog-content/SKILL.md)。

## 这个 skill 做什么 / 不做什么

| 做 ✅ | 不做 ❌ |
|---|---|
| 读 manifest 或现成 .astro | 主题选定 / 内容大纲（blog-content 负责）|
| 选/应用 Astro 主题模板 | 写正文段落（blog-content 负责）|
| 生成完整 SEO meta | 生成 hero 插图（blog-content 负责）|
| 生成 JSON-LD BlogPosting + FAQPage | 处理用户截图（blog-content 负责）|
| 更新首页 posts 列表 + rss.xml.ts | 拟 FAQ Q & A 文本（blog-content 负责）|
| `npm run build` | 决定 keywords / tags（blog-content 负责）|
| 验证 HTTP 200 + JSON-LD | |
| git commit / push | |
| IndexNow 三家 ping | |

**简单分工**：blog-content 决定"说什么"，本 skill 决定"怎么发出去"。

## 两种入参方式

### 方式 A：用 manifest（推荐 / 从 blog-content 接力时）

输入 = `/tmp/blog-draft-<slug>.yaml`（schema 见 [blog-content/references/manifest-schema.md](../blog-content/references/manifest-schema.md)）

```bash
/blog-seo --manifest /tmp/blog-draft-solo-cicd-claude-agent.yaml
```

### 方式 B：用户手写的 .astro 文件

如果用户已经自己写好了 .astro（没走 blog-content），只想要发布流程：

```bash
/blog-seo --astro /tmp/my-post.astro --slug my-post
```

skill 会跳过模板渲染，直接 scp 到服务器 + 走构建发布流程，但**仍然检查 + 补全缺失的 SEO meta 和 JSON-LD**。

## 站点基本信息（固定）

- **域名**: sg.yaoyuheng2001.me
- **服务器**: DO Droplet, `ssh do`，IP 167.71.197.117
- **博客源码**: `/root/blog/`（Astro 项目）
- **构建输出**: `/root/blog/dist/`（Nginx 直接 serve）
- **Node.js**: `export NVM_DIR=/root/.nvm && source /root/.nvm/nvm.sh`，version v22.22.2
- **GitHub**: https://github.com/piglet12138/blog.git
- **IndexNow 脚本**: `/root/blog/ping_indexnow.py`

⚠️ **服务器是唯一 source of truth**。所有源码改动直接在服务器 src 上做，不要本地修改再覆盖。

## 主题选择

读 manifest 里 `theme` 字段（或 ask 用户）。对应模板：

| `theme` 值 | 模板 | 适合 | 参考文章 |
|---|---|---|---|
| `warm-paper` | [templates/warm-paper.astro.tmpl](templates/warm-paper.astro.tmpl) | 散文 / 技术博客 / 思辨长文（默认推荐）| tuike, warp-social-media, solo-cicd-claude-agent |
| `whitepaper` | [templates/whitepaper.astro.tmpl](templates/whitepaper.astro.tmpl) | 严肃白皮书 / 长论文（有 TOC 侧边栏）| focus-whitepaper |
| `minimal` | [templates/minimal.astro.tmpl](templates/minimal.astro.tmpl) | 极简短文 | claude-ai-harness（老版） |
| `custom` | 用户提供完整 CSS（高级）| 自由发挥 | latent-space |

## 渲染流程（manifest 模式）

### Step 1 — 校验 manifest

```bash
MANIFEST="/tmp/blog-draft-$SLUG.yaml"
[ -f "$MANIFEST" ] || die "manifest not found"

# 必填字段
for k in slug title description date_published keywords body lead; do
  yq -e ".$k" "$MANIFEST" >/dev/null || die "missing field: $k"
done
```

### Step 2 — 选模板 + 填占位符

模板里所有 `__XXX__` 占位符按字段替换：

| 占位符 | manifest 字段 | 备注 |
|---|---|---|
| `__SLUG__` | `slug` | URL 路径 |
| `__TITLE__` | `title` | h1 + JSON-LD headline |
| `__SUBTITLE__` | `subtitle` (可空) | italic 衬线副标题 |
| `__DESCRIPTION__` | `description` | meta description / og:description |
| `__DATE_PUBLISHED__` | `date_published` | YYYY-MM-DD |
| `__DATE_MODIFIED__` | `date_modified` | YYYY-MM-DD |
| `__KEYWORDS_CSV__` | `keywords` 逗号 join | meta name=keywords |
| `__TAGS_META__` | `tags` 渲染成多个 `<meta property="article:tag">` | |
| `__SECTION__` | `section` | article:section |
| `__WORD_COUNT__` | `word_count` | JSON-LD wordCount |
| `__HERO_IMG__` | `hero_image` | 路径 `/images/<slug>/<hero_image>` |
| `__HERO_ALT__` | `hero_alt` | alt 文本（GEO 关键） |
| `__PAPER_BG__` | `paper_bg` | CSS body background |
| `__LEAD__` | `lead` | hero 下方的引言段 |
| `__CTAS_HTML__` | `ctas[]` 渲染成 `.cta` 区块 | |
| `__BODY__` | `body` | 已是 HTML 片段，直接塞 article 内 |
| `__FAQ_HTML__` | `faqs[]` 渲染成 `.faq-item` HTML | |
| `__FAQ_JSONLD__` | `faqs[]` 渲染成 FAQPage JSON-LD | |
| `__EN_URL__` / `__HREFLANG__` | `en_url` (可空) | 双语 alt link |

### Step 3 — 生成 JSON-LD（GEO 关键）

两份 JSON-LD 嵌入 `<head>`：

**1) BlogPosting**（每篇文章必备）：

```js
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "__TITLE__",
  "alternativeHeadline": "__SUBTITLE__",
  "description": "__DESCRIPTION__",
  "url": "__URL__",
  "datePublished": "__DATE_PUBLISHED__",
  "dateModified": "__DATE_MODIFIED__",
  "inLanguage": "zh-CN",
  "author": {"@type":"Person","name":"Yao Yuheng","alternateName":"姚钰珩","url":"https://sg.yaoyuheng2001.me/"},
  "publisher": {"@type":"Person","name":"Yao Yuheng","url":"https://sg.yaoyuheng2001.me/"},
  "mainEntityOfPage": "__URL__",
  "image": "https://sg.yaoyuheng2001.me/images/__SLUG__/__HERO_IMG__",
  "keywords": "__KEYWORDS_CSV__",
  "wordCount": __WORD_COUNT__,
  "articleSection": "__SECTION__"
}
```

**2) FAQPage**（manifest 有 faqs 时；GEO 最高 ROI）：

```js
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    { "@type": "Question",
      "name": "<Q>",
      "acceptedAnswer": { "@type": "Answer", "text": "<A>" }
    }
    // ...
  ]
}
```

详见 [references/geo-jsonld-guide.md](references/geo-jsonld-guide.md)。

### Step 4 — meta 标签全套

详见 [references/seo-meta-checklist.md](references/seo-meta-checklist.md)。**最低限度必填**：

- `<meta name="description">`
- `<meta name="keywords">`
- `<meta name="author" content="Yao Yuheng">`
- `<meta name="robots" content="index, follow, max-snippet:-1, max-image-preview:large">`
- `<link rel="canonical">`
- og: title / description / url / type=article / locale / image
- article: published_time / modified_time / author / section / 多个 tag
- twitter:card="summary_large_image" + 三个 twitter:title/description/image
- 双语时 `<link rel="alternate" hreflang="zh|en|x-default">`

### Step 5 — scp 到服务器

```bash
scp /tmp/rendered.astro do:/root/blog/src/pages/posts/$SLUG/index.astro
```

### Step 6 — 站点级更新（默认开）

**首页 posts 列表** (`/root/blog/src/pages/index.astro`)，在 `const posts = [` 数组最前插：

```js
{ url: '/posts/<slug>', title: { zh: '<title>', en: '<en_title or zh>' }, date: 'YYYY-MM-DD' },
```

**RSS** (`/root/blog/src/pages/rss.xml.ts`)，`posts` 数组最前插：

```js
{ url: '/posts/<slug>/', title: '<title>', date: 'YYYY-MM-DD', description: '<desc>' },
```

manifest 字段 `update_homepage: false` 或 `update_rss: false` 可跳过对应步骤。

### Step 7 — 构建

```bash
ssh do "cd /root/blog && PATH=/root/.nvm/versions/node/v22.22.2/bin:\$PATH npm run build 2>&1 | tail -5"
```

期待最后一行 `[build] Complete!`。报错往往是 Astro JSX 解析问题 —— 参考 Gotchas。

### Step 8 — 验证（5 项必查）

```bash
# 1. 文章 HTTP 200
curl -sI "https://sg.yaoyuheng2001.me/posts/$SLUG/" -H 'Cache-Control: no-cache' | head -3

# 2. JSON-LD FAQPage 在 HTML 里
curl -s "https://sg.yaoyuheng2001.me/posts/$SLUG/" -H 'Cache-Control: no-cache' | grep -c FAQPage

# 3. Hero 图可达
curl -sI "https://sg.yaoyuheng2001.me/images/$SLUG/$HERO_IMG" | head -1

# 4. 首页有新条目
curl -s "https://sg.yaoyuheng2001.me/" -H 'Cache-Control: no-cache' | grep -c "$SLUG"

# 5. RSS + Sitemap 有新条目
curl -s "https://sg.yaoyuheng2001.me/rss.xml" | grep -c "$SLUG"
curl -s "https://sg.yaoyuheng2001.me/sitemap.xml" | grep -c "$SLUG"
```

任何一项 fail 都要先修，再 commit。

### Step 9 — git commit + push

```bash
ssh do "cd /root/blog && git add -A && \
  git commit -m 'post: $SLUG - $TITLE_SHORT' && \
  git push"
```

### Step 10 — IndexNow ping

```bash
ssh do "cd /root/blog && python3 ping_indexnow.py"
```

期待三家全部 200/202（IndexNow / Bing / Yandex）。

### Step 11 — 富文本结果验证（可选）

提示用户：
> 推荐去 https://search.google.com/test/rich-results 输入 URL：
> https://sg.yaoyuheng2001.me/posts/$SLUG/
>
> 应该看到 BlogPosting + FAQPage 都被识别，无 warning。

## GEO 优化（生成式搜索引擎，本 skill 的核心增值）

GEO = Generative Engine Optimization。目标是让 Perplexity / Bing Copilot / SearchGPT / Google AI Overviews 引用你的文章。

详见 [references/geo-jsonld-guide.md](references/geo-jsonld-guide.md) + [references/geo-content-anchors.md](references/geo-content-anchors.md)。

核心原则：
1. **FAQPage JSON-LD = 最高密度可引用单元**。每对 Q&A 是一个独立 citation source。一定要有。
2. **alt 文本是图像 GEO 入口**。LLM 不看像素只看 alt，alt 写详尽 → 引用率高。
3. **正文里塞具体实体词**（项目名、工具名、版本号、库名）让 LLM 用作检索锚点。
4. **datePublished + dateModified 影响时效性**。LLM 偏好近期内容。
5. **wordCount 帮 LLM 判断深度**。

## 已有 SEO 基础设施（站点级，本 skill 不再创建）

| 资源 | 路径 | 维护 |
|---|---|---|
| Sitemap | `/sitemap.xml` | Astro 自动生成 |
| RSS Feed | `/rss.xml` | 本 skill 自动更新 |
| robots.txt | `/robots.txt` | 已配置 |
| llms.txt | `/llms.txt` | LLM 友好的站点描述 |
| 聚合页 | `/links/` | 各平台 bio 入口 |
| Analytics | 每页 `<Analytics />` | 自建匿名统计 |
| 邮件订阅 | 首页 subscribe | follow.it |

## 已知 Gotchas

- **Astro CSS scoping** 会给元素加 `data-astro-cid-*`，调试时用 `<style is:inline>` 临时绕过
- **正文不能写裸 `{xxx}`** —— Astro 当 JSX 表达式炸。用 `&lt;xxx&gt;` 或 `&#123;xxx&#125;` 转义
- **YAML `run: |` 块里嵌 bash 多行字符串** —— 非缩进行被当块结束符。用 `printf` 单行
- **paper-bg.jpg 的 URL** —— CSS 里 `url(/images/<slug>/paper-bg.jpg)` 必须绝对路径
- **首发顺序**：博客 → 等 Google 索引 → 同步到 Substack/掘金时把 canonical 设回博客原文

## 跨平台分发（本 skill 不做，用户自己同步）

1. **Substack**: Settings → SEO → Canonical URL 填博客原文
2. **掘金**: 正文开头加「本文首发于 sg.yaoyuheng2001.me」+ 链接
3. 每篇文章底部已经有作者卡片 + 跨平台导流链接（模板自带）

## 文件

- [SKILL.md](SKILL.md) — 本文件
- [templates/warm-paper.astro.tmpl](templates/warm-paper.astro.tmpl) — 暖纸+衬线+rust 主题模板
- [templates/whitepaper.astro.tmpl](templates/whitepaper.astro.tmpl) — 白皮书严肃风格（含 TOC 侧栏）
- [templates/minimal.astro.tmpl](templates/minimal.astro.tmpl) — 极简风格
- [scripts/render-and-publish.sh](scripts/render-and-publish.sh) — manifest → 上线一站式脚本
- [references/seo-meta-checklist.md](references/seo-meta-checklist.md) — meta 标签清单
- [references/geo-jsonld-guide.md](references/geo-jsonld-guide.md) — BlogPosting + FAQPage 详解
- [references/geo-content-anchors.md](references/geo-content-anchors.md) — 让 LLM 引用的具体写法

## 上游 / 下游

- **上游**：[blog-content](../blog-content/SKILL.md) — 提供 manifest（推荐路径）
- **下游**：无（本 skill 是终点，跑完文章就上线了）

## v2 → v3 升级说明

如果你之前在用 v2，主要变化：

- **内容生成不再属于本 skill**。要写新文章请先用 [blog-content](../blog-content/SKILL.md) 起草，输出 manifest 后再调本 skill 发布。
- 仍然支持直接提交一个已写好的 .astro 文件（方式 B），跟 v2 行为一样。
- 模板从内嵌 CSS string 改成独立 `.tmpl` 文件，更易维护。
- 新增完整 GEO 子系统（FAQPage JSON-LD、alt 锚定、实体词指南）。
- 验证步骤从 1 项扩到 5 项（含 JSON-LD 落地、图片可达、RSS/Sitemap 联动）。
