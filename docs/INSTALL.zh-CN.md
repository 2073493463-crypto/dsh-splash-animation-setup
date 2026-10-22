# 从零安装

本文以 Windows 上的 **DSH Desktop 0.2.1-rc.2** 为例。其他版本请先看
[COMPATIBILITY.zh-CN.md](COMPATIBILITY.zh-CN.md)。

## 0. 准备

你需要：

- 已安装并能正常启动的 DeepSeek Harness 桌面版；
- 一个本地视频（推荐 MP4 / H.264 + AAC，或 WebM / VP9）；
- 普通 PowerShell（不要在 DSH 的沙箱终端里操作 profile）。

先确认 DSH 完全退出：

```powershell
Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue
```

如果还有进程，右键系统托盘图标退出，或从“应用”菜单退出，等进程消失。
安装过程本身可以在 DSH 运行时完成，但**必须重启后才会加载插件**。

## 1. 找到桌面版自带的 CLI

DSH 桌面版不依赖 PATH 里的 `dsh`。使用安装目录中的 CLI：

```powershell
$DshExe = Join-Path $env:LOCALAPPDATA "Programs\DeepSeek Harness\DeepSeek Harness.exe"
$DshRoot = Split-Path $DshExe
$DshCli = Join-Path $DshRoot "resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"

Test-Path $DshExe
Test-Path (Join-Path $DshRoot "resources\app.asar")
```

两行都应为 `True`。`app.asar` 是归档文件，PowerShell 的 `Test-Path`
看不到归档内部的 `cli.js`，所以不要对 `$DshCli` 做 `Test-Path`；
把它原样交给 Electron 就能读取。

如果安装到了其他位置，把 `$DshExe` 换成实际路径。

检查版本：

```powershell
$env:ELECTRON_RUN_AS_NODE = "1"
& $DshExe --expose-internals $DshCli --version
```

输出应类似：

```text
0.2.1-rc.2
```

## 2. 找到实际使用的 profile

DSH 桌面版实际使用的是 `desktop` profile：

```powershell
$DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" }
$ProfileDir = Join-Path $DshHome "profiles\desktop"

Test-Path (Join-Path $ProfileDir "package.json")
```

如果 DSH 已经把 `DSH_PROFILE_DIR` 设进当前环境，也可以直接用它：

```powershell
if ($env:DSH_PROFILE_DIR) { $ProfileDir = $env:DSH_PROFILE_DIR }
```

> 网上不少文章写的是 `%APPDATA%\dsh-desktop\harness\profiles\web`。
> 那是其他版本/其他启动方式的路径。本文以你机器上实际存在的 profile 为准。

查看当前插件：

```powershell
& $DshExe --expose-internals $DshCli plugin --profile desktop list
```

应看到 `dsh-whale-widget`、`dshmarket` 等已有依赖。

## 3. 安装插件

### 3.1 有 Git：使用 `github:` 简写

```powershell
& $DshExe --expose-internals $DshCli plugin --profile desktop add `
  github:KDDKBD/DeepSeek-splash-animation
```

### 3.2 没有 Git：使用 GitHub tarball

`github:` 简写最终需要本机有 `git`。如果 `git --version` 报“找不到命令”，
使用同一个仓库的 codeload tarball：

```powershell
$Spec = "https://codeload.github.com/KDDKBD/DeepSeek-splash-animation/tar.gz/refs/heads/main"
& $DshExe --expose-internals $DshCli plugin --profile desktop add $Spec
```

这两种方式都会由 DSH 的插件管理逻辑完成：

- 把包写入 profile 的 `dependencies`；
- 如果包声明了 `dsh.bundle.patch`，自动追加到 `dsh.profile.bundles`；
- 检查 `engines` / `peerDependencies` 兼容性；
- 运行 pnpm 安装依赖。

安装成功的输出会包含类似：

```text
+ dsh-splash-animation 0.4.5
Done
```

检查结果：

```powershell
Get-Content (Join-Path $ProfileDir "package.json") -Raw
Test-Path (Join-Path $ProfileDir "node_modules\dsh-splash-animation\index.js")
```

`package.json` 中应同时出现：

```json
"dependencies": {
  "dsh-splash-animation": "https://codeload.github.com/KDDKBD/DeepSeek-splash-animation/tar.gz/refs/heads/main"
},
"dsh": {
  "profile": {
    "bundles": [
      "...",
      "dsh-splash-animation"
    ]
  }
}
```

有 Git 时，依赖值会是 `github:KDDKBD/DeepSeek-splash-animation`。

## 4. 写入配置

编辑：

```text
<DSH_HOME>\profiles\desktop\cordis.patch.yml
```

在文件末尾追加：

```yaml
- id: dsh-splash-animation
  name: dsh-splash-animation
  config:
    src: ""
    fit: contain
    playbackRate: 1
    duration: 0
    fadeOutMs: 600
    skip: button
    muted: false
    volume: 0.6
