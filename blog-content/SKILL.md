---
name: blog-content
description: "为 sg.yaoyuheng2001.me 起草一篇博客文章。从用户提供的素材（笔记、截图、想法）出发：先做视觉立意（分析内容定 mood → 设计 hero 主视觉与背景的协同概念）→ 生成 hero 插图 + 配套 paper-bg（gpt-image-2 / LuckyAPI，每篇独立，不复用）→ 处理截图 → 规划章节结构 → 写正文 → 拟 FAQ → 输出 manifest 文件交给 blog-seo skill 完成排版+SEO+发布。不负责 Astro 模板、SEO meta、JSON-LD、构建部署。"
type: skill
tags: [blog, writing, illustration, visual-ideation, gpt-image-2, content]
triggers:
  - /blog-content
---

# /blog-content — 起草一篇图文博客

## 这个 skill 做什么 / 不做什么

| 做 ✅ | 不做 ❌ |
|---|---|
| 与用户对齐主题、受众、key points | Astro 模板渲染 |
| **视觉立意（根据内容定 mood + hero/bg 概念）** | meta 标签 / og: / article: |
| **生成 hero 插图 + 配套 paper-bg（每篇独立）** | JSON-LD BlogPosting / FAQPage |
| 处理用户截图（shrink、命名、放到 blog public dir） | `<head>` 样式表 |
| 规划章节结构（h2/h3） | npm run build |
| 写正文段落 | git commit / push |
| 拟 FAQ Q & A | IndexNow ping |
| 选 tag / keywords | 站点级 RSS / index.astro 更新 |
| 输出 manifest YAML 给 blog-seo | （以上一律交给 `blog-seo`）|

**简单分工**：本 skill 决定「文章有什么内容 + 长什么样」，`blog-seo` 决定「怎么打包发出去」。

**关键原则**：**每篇文章的视觉都是独立的**。hero 插图和 paper-bg 必须跟当篇内容的 mood/topic 匹配，不要复用其他文章的素材（包括 tuike 那张暖纸 bg）。视觉一致性靠 typography + 色调倾向 + 版画质感，**不靠复用 asset**。

## 触发后的决策点

按顺序逐项跟用户确认：

1. **POST_SLUG**（小写连字符）
2. **title** + **subtitle**（可选，italic 衬线副标题）
3. **目标读者**（影响语气：技术博客 vs 散文 vs 长论文）
4. **核心 take-away**
5. **素材清单**：笔记 / 提纲 / 已有文字 + 截图所在目录
6. **是否需要 hero 插图 + paper-bg**：默认 yes
7. **章节大纲**：skill 先提议 N 个 h2，让用户增删改
8. **FAQ Q list**：skill 先提议 5-8 个，让用户增删改
9. **是否有英文版**：影响 hreflang

## 工作流（执行顺序）

### Step 1 — 对齐主题 + 大纲

让用户回答上面 1-5 项后，整理一个**大纲草案**给用户审。用户改完才进 Step 2。

### Step 2 — 视觉立意（关键 / 新增）

读完素材 + 截图后，**在生成任何图之前**，先跟用户对齐这篇文章的视觉气质。从下面三层做决定：

#### 2.1 Mood 判断

> ⚠️ **历史 bug 警示**：早期 agent 默认选 `warm-engineering`,导致 SaaS 产品发布、数据对比类文章 hero 全部跟 tuike(literary-personal)视觉撞车 —— 因为这两个 mood 都用 cream/sepia 暖纸调,gpt-image-2 出图风格几乎不可区分。**所以 mood 必须严格匹配文章主类型,不能用默认值或"差不多就行"**。

**Step 1 — 用决策树定位 mood（按顺序判断,匹配第一项就停）：**

| 这篇文章核心是…… | 选 mood | 关键词 |
|---|---|---|
| 现代 SaaS 产品发布 / 数据报告 / 对比分析 / 价格表 / API 文档 | **`clinical-bright`** | 白底,蓝 + 橙,IBM Plex,Tufte 信息图 |
| 工程实践 / DevOps / 工具搭建 / 系统架构 | **`tech-drafting`** | 冷调蓝灰,blueprint,等距示意图 |
| 散文 / 个人随笔 / 心情记录 / 自传 | **`literary-personal`** | 米白 + sage + 灰玫,水彩 + 铅笔 |
| 媒介批评 / 思辨长文 / 哲学 / 文化评论 | **`somber-critical`** | 灰白 + 深红,老解剖图 |
| 神秘学 / 黑色幽默 / 玄学 / Tarot | **`mystic-dark`** | 墨黑 + 金,木版印刷 |
| **怀旧** 工艺 / 手工 / 老物件 / 旧时代叙事 | **`warm-engineering`** | cream + rust,vintage engraving |

