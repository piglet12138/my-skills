---
name: meta-skill
description: "Meta Skill — 生成 Skill 的 Skill。当用户需要创建新的 Claude Code Skill、改进现有 Skill、或评估 Skill 质量时使用。融合 Anthropic/OpenAI/GitHub 各家最佳实践，内置静默调研与质量评测机制。"
version: 1.0.0
author: Yao Yuheng
tags: [meta, skill-maker, claude-code, quality, eval]
triggers:
  - /meta-skill
  - /create-skill
---

# Meta Skill — 生成 Skill 的 Skill

> 普通 Meta Skill 只做一件事：识别用户意图，生成 Skill。
> 本 Meta Skill 在此基础上增加两层：**静默调研**（边识别意图，边检索世界级工程标准）和 **Eval 驱动迭代**（用评测体系反复打磨输出质量）。

## 核心理念

1. **站在巨人肩膀上** — 全球聪明人很多，你的想法大概率已经有人实现过。先找到最佳实践，再做微创新。
2. **静默策略** — 在用户等待的同时，AI 自动检索相关优秀开源项目和顶级工程标准，显著提高第一版 Skill 质量。
3. **Eval 驱动** — 用多维度评测体系不断迭代，而不是凭感觉调试。

## 触发条件

当用户表达以下意图时自动触发：
- "帮我写一个 skill / 创建一个 skill"
- "把这个流程做成 skill"
- "优化 / 改进这个 skill"
- "评估这个 skill 的质量"
- 明确使用 `/meta-skill` 或 `/create-skill`

---

## 工作流：5 个阶段

### Phase 0: 意图识别 + 静默调研（并行执行）

**这是本 Meta Skill 的核心创新。** 两件事同时发生：

#### 0A. 意图识别

从用户输入中提取：

| 提取项 | 示例 |
|--------|------|
| **领域** | 博客发布、API 集成、数据处理、DevOps... |
| **核心动作** | 爬取、部署、生成、分析、转换... |
| **输入/输出** | 输入 URL → 输出 Markdown；输入代码 → 输出测试... |
| **约束条件** | 需要认证、有速率限制、特定格式要求... |
| **复杂度预判** | 单步操作 / 多阶段流水线 / 多 Agent 协作 |

#### 0B. 静默调研（不等用户确认，与 0A 并行）

用 Agent 工具并行执行以下调研：

```
1. 在 GitHub 搜索相关开源项目和 awesome 列表
   → 目标：找到该领域的最佳实践代码
   
2. 搜索 Claude Code / Copilot 社区是否有类似 Skill
   → 目标：避免重复造轮子，借鉴已有方案
   
3. 检索该领域的官方文档和 API 规范
   → 目标：确保 Skill 调用的接口和格式正确
```

**输出**：一份调研摘要（200 字内），列出：
- 找到的 N 个相关项目/Skill 及其亮点
- 该领域的关键技术约束
- 推荐借鉴的设计模式

### Phase 1: 架构设计

基于意图 + 调研结果，确定 Skill 架构：

#### 1.1 选择 Skill 类型

| 类型 | 适用场景 | 复杂度 | 示例 |
|------|---------|--------|------|
| **单步工具** | 一个命令/脚本解决 | 低 | feishu-fetch, clean-figma |
| **多阶段流水线** | 需要 Phase 1→2→3 | 中 | blog-seo, build-vps-vpn |
| **多 Agent 协作** | 需要并行子任务 | 高 | write-report (3-wave pipeline) |

#### 1.2 确定文件结构

```
skill-name/
├── SKILL.md                 # 主文件（必须）
├── references/              # 深度参考资料（复杂领域）
│   └── api-reference.md
├── scripts/                 # 可执行脚本（如有）
│   └── main.py
└── templates/               # 模板文件（如有）
    └── output-template.md
```

**原则**：
- SKILL.md 控制在 500 行以内（每行都是 token 成本）
- 复杂内容拆到 `references/` — AI 按需读取
- 脚本放 `scripts/` — 保持 SKILL.md 可读

#### 1.3 确定 allowed-tools

根据 Skill 的操作范围限制工具集：

| Skill 类型 | 建议 allowed-tools |
|------------|-------------------|
| 只读/分析 | Read, Grep, Glob, WebFetch |
| 文件生成 | Read, Write, Edit, Bash |
| 部署操作 | Bash, Read, Write |
| 全能型 | 不限制（默认） |

### Phase 2: 生成 SKILL.md

使用下面的模板生成，**每个部分都有明确用途**：

```markdown
---
name: skill-name
description: "一句话说明能力 + 触发时机。格式：'X 能力。当用户需要 Y 时使用。'"
version: 1.0.0
author: Yao Yuheng
tags: [tag1, tag2, tag3]
triggers:
  - /skill-name
---

# /skill-name — 技能标题

## 触发条件
> 什么情况下应该使用这个 Skill？列出 3-5 个具体场景。

## 前置条件
> 需要什么环境、依赖、认证？怎么安装/获取？

## 工作流

### Phase 1: [阶段名]
> 每个阶段：目标 → 具体步骤 → 验证方式
> 包含可直接执行的命令或代码模板

### Phase 2: [阶段名]
> 承接上一阶段的输出，说明数据如何传递

### Phase N: 验证
> 必须有验证阶段。列出 checklist 或自动检查命令。

## 输出
> 最终产出是什么？格式、路径、示例。

## 已知问题 (Gotchas)
> 踩过的坑、边界情况、常见错误及解法。
> 这部分决定了 Skill 的实际可用性。
```

#### 模板核心原则

来自世界级 Skill 的最佳实践：

