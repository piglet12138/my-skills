---
name: blog-seo
description: 为 sg.yaoyuheng2001.me 独立博客发布新文章时执行的完整 SEO 清单，包括页面生成、元数据、站点地图、RSS、作者卡片、跨平台声明等。
version: 1.0.0
tags: [seo, blog, astro, deployment, nginx]
triggers:
  - /blog-seo
---

# /blog-seo — 博客文章发布 & SEO 清单

## 站点基本信息

- **域名**: sg.yaoyuheng2001.me
- **服务器**: DigitalOcean Droplet (SSH pubkey auth, IP 见私有配置)
- **静态目录**: `/root/blog/dist/`
- **Nginx**: 直接 serve 静态文件，无构建步骤
- **CSS 文件**: `/_astro/index@_@astro.ByWFJekH.css`（白皮书/长文风格）或 inline astro-cid CSS（短文风格）

## 发布新文章的完整流程

### Phase 1: 生成 HTML 页面

#### 页面类型判断
- **短文/博客**（< 5000 字）：使用 `.page` 布局，无侧边栏 TOC
- **白皮书/长文**（> 5000 字）：使用 `toc-sidebar` + `.page` 布局，带侧边栏目录

#### 必须包含的 SEO 元素

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="author" content="Yao Yuheng">
  <meta name="description" content="【50-160 字描述】">
  <meta name="keywords" content="关键词1, 关键词2, ...">
  <meta name="robots" content="index, follow, max-snippet:-1">
  <link rel="canonical" href="https://sg.yaoyuheng2001.me/posts/POST_SLUG/">

  <!-- Open Graph -->
  <meta property="og:title" content="文章标题">
  <meta property="og:description" content="同 meta description">
  <meta property="og:url" content="https://sg.yaoyuheng2001.me/posts/POST_SLUG/">
  <meta property="og:type" content="article">

  <!-- JSON-LD 结构化数据 -->
  <script type="application/ld+json">{
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": "文章标题",
    "description": "描述",
    "url": "https://sg.yaoyuheng2001.me/posts/POST_SLUG/",
    "datePublished": "YYYY-MM-DD",
    "dateModified": "YYYY-MM-DD",
    "inLanguage": "zh-CN",
    "author": {
      "@type": "Person",
      "name": "Yao Yuheng",
      "url": "https://sg.yaoyuheng2001.me/"
    },
    "mainEntityOfPage": "https://sg.yaoyuheng2001.me/posts/POST_SLUG/",
    "keywords": "关键词"
  }</script>

  <title>文章标题 | Yao Yuheng</title>
  <link rel="stylesheet" href="/_astro/index@_@astro.ByWFJekH.css">
</head>
```

#### 英文版（如需要）
- 路径: `/posts/POST_SLUG/en/`
- `lang="en"`, canonical 指向英文路径
- 添加 `<link rel="alternate" hreflang="zh-CN" href="...">` 和 `hreflang="en"`
- `hreflang="x-default"` 指向中文版

#### 作者卡片（放在 `</body>` 之前）

中文版:
```html
<div class="author-card" style="margin:40px 0 0;padding:24px;border:1px solid #e4d7c6;border-radius:12px;background:#fffaf2;font-size:14px;line-height:1.8;color:#3f342a">
  <p style="font-weight:600;margin-bottom:8px;color:#2a2118;font-size:15px">Yao Yuheng / 姚钰珩</p>
  <p style="margin-bottom:12px;color:#5a4f44;font-size:13px">NTU Data Science 硕士。研究方向：AI Agent 系统、上下文工程、Eval 驱动开发。</p>
  <p style="font-size:13px">本文首发于 <a href="https://sg.yaoyuheng2001.me/" style="color:#96432a">sg.yaoyuheng2001.me</a>，转载请注明出处。</p>
  <p style="font-size:13px;margin-top:8px">
    <a href="https://sg.yaoyuheng2001.me/" style="color:#96432a">Blog</a> ·
    <a href="https://github.com/piglet12138" style="color:#96432a">GitHub</a> ·
    <a href="https://juejin.cn/user/3159377279190218/posts" style="color:#96432a">掘金</a> ·
    <a href="https://sspai.com/u/61a4m9k6/u" style="color:#96432a">少数派</a> ·
    <a href="https://piglet12138.substack.com/" style="color:#96432a">Substack</a> ·
    <a href="https://sg.yaoyuheng2001.me/feed.xml" style="color:#96432a">RSS</a>
  </p>
</div>
```

英文版: 把文案换成 English，去掉少数派。

#### Analytics 脚本（放在 `</body>` 之前，作者卡片之后）

```html
<script>
(function(){
  if(navigator.doNotTrack==='1')return;
  var s=screen.width+'x'+screen.height;
  var raw=s+'|'+navigator.userAgent+'|'+(navigator.language||'');
  function hash(str){
    var h1=0xdeadbeef,h2=0x41c6ce57;
    for(var i=0;i<str.length;i++){var c=str.charCodeAt(i);h1=Math.imul(h1^c,2654435761);h2=Math.imul(h2^c,1597334677);}
    h1=Math.imul(h1^(h1>>>16),2246822507)^Math.imul(h2^(h2>>>13),3266489909);
    h2=Math.imul(h2^(h2>>>16),2246822507)^Math.imul(h1^(h1>>>13),3266489909);
    return (h2>>>0).toString(16).padStart(8,'0')+(h1>>>0).toString(16).padStart(8,'0')+(h1>>>0^h2>>>0).toString(16).padStart(8,'0')+((h1+h2)>>>0).toString(16).padStart(8,'0');
  }
  var fp=hash(raw);
  var data=JSON.stringify({path:location.pathname,referrer:document.referrer||'',screen:s,fp:fp});
  if(navigator.sendBeacon){navigator.sendBeacon('/api/analytics/pv',new Blob([data],{type:'application/json'}));}
  else{fetch('/api/analytics/pv',{method:'POST',headers:{'Content-Type':'application/json'},body:data,keepalive:true});}
})();
</script>
```

### Phase 2: 部署

```bash
# 1. 创建目录并上传
ssh root@YOUR_SERVER_IP "mkdir -p /root/blog/dist/posts/POST_SLUG"
scp /tmp/POST_FILE.html root@YOUR_SERVER_IP:/root/blog/dist/posts/POST_SLUG/index.html

