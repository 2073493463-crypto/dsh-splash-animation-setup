# 常见问题与排查

## 先做这三件事

1. **确认重启方式**：不是只刷新页面，也不是只关窗口。
   右键系统托盘里的 DeepSeek Harness 图标 → **退出**，等图标消失，再重开。
2. **确认 profile**：桌面版实际使用的是
   `%USERPROFILE%\.dsh\profiles\desktop`，不是 `%APPDATA%\...\profiles\web`。
3. **确认插件在 bundle 列表里**：

   ```powershell
   $ProfileDir = Join-Path $env:USERPROFILE ".dsh\profiles\desktop"
   Get-Content (Join-Path $ProfileDir "package.json") -Raw
   ```

   `dsh.profile.bundles` 应包含 `dsh-splash-animation`。

## 重启后完全没有动画

按可能性从高到低检查：

### 1. `src` 是空的

这是本指南的默认状态，目的是不先播放插件自带的示例视频。

打开 **设置 → 插件 → 开屏动画**，确认：

- 有“选择文件…”按钮；
- 选择视频后显示“下次启动播放”；
- 保存成功。

状态文件：

```text
%USERPROFILE%\.dsh\dsh-splash-animation\config.json
```

内容应包含非空的 `src`。

### 2. 视频路径失效

如果视频被移动、重命名或删除，插件**不会回退到默认视频**，而是直接不播放。
这是插件的设计：宁可什么都不播，也不播一个你没选的视频。

重新在设置页选择即可。

### 3. 插件没有加载

```powershell
$ProfileDir = Join-Path $env:USERPROFILE ".dsh\profiles\desktop"
Test-Path (Join-Path $ProfileDir "node_modules\dsh-splash-animation\index.js")
Test-Path (Join-Path $ProfileDir "node_modules\dsh-splash-animation\client.js")
```

再看 `cordis.patch.yml` 是否包含：

```yaml
- id: dsh-splash-animation
  name: dsh-splash-animation
```

### 4. 重启的不是同一个 profile

如果你用命令行或其他 profile 启动 DSH，插件不会出现。
桌面版快捷方式默认使用 `desktop` profile。

## 设置页没有“开屏动画”

说明插件客户端半没有加载，或者你打开的不是设置页。

- 左侧栏的 **插件** 是插件管理页；
- 视频设置入口在 **设置 → 插件 → 开屏动画**。

如果设置页完全没有这个标签：

1. 确认 `dsh.profile.bundles` 中有插件；
2. 确认完整退出并重开；
3. 检查 DSH 启动日志中是否有 `dsh-splash-animation` 的加载错误；
4. 重新安装一次。

## `git: not found` / `spawn git ENOENT`

`github:KDDKBD/DeepSeek-splash-animation` 这种简写需要本机有 Git。
没有 Git 时改用 tarball：

```powershell
$Spec = "https://codeload.github.com/KDDKBD/DeepSeek-splash-animation/tar.gz/refs/heads/main"
& $DshExe --expose-internals $DshCli plugin --profile desktop add $Spec
```

这不是插件的问题，是 pnpm 解析 `github:` 时需要 Git 客户端。

## `profile "desktop" is managed exclusively by the Electron application`

不要用 npm 全局安装的 `dsh` 去管理桌面版 profile。
使用桌面安装目录中的 CLI：

```powershell
$DshExe = Join-Path $env:LOCALAPPDATA "Programs\DeepSeek Harness\DeepSeek Harness.exe"
$DshCli = Join-Path (Split-Path $DshExe) "resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"
$env:ELECTRON_RUN_AS_NODE = "1"
& $DshExe --expose-internals $DshCli plugin --profile desktop list
```

## `EPERM ... package.json.lock`

常见原因：

- 在 DSH 的沙箱终端里执行，沙箱不允许写 profile；
- 另一个 pnpm/插件安装进程正在写同一个 profile；
- 安全软件锁住了文件。

处理：

1. 换到普通 PowerShell（不要在 DSH 对话的终端里）；
2. 关闭其他正在安装插件的窗口；
3. 等几秒再重试；
4. 仍然失败时，完全退出 DSH 后重试。

## `Cannot find module 'dsh-splash-animation'`

通常发生在手动删除 `node_modules` 或只改了一半配置时：

- `package.json` 的 `dsh.profile.bundles` 还引用插件；
- 但 `node_modules/dsh-splash-animation` 已经不存在。

修复：

```powershell
& $DshExe --expose-internals $DshCli plugin --profile desktop install
```

或者从 `dsh.profile.bundles` 中删除 `dsh-splash-animation` 后重启。

## 一直黑屏十几秒

插件有一层启动遮盖，客户端半没加载时由约 10 秒的兜底释放。
如果每次都黑屏十几秒才进界面：

1. 检查 `client.js` 是否存在；
2. 检查插件是否被禁用；
3. 重新安装：

   ```powershell
   & $DshExe --expose-internals $DshCli plugin --profile desktop add `
     "https://codeload.github.com/KDDKBD/DeepSeek-splash-animation/tar.gz/refs/heads/main"
   ```

4. 如果仍然黑屏，先在设置里清除视频，再禁用插件。

## 有画面没声音

这是 Chromium 的自动播放策略，不是 `volume` 配置错误。

- 插件会先尝试带声播放；
- 如果被拦截，会自动静音重试，保证画面正常；
- 页面产生过用户交互后，下一次启动可能允许带声。

如果你必须保证有声音，可以考虑：

- 在开屏期间点击一次页面（但会触发跳过/交互，取决于 `skip` 设置）；
- 或改用 `skip: never` 并配合系统层面的音频策略（不推荐，可能影响可退出性）。

## 视频是黑屏，但能跳过

大概率是编码不支持。优先使用：

- MP4 / H.264 + AAC；
- WebM / VP9 + Opus。

不要使用：

- HEVC/H.265（部分 Windows 环境没有解码器）；
- ProRes、DNxHD、某些 MKV 内的编码；
- 带 DRM 的文件。

转码示例（需要 ffmpeg）：

```bash
ffmpeg -i input.mov -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 160k opening.mp4
```

## “选择文件…”没有反应

- 如果你是在另一台机器的浏览器里访问 DSH，文件对话框会在**运行 DSH 的那台机器**上弹出；
- 如果对话框不可用，可以直接在路径输入框里粘贴绝对路径；
- 路径包含中文通常没问题，插件用 UTF-8 文件传递选择结果。

## 跳过按钮点不到

- 确认 `skip` 是 `button`；
- 插件在开屏期间捕获输入，正常不会被其他插件抢走；
- 如果同屏还有别的全屏悬浮插件，先禁用那个插件再试。

## 如何彻底回滚

1. **设置 → 插件 → 开屏动画 → 清除**：停止播放，但保留插件；
2. **设置 → 插件**：禁用或移除插件；
3. 恢复安装前的备份（`package.json`、`cordis.patch.yml`、`pnpm-lock.yaml`）；
4. 确认 `package.json` 的 `dsh.profile.bundles` 不再包含 `dsh-splash-animation`。

只删除 `node_modules` 而不改 `bundles`，会导致下次启动找不到模块。