**Step 2 — 反向验证(防止误选)：**

| 文章关键词 | ❌ 不要选 | ✅ 应该选 |
|---|---|---|
| "SaaS / OSS launch / 发布 / pricing / dashboard" | warm-engineering, literary-personal | **clinical-bright** |
| "CI/CD / pipeline / agent / workflow / DevOps" | warm-engineering, clinical-bright | **tech-drafting** |
| "GEO/AEO / monitoring / 平台 / 数据分析" | warm-engineering(撞 tuike) | **clinical-bright** |
| "对比 / vs / 价格表 / feature matrix" | 任何暖色调 mood | **clinical-bright** |
| 怀念 / 时间过去了 / 个人成长 | clinical-bright, tech-drafting | **literary-personal** |
| 老技术 / 复古工坊 / 物件考据 | clinical-bright | **warm-engineering** |

**`warm-engineering` 的真实适用域很窄**:专门给"工艺类怀旧"内容 —— 比如手工木作 / 老相机修复 / 19 世纪工程史这种主题。**现代 SaaS / 数据 / 监测 / DevOps 一律不要选**,会跟 tuike 撞视觉。

**Step 3 — agent 自检:**

在调 `gen-hero.sh` **前**,写出来:

```
本文核心类型 = <一句话描述>
匹配的 mood = <选择>
理由 = <为什么不是其他 mood>
```

把这三行给用户确认后再生成。**不要静默生成。**

#### 2.2 Central metaphor

跟用户讨论这篇文章的**中心意象**。不是"画 CI/CD 流水线"这种抽象 —— 要是**具体能视觉化的物**：

| 抽象主题 | 视觉中心意象 |
|---|---|
| CI/CD 自动化 | 一张木桌 + 自动飘出的齿轮箭头链 |
| 童年阴影 | 暮色海滩 + 退去的潮水 + 蜡烛 |
| 社交媒体批判 | 一艘船 + 漂浮的精神实体 + Gellar Field |
| 单人创业 | 灯塔 + 海雾 + 一个剪影 |

让用户提供 / 选择 / 给候选 3 个让用户挑。**这一步决定 hero 是否打动读者**，不要跳过。

#### 2.3 Background 概念

paper-bg 是全屏的微妙背景。**不是 hero 的扩展，而是独立的氛围底**。选项：

- **literal**：与文章主题字面相关的纹理（机械蓝图 / 老报纸 / 海图 / 星图）
- **mood-only**：纯氛围（雾、烟、纸纤维、织物），不含具象内容
- **palette-bridge**：纯色块或渐变 + 微细颗粒，主要承载色调

默认 **mood-only**（最不会跟正文 hero 抢戏）。

### Step 3 — 生成 paper-bg（每篇独立）

```bash
bash scripts/gen-hero.sh \
  --slug "$SLUG" \
  --style paper-bg \
  --mood warm-engineering \
  --concept "<background 概念，从 Step 2.3 来>"
```

生成 1536x1024 或类似宽屏。保存到 `/root/blog/public/images/$SLUG/paper-bg.jpg`。

**❌ 不要 `cp ../tuike/paper-bg.jpg`**。

### Step 4 — 生成 hero 插图

```bash
bash scripts/gen-hero.sh \
  --slug "$SLUG" \
  --style vintage-engraving \
  --mood warm-engineering \
  --concept "<central metaphor 的具体描述，从 Step 2.2 来>" \
  --palette-hint "cream-rust"
```

`--mood` 跟 paper-bg 保持一致（保证视觉协调）。`--concept` 高度具体（句子级，包含构图 + 光线 + 色彩）。

下载到 `/root/blog/public/images/$SLUG/hero.png` + 本地缩略图供 agent **自检构图**。**自检很重要** —— gpt-image-2 偶尔无视 prompt 加涂鸦文字 / 给人脸糟糕的细节 / 构图失衡，发现问题就 refine prompt 重新生成。

### Step 5 — 处理用户截图

```bash
bash scripts/shrink-shots.sh --src /home/yyh/tmp/fig --slug "$SLUG"
```

脚本会 shrink 用户截图到 width 900 并存到 `/tmp/imgwork/preview-*.jpg`。**接下来 agent 必须**：

1. Read 每个 preview 看截图内容
2. 起有意义的名字（`shot-<内容关键词>.png`）
3. scp 原图到 `/root/blog/public/images/$SLUG/<new-name>.png`
4. 记录 (filename, alt, caption) 进 manifest