| 原则 | 来源 | 说明 |
|------|------|------|
| **description 是触发器** | Anthropic + Lark | 必须包含"当用户需要 X 时使用"模式 |
| **验证是必须的阶段** | pptx skill (QA Required) | "第一次渲染几乎永远不对" — 必须有验证环节 |
| **数据先于散文** | write-report (Wave 0 Gate) | 复杂 Skill 必须先准备数据，再执行操作 |
| **Gotchas 决定可用性** | 所有优秀 Skill | 没有 Gotchas 的 Skill 要么没用过，要么在骗人 |
| **500 行上限** | Anthropic 官方建议 | 每行都是 token 成本，复杂内容拆到 references/ |
| **幂等性** | build-vps-vpn | 同一命令执行两次应得到相同结果 |
| **写操作必须预览** | lark-skill-maker | `--dry-run` 或确认提示，防止误操作 |

### Phase 3: 质量评测

生成完成后，用以下维度自评（1-5 分）：

```
┌─────────────┬──────────────────────────────────────────┐
│ 维度         │ 评判标准                                  │
├─────────────┼──────────────────────────────────────────┤
│ 触发准确性   │ description 是否精准？会误触发吗？        │
│ 工程完整性   │ 每个阶段是否可执行？是否缺少步骤？        │
│ 输出稳定性   │ 同样输入，多次执行结果是否一致？          │
│ 错误处理     │ Gotchas 是否覆盖了常见失败场景？          │
│ 测试机制     │ 是否有验证阶段？能自动检测失败吗？        │
│ 上手难度     │ 新用户看完能直接用吗？需要多少前置知识？  │
│ Token 效率   │ SKILL.md 是否精简？是否有冗余？           │
│ 可移植性     │ 换一台机器/换一个用户能直接用吗？         │
└─────────────┴──────────────────────────────────────────┘
```

**评分标准**：
- 5 分（优秀）：该维度达到世界级水平
- 4 分（良好）：超过大多数开源 Skill
- 3 分（及格）：能用但有改进空间
- 2 分（不足）：存在明显缺陷
- 1 分（缺失）：该维度完全未覆盖

**总分 ≥ 32/40 方可交付。低于 32 分必须迭代改进。**

### Phase 4: 迭代改进

如果评测发现薄弱项：

1. **触发准确性不足** → 重写 description，加入更多触发场景
2. **工程完整性不足** → 补充缺失的 Phase，加入中间验证步骤
3. **输出不稳定** → 加入更具体的模板和约束，减少 AI 自由发挥空间
4. **错误处理不足** → 回顾调研结果，补充该领域常见 Gotchas
5. **测试机制缺失** → 生成 `scripts/test.sh` 或验证 checklist
6. **上手难度高** → 加入 Quick Start 示例，简化前置条件
7. **Token 效率低** → 拆分到 references/，精简 SKILL.md 主体
8. **可移植性差** → 减少硬编码路径，使用环境变量

---

## 已有 Skill 的改进流程

当用户要求改进现有 Skill 时：

1. **读取当前 SKILL.md** — 理解现有结构
2. **用评测维度打分** — 找到薄弱项
3. **静默调研** — 搜索该领域是否有新的最佳实践
4. **定向改进** — 只改薄弱项，不破坏已有优势
5. **重新评测** — 确认总分提升

---

## Skill 评估（横向对比）

当用户要求评估 Skill 质量时：

```bash
# 读取目标 Skill
Read skill-a/SKILL.md
Read skill-b/SKILL.md

# 用 8 维度评分表打分
# 生成对比表格 + 改进建议
```

输出格式：

```
| 维度         | Skill A | Skill B | 胜出 |
|-------------|---------|---------|------|
| 触发准确性   | 4       | 3       | A    |
| 工程完整性   | 3       | 5       | B    |
| ...         | ...     | ...     | ...  |
| 总分         | 29/40   | 34/40   | B    |
```

---

## 反模式（不要这样做）

| 反模式 | 为什么不好 | 正确做法 |
|--------|-----------|---------|
| SKILL.md 超过 500 行 | Token 成本高，AI 容易忽略后半部分 | 拆分到 references/ |
| 没有 Gotchas 部分 | Skill 没被实战验证过的标志 | 至少 3 条真实踩坑 |
| description 写成论文 | AI 触发逻辑靠 description 匹配，太长反而不精准 | 一句话：能力 + 触发时机 |
| 硬编码路径和密钥 | 换机器就挂 | 用环境变量或参数 |
| 只有 happy path | 真实世界 50% 是异常路径 | 每个 Phase 都考虑失败分支 |
| 没有验证阶段 | "第一次渲染几乎永远不对" | Phase N 必须是验证 |

---

## 世界级标准参考

本 Meta Skill 融合了以下来源的设计智慧：

| 来源 | 借鉴了什么 |
|------|-----------|
| **Anthropic skill-creator** | SKILL.md 格式规范、500 行上限、description 触发机制 |
| **Anthropic pptx skill** | QA 必须阶段、"第一次渲染永远不对"哲学、子 Agent 做质量审查 |
| **Anthropic write-report** | 3-wave 并行架构、数据先于散文、引用验证管线、references/ 分层 |
| **OpenAI Custom GPTs** | 低门槛上手体验、预览测试机制 |
| **GitHub Copilot Skills** | SKILL.md 跨平台可移植性、agent skills 统一格式 |
| **Lark skill-maker** | "当用户需要 X 时使用"触发模式、--dry-run 预览、scope 文档化 |
| **Claude Code 架构** | 工具权限隔离 (allowed-tools)、token 成本意识、简洁优先 |
