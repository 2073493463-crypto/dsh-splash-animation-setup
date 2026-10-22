# 复制/发布到 GitHub

当前仓库已发布在：

<https://github.com/2073493463-crypto/dsh-splash-animation-setup>

本文保留给 fork、迁移或把同样内容发布到自己账号的场景。
`LICENSE`、`README.md`、`docs/`、`scripts/`、`examples/` 都已就位。

发布需要一个 GitHub 账号。以下三种方式任选一种。

## 方式一：网页上传（不需要 Git）

1. 打开 <https://github.com/new>；
2. Repository name 填 `dsh-splash-animation-setup`；
3. 选择 **Public**；
4. **不要**勾选 “Add a README file”（本地已有）；
5. 点 **Create repository**；
6. 在新仓库页面点 **Add file → Upload files**；
7. 把本目录下的所有文件和文件夹拖进去；
8. Commit message 填 `docs: add DSH splash animation setup guide`；
9. 点 **Commit changes**。

上传后建议在仓库右上角 **About** 里填：

- Description：`在 DSH Desktop 上安装、配置和排查开屏动画插件的可复现流程`
- Topics：`deepseek`、`deepseek-harness`、`dsh`、`dsh-plugin`、`splash-screen`、`windows`

## 方式二：Git 命令行

先安装 Git（<https://git-scm.com/download/win>），然后在仓库目录执行：

```bash
git init
git add .
git commit -m "docs: add DSH splash animation setup guide"
git branch -M main
git remote add origin https://github.com/<你的用户名>/dsh-splash-animation-setup.git
git push -u origin main
```

把 `<你的用户名>` 换成实际账号。第一次 push 时 Git 会要求登录，
推荐使用 GitHub 的 Personal Access Token 或 Git Credential Manager。

## 方式三：GitHub CLI

安装 GitHub CLI（<https://cli.github.com/>）并登录：

```bash
gh auth login
```

然后在仓库目录执行：

```bash
git init
git add .
git commit -m "docs: add DSH splash animation setup guide"
gh repo create dsh-splash-animation-setup --public --source=. --push
```

`gh` 会自动创建远程仓库、设置 `origin` 并推送。

## 发布前检查

- [ ] `README.md` 中的链接可用；
- [ ] 没有把个人路径、用户名、视频文件、日志或凭据提交进去；
- [ ] `LICENSE` 是 MIT；
- [ ] `NOTICE.md` 保留了对上游插件和素材的说明；
- [ ] 示例配置中没有真实的本机路径；
- [ ] 如果改了安装步骤，`docs/COMPATIBILITY.zh-CN.md` 的版本表也同步更新。

## 建议的仓库设置

- **Issues**：开启；
- **Discussions**：可选；
- **Wiki**：不需要，文档放 `docs/`；
- **Topics**：见上；
- **License**：MIT；
- ** description**：一句话说明这是安装指南，不是插件本体。

## 不建议提交的内容

- `node_modules/`
- 个人 `config.json`（含本机视频路径）
- DSH 日志、截图中的个人信息
- 插件自带或用户自己的视频文件
- GitHub Token、Cookie、`.env`

`.gitignore` 已经覆盖常见临时文件。