```

说明：

- `src: ""` 表示**先不播放**，避免首次启动播放插件自带的示例视频；
  之后在设置页选视频会写入状态文件，覆盖这个空值。
- 也可以直接把 `src` 写成视频路径，例如：

  ```yaml
  src: 'D:\Videos\opening.mp4'
  ```

  但更推荐在设置页选择，这样路径存在性、格式和错误提示都由插件处理。
- 只在文件末尾追加一次。如果已经有 `- id: dsh-splash-animation`，不要再追加，
  直接修改那一行的 `config`。

改完后可以用 DSH 的配置组合检查（需要先复制一份 profile 到临时名字，
因为桌面版会拒绝直接 `--dump-config` 正在使用的 `desktop`）。
完整步骤见 [COMPATIBILITY.zh-CN.md](COMPATIBILITY.zh-CN.md) 的“配置组合检查”一节。

> 不要用会写入 UTF-8 BOM 的旧编辑器保存 YAML。DSH 能读 BOM，但带 BOM 的
> 文件在部分工具里会出问题。推荐 VS Code、Notepad++ 或 PowerShell 7。

## 5. 设置视频

完全退出并重新打开 DSH 一次，让插件 Host 加载。然后：

1. 打开 **设置**；
2. 进入 **插件**；
3. 打开 **开屏动画** 标签页；
4. 点 **选择文件…**；
5. 选择视频，点 **保存**；
6. 页面显示“下次启动播放”。

保存后的状态文件：

```text
%USERPROFILE%\.dsh\dsh-splash-animation\config.json
```

内容类似：

```json
{
  "src": "D:\\Videos\\opening.mp4"
}
```

## 6. 重启并查看

右键系统托盘里的 DeepSeek Harness 图标 → **退出**，等图标消失，再重新打开。

启动时会播放视频；右下角有“跳过”按钮，`Esc`、空格、回车也可以提前退出。

## 7. 验证

### 7.1 插件是否在 profile 中

```powershell
& $DshExe --expose-internals $DshCli plugin --profile desktop list
```

### 7.2 视频是否能被解析

在 profile 目录运行插件自带的检查（如果安装包包含 `tools/`）：

```powershell
Push-Location (Join-Path $ProfileDir "node_modules\dsh-splash-animation")
node tools/verify-host.mjs
Pop-Location
```

tarball 安装通常会带仓库的 `tools/`；npm 包只带运行文件，没有这些脚本。

### 7.3 页面请求是否正常

DSH 启动后，插件的 Host 路由包括：

```text
GET  /dsh-splash-animation/config.json
POST /dsh-splash-animation/config
POST /dsh-splash-animation/pick
GET  /dsh-splash-animation/asset/<文件名>
```

普通浏览器直接访问会被 DSH 的认证层拒绝并返回 401，这是正常的；
页面内的请求会带上桌面版注入的认证 Cookie。

## 8. 备份与回滚

安装脚本会自动备份以下文件到临时目录：

- `package.json`
- `cordis.patch.yml`
- `pnpm-lock.yaml`
- `pnpm-workspace.yaml`

手动安装时建议先自己复制一份：

```powershell
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = Join-Path $env:TEMP "dsh-splash-backup-$Stamp"
New-Item -ItemType Directory -Force $Backup | Out-Null
Copy-Item (Join-Path $ProfileDir "package.json") $Backup
Copy-Item (Join-Path $ProfileDir "cordis.patch.yml") $Backup
Copy-Item (Join-Path $ProfileDir "pnpm-lock.yaml") $Backup -ErrorAction SilentlyContinue
Copy-Item (Join-Path $ProfileDir "pnpm-workspace.yaml") $Backup -ErrorAction SilentlyContinue
```

回滚顺序：

1. 设置 → 插件 → 开屏动画 → **清除**（只关闭动画）；
2. 设置 → 插件 → 禁用/移除插件；
3. 恢复上面的备份；
4. 如果只删了 `node_modules`，还要从 `package.json` 的
   `dsh.profile.bundles` 中删掉 `dsh-splash-animation`，否则启动会报模块缺失。
