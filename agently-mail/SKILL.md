---
name: agently-mail
description: "通过 Agently Mail CLI 收发和管理邮件。当用户需要发送邮件、读取邮件、搜索邮件、回复/转发邮件或检查授权邮箱时使用。"
version: 1.0.0
author: Yao Yuheng
tags: [email, agently, qqmail, cli, oauth]
triggers:
  - /agently-mail
  - /mail
---

# /agently-mail — Agently Mail CLI 邮件操作

## 触发条件

当用户需要以下任一邮件操作时使用：
- 发送纯文本或 HTML 富文本邮件
- 查看当前授权邮箱和别名
- 列出、读取、搜索邮件
- 回复或转发邮件
- 上传/下载邮件附件
- 安装、更新或重新授权 Agently Mail CLI

## 当前机器配置

- CLI：`agently-cli`
- 已验证授权邮箱：`yaoyuheng9352@agent.qq.com`
- 常用测试收件人：`879751008@qq.com`
- 安装文档：`https://agent.qq.com/doc/cli-setup.md`
- 管理端：`https://agent.qq.com`

> 注意：授权状态是机器本地状态。换机器、换容器、换用户、keychain 丢失时需重新执行 OAuth 授权。

## 前置条件

### 安装 / 更新 CLI

```bash
npm install -g @tencent-qqmail/agently-cli
```

### 安装 / 更新 Skill

```bash
npx skills add Tencent/AgentlyMail -g -y
```

已知安装输出可能出现：

```text
PromptScript: PromptScript does not support global skill installation
```

如果同时看到 `~/.agents/skills/agently-mail` 和 `symlinked: Claude Code`，说明 Claude Code 侧已安装成功；该报错是 PromptScript 全局安装兼容性问题。

## 授权流程

### 1. 启动 OAuth 登录

```bash
agently-cli auth login
```

执行要求：
- 该命令会等待用户浏览器授权完成。
- 在 agent 环境中建议后台运行，并读取 stdout/stderr 中的原始授权 URL。
- 不要改写、编码、解码、补字符、重拼 query，也不要把 URL 改成 Markdown 链接。

向用户展示时必须使用以下格式：

```text
请点击或复制以下链接在浏览器中完成授权：

<CLI 原样输出的授权 URL>
```

### 2. 验证授权

```bash
agently-cli +me
```

成功时返回 JSON，其中 `data.aliases[].email` 是可用发件别名。当前机器已验证：

```text
yaoyuheng9352@agent.qq.com
```

验证成功后，用简洁格式告知用户：

```text
邮箱地址 xxx 已授权成功，可以用它来收发邮件了
```

## 常用命令

### 查看当前账号

```bash
agently-cli +me
```

### 列出邮件

```bash
agently-cli message +list --limit 10
```

### 读取邮件

```bash
agently-cli message +read --id msg_001
```

### 搜索邮件

```bash
agently-cli message +search --q "keyword"
```

### 发送纯文本邮件

```bash
agently-cli message +send \
  --to recipient@example.com \
  --subject "邮件标题" \
  --body "邮件正文"
```

### 发送 HTML 富文本邮件

```bash
agently-cli message +send \
  --to recipient@example.com \
  --subject "富文本邮件标题" \
  --body-format html \
  --body '<!doctype html><html><body><h1 style="color:#7c3aed;">Hello</h1><p>HTML email</p></body></html>'
```

富文本支持范围以邮件客户端渲染为准。优先使用：
- inline CSS
- 表格布局
- 简单渐变 / 背景色 / 圆角 / 边框
- 链接按钮
- 图片链接或附件

避免依赖：
- 外部 CSS 文件
- JavaScript
- 复杂 CSS 动画
- 现代布局在旧邮箱客户端中的一致性

### 带附件发送

附件路径必须是相对当前目录的相对路径。

```bash
agently-cli message +send \
  --to recipient@example.com \
  --subject "带附件邮件" \
  --body "见附件" \
  --attachment ./report.pdf
```

限制以 `agently-cli +me` 返回为准。当前验证返回：
- 单封最多 3 个附件
- 单个附件最大 1 MiB
- 附件总大小最大 3 MiB

### 回复邮件

```bash
agently-cli message +reply --id msg_001 --body "谢谢，已收到。"
```

### 上传 / 下载附件

```bash
agently-cli attachment +upload --file ./report.pdf
agently-cli attachment +download --msg msg_001 --att att_001
```

## 发送确认机制

`message +send` 是两阶段确认：

1. 第一次调用返回：
   - `confirmation_required: true`
   - `confirmation_token`
   - `summary`
2. 必须让用户确认收件人、主题、正文摘要、附件数量。
3. 用户确认后，带上 token 重跑同一发送命令：

```bash
agently-cli message +send \
  --to recipient@example.com \
  --subject "邮件标题" \
  --body "邮件正文" \
  --confirmation-token ctk_xxx
```

成功返回示例：

```json
{
  "ok": true,
  "data": {
    "queued": true
  }
}
```

用户明确说“发送”“确认发送”“发吧”等，才执行第二阶段。

## 推荐工作流

### Phase 1：确认意图

确定：
- 收件人 `--to`
- 抄送 / 密送（如有）
- 主题
- 正文格式：`plain` 或 `html`
- 附件（如有）

### Phase 2：构造并预提交

运行 `agently-cli message +send ...` 获取确认 token。

### Phase 3：给用户确认摘要

展示：
- From
- To / CC / BCC
- Subject
- Body 摘要或完整正文
- Attachment count

### Phase 4：确认后发送

用户确认后追加 `--confirmation-token` 完成发送。

### Phase 5：报告结果

只报告关键状态，例如：

```text
已发送，状态 queued。
```

## 安全与隐私规则

- 不要未经用户确认发送邮件。
- 不要把授权 URL 改写成 Markdown 链接。
- 不要在日志或回复中泄露 OAuth token、confirmation token 以外的敏感凭据。
- confirmation token 只用于当前发送动作，不要复用到其他邮件。
- 发送给外部收件人前，必须展示摘要并等待确认。
- 如果正文包含密码、密钥、身份证、银行卡等敏感信息，发送前明确提醒用户。

## Gotchas

- `auth login` 会阻塞等待浏览器授权；agent 环境中建议后台运行并读取输出文件。
- 授权失败或超时时，不要盲目重复；先把 CLI 原始错误反馈给用户。
- `message +send` 第一次不会真正发送，只会返回 `confirmation_token`。
- HTML 邮件需要 `--body-format html`，否则会按纯文本显示标签。
- shell 中传 HTML 容易被引号破坏；复杂 HTML 建议用单引号包裹，内部属性用双引号。
- 附件路径必须是相对路径，不是绝对路径。
- 邮件客户端会过滤部分 CSS/JS；最稳的是 table + inline CSS。
