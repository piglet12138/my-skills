# seo-meta-checklist.md — meta 标签必填清单

每篇博客发布前用这个清单过一遍。`<head>` 里**最低必须有**：

## 基础 meta（4 项）

```html
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="description" content="50-160 字描述" />
<meta name="keywords" content="5-15 个关键词, 逗号分隔" />
```

## 权威性 meta（3 项）

```html
<meta name="author" content="Yao Yuheng" />
<meta name="robots" content="index, follow, max-snippet:-1, max-image-preview:large" />
<link rel="canonical" href="https://sg.yaoyuheng2001.me/posts/<slug>/" />
```

- `max-snippet:-1` —— 不限制摘要长度（Google 默认 160 字）
- `max-image-preview:large` —— 允许大图预览（社媒分享时显示 hero 图）

## OpenGraph（Facebook / LinkedIn / 微信 / Slack 卡片，6 项）

```html
<meta property="og:title" content="标题" />
<meta property="og:description" content="描述" />
<meta property="og:url" content="https://sg.yaoyuheng2001.me/posts/<slug>/" />
<meta property="og:type" content="article" />
<meta property="og:locale" content="zh_CN" />
<meta property="og:image" content="https://sg.yaoyuheng2001.me/images/<slug>/hero.png" />
```

- `og:image` 推荐 1200x630px（最广兼容）
- 中文站 `og:locale="zh_CN"`，英文版补一份 `og:locale:alternate="en_US"`

## Article-specific（5 项 + N 个 tag）

```html
<meta property="article:published_time" content="YYYY-MM-DD" />
<meta property="article:modified_time" content="YYYY-MM-DD" />
<meta property="article:author" content="Yao Yuheng" />
<meta property="article:section" content="工程实践 / DevOps" />
<meta property="article:tag" content="标签1" />
<meta property="article:tag" content="标签2" />
<!-- 每个 tag 一个 meta 标签 -->
```

## Twitter Cards（4 项）

```html
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="标题" />
<meta name="twitter:description" content="描述" />
<meta name="twitter:image" content="https://sg.yaoyuheng2001.me/images/<slug>/hero.png" />
```

- 用 `summary_large_image` 让 Twitter 卡片显示大 hero 图
- `twitter:site` / `twitter:creator` 可加，但站长没 Twitter 账号时跳过

## 双语 hreflang（如有英文版，3 项）

```html
<link rel="alternate" hreflang="zh-CN" href="https://sg.yaoyuheng2001.me/posts/<slug>/" />
<link rel="alternate" hreflang="en" href="https://sg.yaoyuheng2001.me/posts/<slug>/en/" />
<link rel="alternate" hreflang="x-default" href="https://sg.yaoyuheng2001.me/posts/<slug>/" />
```

- `x-default` 指向"不知道用户语言时去哪"，通常 = zh 版

## 字体 preconnect（性能优化）

```html
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=..." rel="stylesheet" />
```

## title 标签

```html
<title>文章标题 — Yao Yuheng</title>
```

- 格式：`<文章标题> — Yao Yuheng`（短横线 em-dash，不是 hyphen）
- 长度建议 ≤ 60 字符（Google SERP 截断点）

## JSON-LD（参考 [geo-jsonld-guide.md](geo-jsonld-guide.md)）

```html
<script type="application/ld+json" set:html={JSON.stringify(jsonLd)} />
<script type="application/ld+json" set:html={JSON.stringify(faqLd)} />
```

## 完整顺序（推荐）

```html
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content={description} />
  <meta name="keywords" content="..." />
  <meta name="author" content="Yao Yuheng" />
  <meta name="robots" content="..." />
  <link rel="canonical" href={url} />
  <link rel="alternate" hreflang="..." href="..." />  <!-- 双语 -->

  <!-- OpenGraph -->
  <meta property="og:title" content={title} />
  <meta property="og:description" content={description} />
  <meta property="og:url" content={url} />
  <meta property="og:type" content="article" />
  <meta property="og:locale" content="zh_CN" />
  <meta property="og:image" content="..." />

  <!-- Article -->
  <meta property="article:published_time" content={datePublished} />
  <meta property="article:modified_time" content={dateModified} />
  <meta property="article:author" content="Yao Yuheng" />
  <meta property="article:section" content="..." />
  <meta property="article:tag" content="tag1" />
  <meta property="article:tag" content="tag2" />

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content={title} />
  <meta name="twitter:description" content={description} />
  <meta name="twitter:image" content="..." />

  <title>{title} — Yao Yuheng</title>
  <script type="application/ld+json" set:html={JSON.stringify(jsonLd)} />
  <script type="application/ld+json" set:html={JSON.stringify(faqLd)} />

  <!-- 字体 preconnect 放最后，不阻塞首屏 -->
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?..." rel="stylesheet" />

  <style>...</style>
</head>
```

## 验证

发布后用以下工具检查：

- [Google Rich Results Test](https://search.google.com/test/rich-results) - SERP 富文本预览
- [Twitter Card Validator](https://cards-dev.twitter.com/validator) - Twitter 卡片预览
- [Facebook Sharing Debugger](https://developers.facebook.com/tools/debug/) - FB / 微信卡片
- [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/) - LinkedIn 卡片
