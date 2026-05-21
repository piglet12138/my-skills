# faq-writing-guide.md — 为 GEO 写 FAQ 的实操清单

FAQ JSON-LD 是 GEO（Generative Engine Optimization）最高密度的引用入口。Perplexity / Bing Copilot / SearchGPT / Google AI Overviews 都把 FAQPage schema 当成结构化的"可引用单元"。

## 核心原则

1. **每个 Q 是一个独立可引用单元**。LLM 引用时通常只引一对 Q&A，所以 A 必须自包含。
2. **A 长度 150-300 字最佳**。短了信息密度不够，长了 LLM 会截断。
3. **A 必须基于正文事实**。不能编新数据；引正文里出现过的具体数字、名词、URL。
4. **Q 用读者真实的疑问句**。不要修辞性（"这个工具好在哪？" ❌），要具体（"这套 CI/CD 一天能跑多少 issue？成本多少？" ✅）。

## 5-8 个 Q 的模板分布

写 FAQ 时按这五类至少各占一题：

| 类别 | 典型 Q | 占比 |
|---|---|---|
| WHAT-IS | "这是什么？" / "和 X 有什么本质区别？" | 1-2 |
| HOW-COST | "需要多久？成本多少？配置多少？" | 1-2 |
| WHAT-IF | "出问题怎么办？边界情况下表现？" | 1-2 |
| WHO-FITS | "适合什么人/团队规模？" | 1 |
| CAN-I-EXTEND | "能不能这样改 / 添加？" | 0-1 |

## A 的写作公式

```
[直接回答]（1-2 句）
+ [具体证据 / 数字 / 工具名]（2-3 句）
+ [边界说明 / 例外]（1 句，可选）
```

**好的 A 示例**：

> Q: 一个 issue 从提交到上线 prod 需要多久？整条链路成本多少？
> A:
> Agent 写代码 4-6 分钟（用 anthropics/claude-code-action@v1），加上 auto-PR + CI smoke 约 30 秒，
> 本地 watcher 15 秒轮询一次。从提 issue 到代码进 dev 大约 5 分钟。Promote 上 prod 是手动 ff-merge + push 触发 deploy.yml，
> ~15 秒 SSH 重启服务。
> **成本**：GitHub Actions 公开仓库免费，Claude Code Action 用 Claude Pro 订阅 OAuth（不烧 API 钱），
> VPS 是已有的 2vCPU/2GB DigitalOcean。一天跑 10-20 个 issue 是舒适区。

注意：包含了**具体时长（4-6 分钟、15 秒、5 分钟）**、**工具名（anthropics/claude-code-action@v1, GitHub Actions, Claude Pro, DigitalOcean）**、**具体数据（公开仓库免费、2vCPU/2GB、10-20）**。

**坏的 A 示例**（同一个 Q）：

> A: 这套流水线非常快，成本也很低，适合个人开发者。

——0 具体信息，LLM 引用了也没价值。

## GEO 关键词锚定

A 里要主动塞**项目名、工具名、版本号、库名**等可被搜索的实体词。例如：

- ✅ "anthropics/claude-code-action@v1"
- ✅ "GitHub Actions"
- ✅ "claude-ai-harness"
- ✅ "Claude Pro 订阅 OAuth"
- ❌ "我们的 AI 助手"（无锚点）
- ❌ "这个工具"（无锚点）

## 5 个常见的 GEO Anti-pattern

| 错误 | 例子 | 修法 |
|---|---|---|
| Q 太抽象 | "AI 编程怎么样？" | "Claude Code Action 在 GitHub issue 上能做什么？" |
| A 太短 | "几分钟。" | 给出具体分解：4-6 分钟 + 30 秒 + 5 分钟 |
| A 不基于正文 | 现编新例子 | 引用正文已经讲过的具体场景 |
| 全是营销话术 | "极致高效""革命性" | 删掉，只留事实 |
| Q & A 重复正文 | 跟某章节一模一样 | Q 视角换一下；A 浓缩到独立可读 |

## 输出格式（manifest 字段）

```yaml
faqs:
  - q: 真实的疑问句，不带「。」结尾的常见，问号正常加
    a: |
      [直接回答][证据][边界]
      可以用 <strong> <code> <a> 等 inline HTML 标记，
      blog-seo 会原样转成 JSON-LD 的 "text" 字段。
```

## 验证：发布后检查

发布后用 Google 的 [Rich Results Test](https://search.google.com/test/rich-results) 输入文章 URL，应该看到：

- ✅ BlogPosting structured data detected
- ✅ FAQPage structured data detected with N questions
- ⚠️ 任何 warning 都要修

Perplexity 的引用通常需要等 24-48 小时被它的 crawler 抓到。直接搜文章关键短语，看是否能命中。
