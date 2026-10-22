# DSH Desktop 开屏动画安装指南

[![release](https://img.shields.io/github/v/release/2073493463-crypto/dsh-splash-animation-setup)](https://github.com/2073493463-crypto/dsh-splash-animation-setup/releases)
[![license](https://img.shields.io/github/license/2073493463-crypto/dsh-splash-animation-setup)](LICENSE)

在 **DeepSeek Harness 桌面版（Windows）** 中安装、配置和排查社区插件
[`dsh-splash-animation`](https://github.com/KDDKBD/DeepSeek-splash-animation) 的可复现流程。

> 非官方文档。插件版权归 [KDDKBD](https://github.com/KDDKBD) 所有；本仓库只记录安装与配置方法，
> 不包含插件代码、插件素材或任何视频文件。

## 这是什么

`dsh-splash-animation` 会在 DSH 启动时播放一段视频，播完后渐隐进入主界面。
它不是 DSH 内置功能，而是通过插件的 `dsh.bundle.patch` 挂载到当前 profile 上。

本仓库解决三个问题：

1. **装到正确的 profile**：DSH 桌面版实际使用的是 `desktop` profile，不是 README 里常见的 `web`。
2. **没有 Git 也能装**：`github:` 简写依赖本机 `git`；没有 Git 时改用同一仓库的 GitHub tarball。
3. **配置和排查有据可查**：包含实测版本、配置项、重启方式、常见报错和回滚方法。

### 它怎么工作

1. `dsh plugin` 把插件包安装到当前 profile 的 `node_modules`；
2. 插件声明 `dsh.bundle.patch`，安装器把它追加到 `dsh.profile.bundles`；
3. DSH 启动时加载 bundle，Host 半在 `webserver/index-inject` 里注入启动样式和脚本；
4. 浏览器半在 `shell.overlay` 挂一层全屏视频，Host 通过带 Range 的本地路由流式提供视频；
5. 视频结束或用户跳过后，覆盖层渐隐并销毁，露出正常界面。

整个过程不修改 `app.asar`，所以 DSH 自动更新不会把它覆盖掉；卸载插件或清除配置即可恢复原状。

## 快速开始

也可以直接从 [Releases](https://github.com/2073493463-crypto/dsh-splash-animation-setup/releases) 下载 ZIP。

在 **普通 PowerShell** 中运行（不要通过 DSH 的沙箱终端运行）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-DshSplash.ps1 `
  -VideoPath "D:\Videos\opening.mp4"
```

如果使用 PowerShell 7，把 `powershell` 换成 `pwsh` 即可。

脚本会：

- 找到 DSH Desktop 自带的 CLI 和实际使用的 `desktop` profile；
- 备份 `package.json`、`cordis.patch.yml`、`pnpm-lock.yaml`、`pnpm-workspace.yaml`；
- 通过 DSH 自带的 `dsh plugin` 安装插件，并把它加入 `dsh.profile.bundles`；
- 写入开屏配置；
- 如果你传了 `-VideoPath`，同时写入视频路径；
- 提示你完全退出并重新打开 DSH。

不想用脚本，或者想理解每一步，请看
[docs/INSTALL.zh-CN.md](docs/INSTALL.zh-CN.md)。

### 脚本参数

| 参数 | 说明 |
|---|---|
| `-VideoPath` | 视频路径；不传则只写配置，之后在设置页选择 |
| `-DryRun` | 只打印计划，不修改任何文件 |
| `-DshExe` | DSH 安装路径，默认从 `%LOCALAPPDATA%\Programs` 查找 |
| `-DshHome` | DSH home，默认 `%USERPROFILE%\.dsh` |
| `-Profile` | profile 名，默认 `desktop` |
| `-ProfileDir` | 直接指定 profile 目录 |
| `-Spec` | 自定义安装 spec |
| `-UseGitSpec` | 强制使用 `github:` 简写 |
| `-SkipInstall` | 跳过安装，只写配置/视频 |
| `-SkipConfig` | 跳过 `cordis.patch.yml` 修改 |

> 插件 Host 代码会在 DSH 进程内执行。安装前请确认来源可信；本仓库不审计插件代码。

## 已验证环境

| 项目 | 版本 |
|---|---|
| 操作系统 | Windows 10/11 x64 |
| DSH Desktop | `0.2.1-rc.2` |
| Electron | `44.7.0` |
| 内置 Node | `24.21.0` |
| 插件 | `dsh-splash-animation@0.4.5` |
| 实测日期 | 2026-10 |

插件声明 `engines.node >= 20`，没有额外的 DSH peer 依赖；它使用的
`webserver/index-inject`、`webServer.register`、`settings.plugins.tab` 和
`shell.overlay` 在实测版本中均存在。更完整的检查过程见
[docs/COMPATIBILITY.zh-CN.md](docs/COMPATIBILITY.zh-CN.md)。

## 安装后的效果

本指南默认写入以下配置：

| 字段 | 值 | 含义 |
|---|---|---|
| `fit` | `contain` | 完整显示视频，保留画面边缘，可能留黑边 |
| `playbackRate` | `1` | 原速播放 |
| `duration` | `0` | 播放到视频结束，不按固定时长截断 |
| `fadeOutMs` | `600` | 播完后 600ms 渐隐进入主界面 |
| `skip` | `button` | 右下角显示“跳过”按钮 |
| `muted` | `false` | 先尝试带声音播放 |
| `volume` | `0.6` | 音量 60% |

`src` 由你选择的视频决定。如果暂时不选，脚本会写入空字符串 `src: ""`，
这样插件不会播放自带的示例视频。

## 设置视频

安装并重启一次后，打开：

**设置 → 插件 → 开屏动画 → 选择文件…**

选中视频，点 **保存**。保存后会写入：

```text
%USERPROFILE%\.dsh\dsh-splash-animation\config.json
```

设置页显示“下次启动播放”后，完全退出 DSH 再打开即可看到效果。

> 注意：左侧栏的“插件”是插件管理页；视频设置入口在“设置 → 插件”下的“开屏动画”标签页。

## 重启方法

**只关闭主窗口可能只是隐藏到系统托盘，不会重启 Host。**

1. 右键系统托盘里的 DeepSeek Harness 图标；
2. 选择 **退出**；
3. 等托盘图标消失；
4. 从开始菜单或桌面快捷方式重新打开。

插件的 Host 半在 DSH 启动时加载，所以安装或升级插件后必须完整重启；
只刷新页面不够。

## 常见问题

| 现象 | 先检查 |
|---|---|
| `git: not found` / `spawn git ENOENT` | 本机没有 Git；改用 tarball 安装，见安装文档 |
| `profile "desktop" is managed exclusively` | 不要用 npm 全局安装的 `dsh`；用桌面版自带的 CLI |
| `EPERM ... package.json.lock` | 不要在 DSH 沙箱内执行；换普通 PowerShell，避免并发安装 |
| 重启后没有动画 | `src` 是否为空、视频是否还存在、插件是否在 `bundles` 中 |
| 设置页没有“开屏动画” | 插件 Host 没加载；检查 profile 和重启方式 |
| 有画面没声音 | Chromium 自动播放策略；插件会自动静音重试 |
| 一直黑屏约 10 秒 | 插件客户端没加载；看 DSH 日志并重装 |
| 视频黑屏但能跳过 | 编码不被支持；优先 H.264/AAC 的 MP4，或 VP9 的 WebM |

完整排查见 [docs/TROUBLESHOOTING.zh-CN.md](docs/TROUBLESHOOTING.zh-CN.md)。

## 卸载与回滚

优先级从高到低：

1. **设置 → 插件 → 开屏动画 → 清除**：只关闭开屏，不卸载插件。
2. **设置 → 插件**：禁用或移除插件。
3. 恢复安装前的备份文件（脚本会在临时目录打印备份路径）。
4. 手动从 profile 的 `package.json` 和 `cordis.patch.yml` 中移除插件。

不要只删除 `node_modules`：profile 的 `dsh.profile.bundles` 还引用它时，
DSH 启动会报模块缺失。

## 仓库结构

```text
.
├─ README.md
├─ docs/
│  ├─ INSTALL.zh-CN.md          # 从零安装，含 Git / 无 Git 两条路径
│  ├─ COMPATIBILITY.zh-CN.md    # 版本检查与 API 依据
│  ├─ TROUBLESHOOTING.zh-CN.md  # 常见报错与回滚
│  └─ PUBLISH.zh-CN.md          # 发布到 GitHub 的方法
├─ examples/
│  ├─ cordis.patch.example.yml
│  └─ config.example.json
├─ scripts/
│  └─ Install-DshSplash.ps1
├─ NOTICE.md
├─ CONTRIBUTING.md
└─ LICENSE
```

## 许可

本仓库的文档和脚本以 MIT 许可发布。插件本身也是 MIT，但其自带的
`assets/default.mp4` 属于示例素材，不在插件代码许可范围内；本仓库不再分发该素材。
详见 [NOTICE.md](NOTICE.md)。

DeepSeek、DeepSeek Harness 是其权利人的商标。本仓库与 DeepSeek 官方无隶属关系。