# 2. 验证
ssh root@YOUR_SERVER_IP "curl -s -o /dev/null -w '%{http_code}' https://sg.yaoyuheng2001.me/posts/POST_SLUG/"
```

### Phase 3: 更新站点级 SEO 资源

#### 3.1 首页文章列表
在 `/root/blog/dist/index.html` 的 `<ul class="post-list">` 中，在最前面插入新条目：

```html
<li class="post-item" data-astro-cid-j7pv25f6>
  <a href="/posts/POST_SLUG/" data-astro-cid-j7pv25f6>
    <span class="post-title" data-astro-cid-j7pv25f6>
      <span class="zh" data-astro-cid-j7pv25f6>中文标题</span>
      <span class="en" data-astro-cid-j7pv25f6>English Title</span>
    </span>
    <span class="post-date" data-astro-cid-j7pv25f6>YYYY-MM-DD</span>
  </a>
</li>
```

#### 3.2 Sitemap (`/root/blog/dist/sitemap.xml`)
在 `</urlset>` 之前追加：

```xml
<url>
  <loc>https://sg.yaoyuheng2001.me/posts/POST_SLUG/</loc>
  <lastmod>YYYY-MM-DD</lastmod>
  <changefreq>monthly</changefreq>
  <priority>0.8</priority>
</url>
```

#### 3.3 RSS Feed (`/root/blog/dist/feed.xml`)
在 `<channel>` 的第一个 `<item>` 之前插入新条目：

```xml
<item>
  <title>文章标题</title>
  <link>https://sg.yaoyuheng2001.me/posts/POST_SLUG/</link>
  <guid isPermaLink="true">https://sg.yaoyuheng2001.me/posts/POST_SLUG/</guid>
  <pubDate>Day, DD Mon YYYY 00:00:00 +0800</pubDate>
  <dc:creator>Yao Yuheng</dc:creator>
  <description>文章摘要</description>
  <category>标签1</category>
  <category>标签2</category>
</item>
```

同时更新 `<lastBuildDate>` 为当天日期。

### Phase 4: 验证清单

```bash
# 页面可访问
curl -s -o /dev/null -w '%{http_code}' https://sg.yaoyuheng2001.me/posts/POST_SLUG/

# 首页有新条目
curl -s https://sg.yaoyuheng2001.me/ | grep -o 'POST_SLUG'

# Sitemap 有新条目
curl -s https://sg.yaoyuheng2001.me/sitemap.xml | grep 'POST_SLUG'

# RSS 有新条目
curl -s https://sg.yaoyuheng2001.me/feed.xml | grep 'POST_SLUG'

# 作者卡片存在
curl -s https://sg.yaoyuheng2001.me/posts/POST_SLUG/ | grep -o 'author-card'
```

## 站点已有的 SEO 基础设施

| 资源 | 路径 | 用途 |
|------|------|------|
| Sitemap | `/sitemap.xml` | Google 爬虫发现页面 |
| RSS Feed | `/feed.xml` | 订阅 & Substack 同步 |
| robots.txt | `/robots.txt` | 允许所有爬虫 + 指向 sitemap |
| llms.txt | `/llms.txt` | LLM 友好的站点描述 |
| 聚合页 | `/links/` | 放到各平台 bio 的统一入口 |
| Analytics | 每页内嵌 | 自建匿名流量统计 |
| 作者卡片 | 每篇文章底部 | 首发声明 + 跨平台导流 |

## 跨平台分发注意事项

1. **发文顺序**: 先发独立博客 → 等 Google 索引 → 再同步到其他平台
2. **Canonical 声明**:
   - Substack: Settings → SEO → Canonical URL 填博客原文 URL
   - 掘金/少数派: 正文开头加「本文首发于 sg.yaoyuheng2001.me」
3. **导流**: 每篇文章底部有作者卡片，包含所有平台链接
4. **避免重复内容惩罚**: canonical + 首发声明 + 先发博客后发平台

## Nginx 相关

- 配置文件: `/etc/nginx/sites-enabled/sg.yaoyuheng2001.me`
- `/sub/` 路径有 `X-Robots-Tag: noindex`（正确，VPN 订阅不需要索引）
- 其他路径均允许索引
- SSL: Let's Encrypt 自动续期

## 已知 Gotchas

- 首页是单行 HTML（Astro 构建产物），用 sed 替换时要小心，建议用 Python
- 所有元素都带 `data-astro-cid-j7pv25f6` 属性，新增首页内容时必须带上
- 白皮书风格用外部 CSS `/_astro/index@_@astro.ByWFJekH.css`，短文风格用 inline CSS with `data-astro-cid-3cqn74kc`
- Google Search Console 已配置，sitemap URL: `https://sg.yaoyuheng2001.me/sitemap.xml`
