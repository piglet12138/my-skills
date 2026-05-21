# manifest-schema.md — blog-content → blog-seo 契约

`blog-content` 输出 `/tmp/blog-draft-<SLUG>.yaml`，`blog-seo` 读取并消费。这个 schema 是两者唯一的接口。

## 完整字段

```yaml
# 必填 - 基本信息
slug: solo-cicd-claude-agent
title: 单人项目 CI/CD：让 @claude 自己跑流水线
subtitle: 一天 14 个 PR、零命令行、GitHub Actions × Claude Code Agent 的完整链路   # 可选，副标题（italic 衬线展示）
description: |
  一套面向单人开发者的全自动 CI/CD 流水线：在 GitHub 提 issue 评论 @claude，
  agent 自动改代码、开 PR、跑 CI、自动 merge，本地 watcher 拉到预览。
  以 claude-ai-harness 为例的完整实现与一天 14 个 PR 的实战记录。
  # 50-160 字，用于 meta description / og:description

# 必填 - 时间
date_published: 2026-05-21
date_modified: 2026-05-22

# 必填 - 主题选择
theme: warm-paper             # warm-paper | whitepaper | minimal | custom
# warm-paper: tuike / warp / cicd 风（暖纸 + 衬线 + rust）
# whitepaper: focus-whitepaper 风（白底 + 黑字 + 橙强调）
# minimal: 纯黑白衬线
# custom: 提供完整 css 字符串（高级）
# 注意：theme 决定 Astro 模板结构（typography、layout），但视觉差异化主要靠下面的 hero + paper-bg + mood，
# 而不是改 theme。多篇 warm-paper 文章看起来不一样，是因为 hero/bg 不同。

# 必填 - 视觉立意 mood（决定 hero + paper-bg 的视觉气质）
mood: warm-engineering        # warm-engineering | literary-personal | somber-critical | clinical-bright | mystic-dark
# 详见 blog-content/references/illustration-prompts.md 的 mood 表
# 同一篇文章的 hero 和 paper-bg 必须用同一个 mood 调用 gen-hero.sh，保证视觉协调

# 可选 - 双语
language: zh-CN
en_url: null                  # 若有英文版填 https://sg.yaoyuheng2001.me/posts/<slug>/en/

# 必填 - SEO/GEO 元数据
keywords:                     # 5-15 个，主关键词 + 长尾
  - CI/CD
  - GitHub Actions
  - Claude Code
  - Solo Developer
  - AI Agent
tags:                         # 高层分类，会变成 <meta property="article:tag">
  - CI/CD
  - GitHub Actions
  - Claude Code
  - DevOps
section: 工程实践 / DevOps    # <meta property="article:section">
word_count: 5800              # 大约字数；blog-seo 自动用在 JSON-LD

# 必填 - 视觉素材（每篇独立生成，不复用其他文章的）
hero_image: hero.png          # 文件名（gen-hero.sh --kind hero 生成，已在 /root/blog/public/images/<slug>/）
paper_bg: paper-bg.jpg        # 背景纹理文件名（gen-hero.sh --kind paper-bg 生成，同上目录）
hero_alt: |
  一张温暖色调的版画式插图：木桌上放着一台合着的笔记本，
  从中飘出齿轮与箭头组成的自动化流水线，穿过窗户飘向夕阳余晖的天空。

# 可选 - CTA 按钮（lead 段下方）
ctas:
  - label: 在线体验 →
    url: https://claude.yaoyuheng2001.me
    style: primary            # primary | secondary
  - label: GitHub 源码
    url: https://github.com/piglet12138/claude-ai-harness
    style: secondary
  - label: 直接看 workflows
    url: https://github.com/piglet12138/claude-ai-harness/tree/main/.github/workflows
    style: secondary

# 必填 - lead 段落（hero 图下方第一段，italic 衬线展示）
lead: |
  在 GitHub 上提一个 issue，评论里写 @claude，五分钟后修复的代码已经在我浏览器里待我 Ctrl+F5 验收。
  我点头说『上线』，再过十几秒它就在 prod 跑了。除了写 issue 和按 F5，全程 0 命令行。
  这篇博客记录这套面向单人开发者的全自动 CI/CD 流水线 ——
  以 <a href="https://github.com/piglet12138/claude-ai-harness">claude-ai-harness</a> 为例 ——
  一天下来跑了 14 个 PR、修了 9 个 issue 的完整结构，外加几个值得记一笔的坑。

# 必填 - 正文 body（已是 Astro-template-ready HTML 片段）
body: |
  <h2>章节一标题</h2>
  <p>段落正文...</p>
  <figure>
    <img src="/images/solo-cicd-claude-agent/shot-pr-list.png" alt="详细描述这张截图..." />
    <figcaption>caption 文字（GEO 关键）</figcaption>
  </figure>
  <h2>章节二</h2>
  <p>...</p>
  <pre><code>$ command --here
output line
</code></pre>
  ...
# 注意：
# - 直接用 HTML 标签，不写 markdown
# - 截图引用绝对路径 /images/<slug>/<filename>
# - <code> 块里的 <、> 用 &lt; &gt; 实体
# - 不要在正文写裸的 {xxx}（Astro 会当 JSX 表达式）

# 必填 - FAQ（GEO 核心）
faqs:
  - q: 这套 @claude 驱动的 CI/CD 跟 Jenkins / GitLab CI / GitHub Copilot Workspace 有什么本质区别？
    a: |
      传统 CI 只跑你写好的 pipeline，不替你写代码。Copilot Workspace 能改代码但不接 deploy。
      这套流水线把两件事串起来：在 GitHub issue 评论写 @claude，Claude Code Action 读 issue、改源码、推 feature 分支；
      auto-pr.yml 接力开 PR，ci.yml 跑 smoke，GitHub 自动 merge 进 dev，本地 watcher 拉到预览。
      你说『上线』后 ff-merge 推一下，deploy.yml SSH 到 VPS。从『写 issue』到『线上生效』5-10 分钟，0 命令行。
  - q: ...
    a: ...

# 可选 - 站点级更新（如果不填，blog-seo 默认自动加）
update_homepage: true         # 是否更新 src/pages/index.astro 的 posts 列表
update_rss: true              # 是否更新 src/pages/rss.xml.ts

# 可选 - 直接发布 or 暂存
auto_publish: true            # true = blog-seo 会自动 build + commit + push + IndexNow
                              # false = 只生成 index.astro，等用户手动审阅
```

## blog-seo 怎么使用

```bash
# blog-seo skill 收到的指令大概是：
SLUG="solo-cicd-claude-agent"
MANIFEST="/tmp/blog-draft-$SLUG.yaml"

# 它会：
# 1. yq 解析 manifest
# 2. 选模板 (warm-paper.astro.tmpl)
# 3. 填入所有字段（含 SEO meta、JSON-LD BlogPosting + FAQPage）
# 4. scp 到服务器 src/pages/posts/$SLUG/index.astro
# 5. 更新 index.astro posts 列表 + rss.xml.ts
# 6. npm run build
# 7. 验证 (curl 200 + grep markers)
# 8. git commit + push + IndexNow ping
```

## 何时不需要 manifest？

如果用户直接给一份已经写好的 Astro 文件（手工写的），不需要 blog-content，可以**直接调用 blog-seo** 跳过 manifest 步骤。blog-seo 的入参支持两种：

- A. 一个 manifest YAML（来自 blog-content）
- B. 一个已经写好的 `.astro` 文件路径（用户手工产出）