⚠️ **不要用 `1.png` `2.png` 这种名字**。alt 要详尽（GEO 关键）。

### Step 6 — 写正文

基于大纲 + 素材 + 截图位置，写章节正文。用 **Astro-template-ready 的 HTML 片段**：

- 段落 `<p>`，截图 `<figure><img><figcaption>`
- alt 写详尽（描述截图实际显示什么）
- 代码块 `<pre><code>`，里面的 `<`、`>` 用 HTML 实体
- 强调 `<strong>` 重要事实/数字/名词
- **不要写裸 `{xxx}`**（Astro 当 JSX 表达式炸），用 `&lt;xxx&gt;` 或 `&#123;xxx&#125;` 转义

### Step 7 — 拟 FAQ

5-8 个 Q&A，A 长度 150-300 字最佳。详见 [references/faq-writing-guide.md](references/faq-writing-guide.md)。

### Step 8 — 选 keywords + tags + section

- **keywords**：5-15 个逗号分隔
- **tags**：高层分类，会变成多个 `article:tag` meta
- **section**：栏目名

### Step 9 — 输出 manifest

组装成 `/tmp/blog-draft-<SLUG>.yaml`，schema 见 [references/manifest-schema.md](references/manifest-schema.md)。

### Step 10 — 移交 blog-seo

告诉用户：
> 内容草稿完成。素材在 `/root/blog/public/images/<SLUG>/`，manifest 在 `/tmp/blog-draft-<SLUG>.yaml`。**下一步**：调用 `blog-seo` skill 完成排版 + SEO + GEO + 发布。

## 与 blog-seo 的契约

manifest 必须传以下视觉相关字段：

```yaml
hero_image: hero.png       # 文件名（已生成到 /root/blog/public/images/<slug>/）
paper_bg: paper-bg.jpg     # 同上
hero_alt: |
  详尽的 alt 描述（GEO 关键）
mood: warm-engineering     # blog-seo 用来选模板配色变种（如果未来支持多 palette）
```

注意 mood 不影响 Astro 模板本身的结构（仍然是 warm-paper template），但**视觉差异化通过独立的 hero + paper-bg 体现**，不靠改 CSS 变量。

## 已发布参考（视觉立意范例）

| 文章 | Mood | Central metaphor | Background |
|---|---|---|---|
| [open-source-citescope](https://sg.yaoyuheng2001.me/posts/open-source-citescope/) | **clinical-bright** | Tufte 棱镜分光 + 6 道彩色光带 + 横轴源域名点 | 近白色 + 极淡冷灰网格 + 角落橙 ticks |
| [solo-cicd-claude-agent](https://sg.yaoyuheng2001.me/posts/solo-cicd-claude-agent/) | **tech-drafting** | 等距 blueprint 数据管道示意图 + 比例尺 + 罗盘标记 | 冷调蓝灰网格纸 |
| [warp-social-media](https://sg.yaoyuheng2001.me/posts/warp-social-media/) | somber-critical | 亚空间漂浮的精神实体 + Gellar Field | 阴沉版画质感 |
| [tuike](https://sg.yaoyuheng2001.me/posts/tuike/) | literary-personal | 退潮的海岸 + 烛火 | 米白 + sage |

⚠️ **反例**: 早期 open-source-citescope 第一版用了 `warm-engineering` mood,生成出的 hero 是黄铜光学测绘仪 + 老地图 + 沉色调,跟 tuike 一眼看不出区别。原因是 warm-engineering 默认词典里的 cream/sepia/parchment 跟 literary-personal 高度重叠。**修复**:重生成时切到 `clinical-bright`,palette 也从 warm 切到 white + 蓝 + 橙,视觉问题立刻消失。这是为什么 2.1 节加了决策树 + agent 自检 + 脚本去掉默认值。

## 文件

- [SKILL.md](SKILL.md) — 本文件
- [scripts/gen-hero.sh](scripts/gen-hero.sh) — LuckyAPI gpt-image-2 调用（hero / paper-bg / 其他 inline 插图共用一个入口）
- [scripts/shrink-shots.sh](scripts/shrink-shots.sh) — sharp 缩图 + 帮助 agent 自检命名
- [references/illustration-prompts.md](references/illustration-prompts.md) — mood 表 + 风格 preset + 协同生成（hero+bg）的实践
- [references/faq-writing-guide.md](references/faq-writing-guide.md) — GEO-friendly FAQ 写作清单
- [references/manifest-schema.md](references/manifest-schema.md) — 跟 blog-seo 的契约

## 上下游

- **上游**：用户素材（笔记、截图、想法）
- **下游**：[blog-seo](../blog-seo/SKILL.md) —— 必须配套使用
