# illustration-prompts.md — 视觉立意 + gpt-image-2 prompt 实战

**核心原则**：每篇文章的 hero 和 paper-bg 都独立生成 + 互相协调（mood 一致）。下面是从 mood 到 prompt 的实操指南。

## Mood 表（视觉立意起点）

读完素材 + 截图后，用这个表给文章定 mood，后续 hero 和 paper-bg 都按这个 mood 走。

| Mood | 适合内容 | 色调倾向 | 笔触 | 已有参考 |
|---|---|---|---|---|
| `warm-engineering` | 技术博客、工具搭建、自动化 | cream + rust + 暗木色 | vintage engraving 工程图 | solo-cicd-claude-agent |
| `literary-personal` | 散文、个人随笔、自传 | 米白 + sage + 灰玫 | 水彩 + 铅笔 | tuike |
| `somber-critical` | 媒介批评、思辨长文、哲学 | 灰白 + 深红 + 黑 | 老解剖图 / 炼金术插画 | warp-social-media |
| `clinical-bright` | 数据报告、白皮书 | 白底 + 蓝 + 橙 | 现代信息图 | focus-whitepaper |
| `mystic-dark` | 神秘 / 黑色幽默 / 玄学 | 墨黑 + 金 + 暗紫 | 木版印刷 + 错版叠印 | （未尝试） |

## Mood-specific Prompt Templates

### `warm-engineering`

**Hero**：
```
A warm muted illustration in the style of a vintage paper engraving with hand-tinted color:
<CONCEPT>. Warm cream and rust color palette, subtle ink crosshatching, soft paper texture.
Style references: 19th century technical manual illustration, William Morris workshop scene.
No people unless required. No text. No legible code or letters.
Aspect ratio 16:9, banner composition. Tasteful, literary, slightly nostalgic.
```

**Paper-bg**：
```
A seamless warm paper texture, like aged 19th-century engineering blueprint paper.
Cream and light beige tones with subtle ink stains, brown fiber flecks, and very faint
sepia drafting compass marks at the edges. No central subject. No text. No legible drawings.
The texture should tile cleanly. Aspect ratio 16:10, high resolution.
```

### `literary-personal`

**Hero**：
```
A warm muted illustration evoking a quiet introspective moment: <CONCEPT>.
Soft watercolor wash over hand-drawn pencil lines. Cream paper, dusty rust accent,
sage green secondary tone. The composition feels still and contemplative.
Style references: Andrew Wyeth, Beatrix Potter quiet interior scenes.
No legible text. Aspect ratio 4:3.
```

**Paper-bg**：
```
A seamless aged paper texture with very subtle watercolor wash —
warm cream base with faint sage green and dusty rose hints near the edges,
suggesting a personal journal page. No drawings, no text, no central subject.
Soft fiber grain. Tile cleanly. 16:10 high resolution.
```

### `somber-critical`

**Hero**：
```
An ominous yet refined illustration in vintage scientific diagram style:
<CONCEPT>. Cream paper background going slightly grayer at edges,
hand-drawn cross-hatching, deep red and muted teal accent colors.
Suggests an old anatomy plate or alchemical diagram with hidden meaning.
Style references: Vesalius anatomical engravings, Athanasius Kircher illustrations.
No people unless required. No modern objects. No text. Aspect ratio 16:9.
```

**Paper-bg**：
```
A seamless aged paper texture in muted greyed cream, with very faint cross-hatching
patterns and dark ink stains scattered subtly. Hints of deep red and teal at corners.
No central subject. No text. The mood is quiet but unsettling. Tile cleanly. 16:10.
```

### `clinical-bright`

**Hero**：
```
A clean modern infographic-style illustration: <CONCEPT>.
White or off-white background with crisp blue and orange accent colors,
thin geometric lines, minimal flat shading. Style references: contemporary
information design, Edward Tufte plates. No serif decoration. No text.
Aspect ratio 16:9.
```

**Paper-bg**：
```
A near-white seamless background with extremely subtle pale-grey grid pattern
suggesting graph paper or technical drafting sheet. No central subject.
No content. Just a faint structural grid. Tile cleanly. 16:10.
```

### `mystic-dark`

**Hero**：
```
A mysterious dark illustration in woodblock print style: <CONCEPT>.
Deep ink-black background with gold and dim purple accents. Heavy contrast,
slightly mis-registered color layers like old multi-block printing.
Style references: Ukiyo-e night scenes, occult Tarot iconography.
No legible text or symbols. Aspect ratio 16:9.
```

**Paper-bg**：
```
A near-black seamless background with subtle ink texture and very faint gold leaf flecks
scattered randomly. Heavy paper grain. No central subject. Suggests a midnight altar cloth.
Tile cleanly. 16:10.
```

## 协同生成（hero + bg）实战

关键：**两次生成共用同一个 `--mood` 标记**，让 prompt 中相同的色彩词描述（"warm cream", "muted teal" 等）反复出现，gpt-image-2 自然会给出色调一致的结果。

**推荐执行顺序**：先生成 paper-bg（氛围底）→ 看一眼 → 再生成 hero（要在 bg 之上能看得清）。

**反例 / 不要做**：
- ❌ `cp tuike/paper-bg.jpg`（强制视觉雷同）
- ❌ Hero 是 warm-engineering 但 paper-bg 是 clinical-bright（撞色）
- ❌ Concept 太抽象（"画一个 CI 流水线"）→ 出图必废

## CONCEPT 怎么写得好

具体到能视觉化的句子，至少包含：**主体物 + 光线/时刻 + 周边元素 + 隐喻指向**。

| 抽象主题 | ❌ 错的 CONCEPT | ✅ 对的 CONCEPT |
|---|---|---|
| CI/CD 自动化 | a CI/CD pipeline | a single small wooden writing desk by an open window at golden hour, holding only a closed laptop. From the laptop drift faint translucent geometric shapes — gears, branching arrow loops, dotted flowchart lines — floating upward and out through the window into a soft cream-and-rust sky |
| 童年阴影 | a sad childhood memory | an empty wooden chair on a tide-receded beach at dusk. A single candle on the chair, half-melted. Distant lighthouse blinks once. Soft fog. The composition feels like something just left this scene |
| 社交媒体 = Warp | social media as warp space | a translucent sailing ship suspended in dark swirling space, surrounded by half-formed face-like entities pressing against its glowing protective bubble. The ship is intricate but the entities feel distant and dreamlike |

## gpt-image-2 已知坑

- **`(按次)gpt-image-2`** 模型 ID 必须带中文前缀。`-d` 传 body 会破坏 UTF-8，用 `--data-binary @file.json`。
- **No text 经常被违反**：生成出来图上有涂鸦文字 → 重试一次基本能解决。
- **人脸质量差**：默认 "no people unless required"，如果必要写 "small distant silhouette" 或 "person seen from behind"。
- **Cloudflare 524**：~20% 失败率，自动重试一次。
- **Python on Windows SSL EOF**：用 curl via subprocess.run 调用，不用 requests.post。
- **预算**：gpt-image-2 按次计费。Hero + paper-bg 一篇 = 2 次 API call，不要 speculative 重试。
