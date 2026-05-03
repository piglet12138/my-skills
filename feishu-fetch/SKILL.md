---
name: feishu-fetch
description: 通过 Cookie 认证拉取飞书公开文档的完整内容，绕过 JS 渲染限制，输出纯文本。
version: 1.0.0
tags: [feishu, scraping, document, cookie, puppeteer]
triggers:
  - /feishu-fetch
---

# /feishu-fetch — 飞书文档内容拉取

## 触发条件
用户提供飞书文档 URL（`feishu.cn/docx/...`），需要获取其完整正文内容。

## 前置条件

### 依赖
```bash
node --version   # 需要 Node.js
cd /tmp && npm install puppeteer
# Chrome 系统依赖（Ubuntu/Debian）：
apt-get install -y libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
  libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 \
  libgbm1 libasound2t64 libcairo2 libpango-1.0-0 libpangocairo-1.0-0 \
  libnspr4 libnss3 libx11-xcb1
```

### Cookie 获取方法
1. 浏览器打开飞书文档，确保已登录且能看到内容
2. F12 → Network → 刷新页面
3. 点击任意 `feishu.cn` 请求 → Request Headers → 复制 `Cookie:` 整行值

## 执行流程

### Phase 1：探测文档是否需要登录

```bash
curl -s -o /dev/null -w "%{http_code}" "https://jiahejiaoyu.feishu.cn/docx/DOC_ID" -L
# 302 → 需要登录；200 → 可能公开
```

### Phase 2：用 Puppeteer 注入 Cookie 加载页面，拦截 API 响应

飞书文档内容通过 `client_vars` 分页 API 加载，需拦截该接口：

```javascript
// /tmp/intercept_feishu.js
const puppeteer = require('/tmp/node_modules/puppeteer');
const fs = require('fs');

const COOKIE_STR = `/* 粘贴完整 Cookie 字符串 */`;
const DOC_ID = 'YHOHd1TLyom6KDxQY8Ac8m4hngf'; // 从 URL 提取

const cookies = COOKIE_STR.split('; ').map(c => {
  const [name, ...rest] = c.split('=');
  return { name: name.trim(), value: rest.join('='), domain: '.feishu.cn', path: '/' };
});

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
  });
  const page = await browser.newPage();
  await page.setCookie(...cookies);

  const captured = [];
  page.on('response', async (res) => {
    const url = res.url();
    if (url.includes('client_vars') && !url.includes('cursor=')) {
      try { captured.push(await res.text()); } catch(e) {}
    }
  });

  await page.goto(`https://jiahejiaoyu.feishu.cn/docx/${DOC_ID}`, {
    waitUntil: 'domcontentloaded', timeout: 60000
  });
  await new Promise(r => setTimeout(r, 8000));

  // 验证登录状态
  const bodyText = await page.evaluate(() => document.body.innerText);
  if (bodyText.includes('Log In or Sign Up')) {
    console.error('Cookie 已过期，请重新获取');
    process.exit(1);
  }

  // 找到 API 端点
  const apiUrls = captured.map(c => '找到 client_vars API');
  console.log('API 端点已确认，开始直接调用');
  fs.writeFileSync('/tmp/feishu_api_confirmed.txt', 'ok');
  await browser.close();
})();
```

### Phase 3：直接调用分页 API 提取全文

```python
# /tmp/extract_feishu.py
import json, urllib.request, urllib.parse, time

COOKIE = '/* 粘贴完整 Cookie 字符串 */'
DOC_ID = 'YHOHd1TLyom6KDxQY8Ac8m4hngf'

def fetch_page(cursor=None):
    url = f'https://jiahejiaoyu.feishu.cn/space/api/docx/pages/client_vars?id={DOC_ID}&mode=7&limit=239'
    if cursor:
        url += f'&cursor={urllib.parse.quote(cursor)}'
    req = urllib.request.Request(url, headers={
        'Cookie': COOKIE,
        'Referer': f'https://jiahejiaoyu.feishu.cn/docx/{DOC_ID}',
        'User-Agent': 'Mozilla/5.0'
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def extract_text(block):
    try:
        texts = block['data']['text']['initialAttributedTexts']['text']
        return ''.join(texts.values())
    except:
        return ''

all_blocks = {}
all_sequence = []
cursor = None

while True:
    data = fetch_page(cursor)['data']
    all_blocks.update(data.get('block_map', {}))
    all_sequence.extend(data.get('block_sequence', []))
    print(f'已拉取 {len(all_blocks)} 个块', flush=True)
    if not data.get('has_more'):
        break
    cursor = data.get('cursor')
    if not cursor:
        break
    time.sleep(0.3)

lines = []
seen = set()
for bid in all_sequence:
    if bid in seen or bid not in all_blocks:
        continue
    seen.add(bid)
    t = extract_text(all_blocks[bid])
    if t.strip():
        lines.append(t)

with open('/tmp/feishu_output.txt', 'w') as f:
    f.write('\n'.join(lines))
print(f'完成！共 {len(lines)} 个文本块，{sum(len(l) for l in lines)} 字符')
```

```bash
python3 /tmp/extract_feishu.py
```

## 数据结构说明

飞书 `client_vars` API 响应结构：
```
data.block_map[block_id].data.text.initialAttributedTexts.text
  → dict，values() 拼接即为该块的纯文本
data.block_sequence  → 块的顺序列表
data.has_more        → 是否还有下一页
data.cursor          → 下一页游标
```

## 已知 Gotchas

- **Cookie 有效期短**：飞书 session 通常数小时内过期，需重新获取
- **必须包含的关键 Cookie**：`session`、`_csrf_token`、`sl_session`、`passport_web_did`，缺少任一可能导致 403
- **Chrome 系统库**：Ubuntu 24.04 的 `libasound2` 包名变为 `libasound2t64`
- **`networkidle2` 会超时**：飞书页面有长连接 WebSocket，必须用 `domcontentloaded`
- **内容懒加载**：直接读 `document.body.innerText` 只能拿到目录，需通过 API 分页拉取
- **API 端点格式**：`/space/api/docx/pages/client_vars?id=DOC_ID&mode=7&limit=239`，limit 最大约 239

## 输出

- `/tmp/feishu_output.txt`：文档完整纯文本，按原始块顺序排列
