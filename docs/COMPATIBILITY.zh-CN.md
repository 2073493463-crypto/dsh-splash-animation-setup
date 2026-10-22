# 兼容性检查

本文记录本指南在 **2026-10** 的实测环境，以及为什么判断
`dsh-splash-animation@0.4.5` 可以运行在 **DSH Desktop 0.2.1-rc.2** 上。

> 这不是对未来版本的保证。DSH 仍在快速迭代，插件 API、profile 格式和
> 客户端模块加载方式都可能变化。升级 DSH 后请重新做一遍本文的检查。

## 实测环境

| 项目 | 值 | 检查方法 |
|---|---|---|
| DSH Desktop | `0.2.1-rc.2` | `dsh --version`（桌面版自带 CLI） |
| Electron | `44.7.0` | `resources\app.asar\package.json` 或进程信息 |
| 内置 Node | `24.21.0` | `resources\runtime\primary-runtime\dependencies\node\bin\node.exe -v` |
| 内置 pnpm | `11.28.5` | `resources\runtime\versions.json` |
| 插件 | `dsh-splash-animation@0.4.5` | 插件 `package.json` |
| Profile | `desktop` | `DSH_PROFILE` / 实际 profile 目录 |

检查 DSH 版本：

```powershell
$DshExe = Join-Path $env:LOCALAPPDATA "Programs\DeepSeek Harness\DeepSeek Harness.exe"
$DshCli = Join-Path (Split-Path $DshExe) "resources\app.asar\dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"
$env:ELECTRON_RUN_AS_NODE = "1"
& $DshExe --expose-internals $DshCli --version
```

检查 Node：

```powershell
$Node = Join-Path (Split-Path $DshExe) "resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
& $Node -v
```

检查插件：

```powershell
$ProfileDir = Join-Path $env:USERPROFILE ".dsh\profiles\desktop"
Get-Content (Join-Path $ProfileDir "node_modules\dsh-splash-animation\package.json") -Raw
```

## 插件声明的要求

`dsh-splash-animation@0.4.5` 的 `package.json` 只声明了：

```json
"engines": {
  "node": ">=20"
}
```

它没有 `peerDependencies`，也没有要求某个具体的 DSH 版本。
内置 Node 24.21.0 满足 `>=20`。

此外它声明了：

```json
"dsh": {
  "bundle": {
    "patch": "./cordis.patch.yml"
  },
  "client": {
    "platform": "web",
    "immediately": true,
    "inject": []
  }
}
```

这表示：

- 它是标准的 DSH bundle，可以通过 profile 的 `dsh.profile.bundles` 加载；
- 它有一个 Web 客户端半，需要 `client.js` 能在客户端模块加载器里注册；
- `immediately: true` 让客户端半尽早加载，用于在首帧盖住应用；
- 它不依赖额外客户端包。

## 插件使用的宿主 API

在 `0.2.1-rc.2` 的安装包中可以找到这些能力：

| 插件用法 | 宿主侧 | 是否存在 |
|---|---|---|
| `ctx.on('webserver/index-inject', ...)` | `@deepseek-ai/dsh-host-webserver` | 是 |
| `ctx.inject(['webServer'], ...)` | 同上 | 是 |
| `webServer.register({ kind, path, handler })` | 同上 | 是 |
| `connection.requestRejection(req)` | `@deepseek-ai/dsh-client-connection` | 是 |
| `settings.plugins.tab` 插槽 | `@deepseek-ai/dsh-client-ui-settings-plugins` | 是 |
| `shell.overlay` 插槽 | Web 客户端 shell | 是 |

因此插件的 Host 路由、设置页注册和全屏覆盖层都有对应的宿主能力。

## 插件自带校验

在安装目录运行插件自带的检查：

```powershell
Push-Location (Join-Path $ProfileDir "node_modules\dsh-splash-animation")
node tools/verify-contract.mjs
node tools/verify-host.mjs
node tools/verify-package-contents.mjs
Pop-Location
```

本次实测结果：

```text
verify-contract: PASS — 96/96 assertions
verify-host:     PASS — 51/51 assertions
verify-package:  PASS — every runtime and listing file is published
```

这些检查验证的是插件自身的契约和打包内容，不等于 DSH 的完整启动测试，
但能排除“缺少入口、缺资源、配置归一化错误”等常见问题。

## 配置组合检查

DSH 桌面版拒绝直接对正在使用的 `desktop` profile 执行 `--dump-config`：

```text
error: profile "desktop" is managed exclusively by the Electron application
```

可以在临时 profile 名字下复制配置，验证 YAML 和 bundle 组合：

```powershell
$TestHome = Join-Path $env:TEMP "dsh-splash-compat"
$TestProfile = Join-Path $TestHome "profiles\desktop-test"
New-Item -ItemType Directory -Force $TestProfile | Out-Null

Copy-Item (Join-Path $ProfileDir "package.json") $TestProfile
Copy-Item (Join-Path $ProfileDir "cordis.patch.yml") $TestProfile
Copy-Item (Join-Path $ProfileDir "cordis.yml") $TestProfile -ErrorAction SilentlyContinue
Copy-Item (Join-Path $ProfileDir "pnpm-workspace.yaml") $TestProfile -ErrorAction SilentlyContinue

# 避免复制整个 node_modules
New-Item -ItemType Junction -Path (Join-Path $TestProfile "node_modules") `
  -Target (Join-Path $ProfileDir "node_modules") | Out-Null

$env:DSH_HOME = $TestHome
& $DshExe --expose-internals $DshCli --profile desktop-test --dump-config |
  Select-String -Pattern "dsh-splash-animation" -Context 0,12
```

应看到：

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

检查完删除临时目录即可。

## 已知限制

- **不是官方插件**：插件由社区维护；DSH 升级后可能失效。
- **Git 依赖**：`github:` spec 需要本机 `git`；没有 Git 时用 tarball。
- **声音**：Chromium 可能在页面交互前拦截带声自动播放；插件会自动静音重试。
- **视频编码**：MP4 推荐 H.264 + AAC；HEVC/ProRes/DNxHD 等可能无法解码。
- **首次启动黑屏**：插件有约 10 秒兜底；如果一直黑屏，通常是客户端半没有加载。
- **多插件覆盖层**：其他使用 `shell.overlay` 的插件可能和开屏层竞争，优先检查层级和点击捕获。

## 升级 DSH 后

1. 先记录当前 DSH 版本和插件版本；
2. 重新运行 `dsh plugin --profile desktop list`；
3. 看插件 `package.json` 的 `engines` / `peerDependencies`；
4. 启动一次，确认开屏、设置页、跳过按钮都正常；
5. 如果失败，先在设置里清除视频，再禁用插件，避免影响正常启动。
