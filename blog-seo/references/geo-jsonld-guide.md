# geo-jsonld-guide.md — BlogPosting + FAQPage JSON-LD 详解

## 为什么 JSON-LD 是 GEO 的核心

传统 SEO 给爬虫看 HTML 标签和关键词密度。**GEO（Generative Engine Optimization）**给 LLM-based 搜索引擎看 **结构化数据**。

Perplexity、Bing Copilot、SearchGPT、Google AI Overviews 抓你的文章时，第一优先级是看 `<script type="application/ld+json">`。它们用这些 schema 决定：

- 文章主题是什么（headline + keywords + section）
- 适合回答什么问题（FAQPage 的每对 Q&A）
- 时效性（datePublished / dateModified）
- 是否权威（author + publisher）

写得好的 JSON-LD 会让你的文章被 LLM 引用，写得差就只能等关键词命中。

## 必备的两个 schema

### 1. BlogPosting（每篇必备）

```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "标题，跟 <h1> 一致",
  "alternativeHeadline": "副标题，可选",
  "description": "50-160 字的摘要",
  "url": "https://sg.yaoyuheng2001.me/posts/<slug>/",
  "datePublished": "YYYY-MM-DD",
  "dateModified": "YYYY-MM-DD",
  "inLanguage": "zh-CN",
  "author": {
    "@type": "Person",
    "name": "Yao Yuheng",
    "alternateName": "姚钰珩",
    "url": "https://sg.yaoyuheng2001.me/"
  },
  "publisher": {
    "@type": "Person",
    "name": "Yao Yuheng",
    "url": "https://sg.yaoyuheng2001.me/"
  },
  "mainEntityOfPage": "https://sg.yaoyuheng2001.me/posts/<slug>/",
  "image": "https://sg.yaoyuheng2001.me/images/<slug>/hero.png",
  "keywords": "逗号分隔的关键词列表",
  "wordCount": 5800,
  "articleSection": "工程实践 / DevOps"
}
```

字段细则：

- **headline** 必须 ≤ 110 字符（Google 的硬上限）
- **description** 必须 50-160 字（短了被忽略，长了被截断）
- **datePublished + dateModified** 用 ISO 8601 (`YYYY-MM-DD`)
- **image** 必须是绝对 URL，hero 推荐 16:9 比例，宽度 ≥ 1200px
- **keywords** 5-15 个，最重要的放前面
- **wordCount** 帮 LLM 判断深度，长文更可信
- **articleSection** 一两个高层分类，例「工程实践 / DevOps」「散文」「媒介批评」

### 2. FAQPage（GEO 最高 ROI）

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Q 原文",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "A 原文，纯文本或限定 HTML"
      }
    }
  ]
}
```

字段细则：

- **mainEntity 至少 3 个 Q**，建议 5-8 个
- **Question.name** 用真实疑问句（"是什么..." "怎么..." "如果...怎么办"）
- **Answer.text** 长度 150-300 字最佳。短了不够引用，长了 LLM 截断
- **Answer.text 可以包含基本 HTML**（`<strong>` `<code>` `<a>`），但避免 `<script>` `<style>` `<iframe>`

A 文本里要塞**具体实体词**让 LLM 用做检索锚点：

- ✅ 工具名（`anthropics/claude-code-action@v1`、`GitHub Actions`、`DigitalOcean`）
- ✅ 具体数字（`4-6 分钟`、`2 vCPU/2GB`、`10-20 个`）
- ✅ 项目名（`claude-ai-harness`）
- ❌ 含糊词（"我们的工具"、"几分钟"、"较快"）

## 嵌入位置

两份 JSON-LD 都放 `<head>`，紧挨着 `<title>`：

```html
<title>...</title>
<script type="application/ld+json" set:html={JSON.stringify(jsonLd)} />
<script type="application/ld+json" set:html={JSON.stringify(faqLd)} />
```

⚠️ **Astro 注意**：用 `set:html={JSON.stringify(obj)}` 而不是 `{JSON.stringify(obj)}` —— 后者会被 HTML 转义破坏 JSON 语法。

## 可选 schema（高级）

按文章类型加一份额外的：

### TechArticle（技术博客 / 教程）

把 `"@type": "BlogPosting"` 改成 `"BlogPosting", "TechArticle"`（数组），或单独加一份 TechArticle JSON-LD。LLM 在技术问题路由时优先匹配 TechArticle。

### HowTo（步骤教程）

如果文章核心是「N 步完成 X」，加一份 HowTo schema：

```json
{
  "@type": "HowTo",
  "name": "如何搭建 @claude 驱动的 CI/CD",
  "step": [
    { "@type": "HowToStep", "text": "..." }
  ]
}
```

### Course（系列文章 / 系统教学）

只在多篇文章构成系统化课程时用。

## 验证

发布后做 3 件事：

1. **Google Rich Results Test**: https://search.google.com/test/rich-results
   - 输入文章 URL
   - 应该看到 BlogPosting + FAQPage 都被识别
   - 任何 warning 都要修

2. **Schema.org Validator**: https://validator.schema.org/
   - 检查 JSON-LD 语法错误

3. **Search Console** (要等几天)
   - 看「Enhancements」面板的 BlogPosting 和 FAQ 报告

## 常见错误

| 错误 | 表现 | 修法 |
|---|---|---|
| `image` 用相对 URL | rich result test 报错 | 改成绝对 URL `https://...` |
| `datePublished` 缺时区 | Google 仍接受，但 Yandex 警告 | 加 `+08:00` 后缀，或保持 `YYYY-MM-DD` 不要尝试加部分时区 |
| `wordCount` 不准 | 引用率低 | 用 `wc -w` 或类似工具数字数 |
| FAQ Q 太短 | LLM 忽略 | 改成完整疑问句 |
| FAQ A 包含 `<script>` | validator 报错 | 删掉 |
| 两份 JSON-LD 用同一个 `@graph` 包装 | 部分 LLM 解析失败 | 用两个独立 `<script>` 标签 |
| `JSON.stringify` 没加 `set:html=` | Astro HTML 转义破坏 JSON | 改成 `set:html={JSON.stringify(obj)}` |
