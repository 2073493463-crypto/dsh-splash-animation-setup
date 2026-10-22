# Contributing

欢迎提交 Issue 或 Pull Request，尤其是：

- 新的 DSH Desktop 版本实测结果；
- 新的 Windows 环境兼容性信息；
- 更准确的报错排查步骤；
- 安装脚本的健壮性改进。

## 提交前

1. 不要提交个人路径、用户名、Cookie、Token、日志或视频文件；
2. 如果改了默认配置，同步更新：
   - `README.md`
   - `docs/INSTALL.zh-CN.md`
   - `examples/cordis.patch.example.yml`
3. 如果更新了兼容性结论，在 `docs/COMPATIBILITY.zh-CN.md` 里写清：
   - DSH Desktop 版本
   - Electron / Node 版本
   - 插件版本
   - 实测日期
   - 哪些检查通过、哪些没测

## 测试安装脚本

在普通 PowerShell 中先跑 DryRun：

```powershell
pwsh -NoProfile -File .\scripts\Install-DshSplash.ps1 -DryRun -VideoPath "D:\Videos\opening.mp4"
```

DryRun 不应修改 profile。确认真实安装前先备份 profile。

## 许可

提交即表示你同意以本仓库的 MIT 许可发布你的贡献。
