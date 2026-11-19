# 微信群投票

一个极简的网页投票：创建投票 → 把链接发到微信群 → 群友点开填昵称投票 → 实时看结果。

- 前端：单个 `index.html`，不依赖任何外部库，托管在 GitHub Pages
- 数据：Supabase（免费）

## 部署

1. 在 [supabase.com](https://supabase.com) 用 GitHub 登录，新建项目（Region 选 Singapore 或 Tokyo，国内访问更快）
2. 打开项目 → SQL Editor，粘贴运行 `schema.sql`
3. 打开 Project Settings → API，复制 **Project URL** 和 **anon public key**，填到 `index.html` 顶部
4. 推送到 GitHub，在仓库 Settings → Pages 里选 `main` 分支，保存
5. 访问 `https://fangzhoupig.github.io/wechat-vote/`

## 说明

- anon key 本来就是公开用的，安全靠 `schema.sql` 里的行级权限保证：只能读和新增，不能改、删
- 防重复投票：同一投票里同一昵称只能投一次，浏览器也会记住你投过。这是"君子协定"级别的防护，够群里日常使用
- Supabase 免费项目连续 7 天没人访问会暂停，去后台点一下就能恢复
