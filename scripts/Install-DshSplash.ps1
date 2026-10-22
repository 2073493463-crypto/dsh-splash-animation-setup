#Requires -Version 5.1
<#
.SYNOPSIS
    在 Windows 的 DeepSeek Harness 桌面版中安装并配置 dsh-splash-animation。

.DESCRIPTION
    默认安装到当前桌面版实际使用的 desktop profile，写入 fit=contain、
    playbackRate=1、duration=0、fadeOutMs=600、skip=button、muted=false、
    volume=0.6。可通过 -VideoPath 同时指定视频。

    本机没有 git 时，自动改用 GitHub codeload tarball；有 git 时默认使用
    github: 简写，失败会回退到 tarball。

.EXAMPLE
    pwsh -NoProfile -File .\Install-DshSplash.ps1 -VideoPath "D:\Videos\opening.mp4"

.EXAMPLE
    pwsh -NoProfile -File .\Install-DshSplash.ps1 -DryRun

.NOTES
    需要普通 PowerShell，不要在 DSH 的沙箱终端里运行。
#>
[CmdletBinding()]
param(
    [string]$VideoPath,
    [string]$Profile = "desktop",
    [string]$DshExe,
    [string]$DshHome,
    [string]$ProfileDir,
    [string]$Spec,
    [switch]$UseGitSpec,
    [switch]$DryRun,
    [switch]$SkipInstall,
    [switch]$SkipConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:Tarball = "https://codeload.github.com/KDDKBD/DeepSeek-splash-animation/tar.gz/refs/heads/main"
$script:GitSpec = "github:KDDKBD/DeepSeek-splash-animation"
$script:SupportedExtensions = @(
    ".mp4", ".m4v", ".webm", ".mov", ".mkv", ".ogv", ".ogm", ".mpg", ".mpeg", ".ts",
    ".gif", ".apng", ".webp", ".avif", ".png", ".jpg", ".jpeg", ".svg", ".bmp", ".ico"
)

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Gray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Resolve-DshExecutable {
    param([string]$Given)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($Given) { $candidates.Add($Given) }
    if ($env:DSH_DESKTOP_EXE) { $candidates.Add($env:DSH_DESKTOP_EXE) }

    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA "Programs\DeepSeek Harness\DeepSeek Harness.exe"))
    }
    if ($env:ProgramFiles) {
        $candidates.Add((Join-Path $env:ProgramFiles "DeepSeek Harness\DeepSeek Harness.exe"))
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} "DeepSeek Harness\DeepSeek Harness.exe"))
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    # 最后在常见安装根目录做一次浅层搜索。
    foreach ($root in @((Join-Path $env:LOCALAPPDATA "Programs"), $env:ProgramFiles)) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Filter "DeepSeek Harness.exe" -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    throw "找不到 DeepSeek Harness.exe。请用 -DshExe 指定安装路径。"
}

function Get-DefaultDshHome {
    if ($env:DSH_HOME) { return $env:DSH_HOME }
    return (Join-Path $env:USERPROFILE ".dsh")
}

function Get-ProfileDirectory {
    param(
        [string]$ExplicitDir,
        [string]$HomePath,
        [string]$Name
    )

    if ($ExplicitDir) { return $ExplicitDir }
    if ($env:DSH_PROFILE_DIR -and $env:DSH_PROFILE -eq $Name) { return $env:DSH_PROFILE_DIR }
    return (Join-Path (Join-Path $HomePath "profiles") $Name)
}

function Invoke-DshCli {
    param(
        [string]$Executable,
        [string]$CliPath,
        [string[]]$Arguments,
        [string]$DshHomePath
    )

    $previousRunAsNode = $env:ELECTRON_RUN_AS_NODE
    $previousDshHome = $env:DSH_HOME
    $env:ELECTRON_RUN_AS_NODE = "1"
    if ($DshHomePath) { $env:DSH_HOME = $DshHomePath }
    try {
        & $Executable --expose-internals $CliPath @Arguments
        $nativeExit = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
        if ($null -eq $nativeExit) { return 1 }
        return [int]$nativeExit
    }
    finally {
        if ($null -eq $previousRunAsNode) {
            Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
        }
        else {
            $env:ELECTRON_RUN_AS_NODE = $previousRunAsNode
        }
        if ($null -eq $previousDshHome) {
            Remove-Item Env:DSH_HOME -ErrorAction SilentlyContinue
        }
        else {
            $env:DSH_HOME = $previousDshHome
        }
    }
}

function Backup-ProfileFiles {
    param([string]$Directory)

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path $env:TEMP "dsh-splash-backup-$stamp"
    New-Item -ItemType Directory -Force -Path $backup | Out-Null

    foreach ($name in @("package.json", "cordis.patch.yml", "pnpm-lock.yaml", "pnpm-workspace.yaml")) {
        $source = Join-Path $Directory $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
    }

    return $backup
}

function Get-SplashConfigBlock {
    @"
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
"@
}

function Add-SplashConfigRow {
    param(
        [string]$PatchFile,
        [string]$Block
    )

    if (-not (Test-Path -LiteralPath $PatchFile)) {
        [System.IO.File]::WriteAllText($PatchFile, $Block, $script:Utf8NoBom)
        return "created"
    }

    $text = [System.IO.File]::ReadAllText($PatchFile)
    if ($text -match "(?m)^-\s*id:\s*dsh-splash-animation\s*$") {
        return "exists"
    }

    # 空 profile 的 cordis.patch.yml 可能是一个空数组 []；直接追加列表项会变成
    # "[]\n- id: ..."，不是合法 YAML。先去掉只占一行的 []。
    $text = [regex]::Replace($text, "(?m)^[ \t]*\[[ \t]*\][ \t]*\r?\n?", "")

    if ([string]::IsNullOrWhiteSpace($text)) {
        [System.IO.File]::WriteAllText($PatchFile, $Block, $script:Utf8NoBom)
        return "created"
    }

    if (-not $text.EndsWith("`n")) {
        $text += "`r`n"
    }

    $text += $Block
    [System.IO.File]::WriteAllText($PatchFile, $text, $script:Utf8NoBom)
    return "appended"
}

function Set-VideoState {
    param(
        [string]$HomePath,
        [string]$Path
    )

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $item = Get-Item -LiteralPath $resolved
    if ($item.PSIsContainer) {
        throw "视频路径不是文件：$resolved"
    }
    if ($item.Length -le 0) {
        throw "视频文件为空：$resolved"
    }
    if ($item.Length -gt (4GB)) {
        throw "视频超过 4GB，插件不会提供该文件：$resolved"
    }

    $extension = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
    if ($script:SupportedExtensions -notcontains $extension) {
        throw "插件不支持该扩展名：$extension"
    }

    $stateDir = Join-Path $HomePath "dsh-splash-animation"
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    $stateFile = Join-Path $stateDir "config.json"

    $state = @{}
    if (Test-Path -LiteralPath $stateFile) {
        try {
            $existing = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            foreach ($property in $existing.PSObject.Properties) {
                $state[$property.Name] = $property.Value
            }
        }
        catch {
            Write-Warn "现有 config.json 无法解析，将覆盖：$stateFile"
        }
    }

    $state["src"] = $resolved
    $json = $state | ConvertTo-Json
    [System.IO.File]::WriteAllText($stateFile, $json + [Environment]::NewLine, $script:Utf8NoBom)
    return $resolved
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

Write-Host "DSH Desktop 开屏动画安装脚本" -ForegroundColor White
Write-Host "插件：dsh-splash-animation" -ForegroundColor DarkGray

try {
    $DshExePath = Resolve-DshExecutable -Given $DshExe
    $DshRoot = Split-Path -Parent $DshExePath
    $AsarPath = Join-Path $DshRoot "resources\app.asar"
    $CliPath = Join-Path $AsarPath "dsh\node_modules\@deepseek-ai\dsh-desktop-host\lib\cli.js"

    # app.asar 是归档文件，PowerShell 的 Test-Path 看不到其中的 cli.js；
    # 只检查归档存在，具体路径交给 Electron 的 asar 文件系统解析。
    if (-not (Test-Path -LiteralPath $AsarPath)) {
        Fail "找不到 app.asar：$AsarPath"
    }

    if (-not $DshHome) { $DshHome = Get-DefaultDshHome }
    $ProfileDir = Get-ProfileDirectory -ExplicitDir $ProfileDir -HomePath $DshHome -Name $Profile
    $ManifestPath = Join-Path $ProfileDir "package.json"
    $PatchPath = Join-Path $ProfileDir "cordis.patch.yml"

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        Fail "profile 尚未初始化：$ManifestPath（先打开一次 DSH Desktop）"
    }

    Write-Step "环境"
    Write-Info "DSH：$DshExePath"
    Write-Info "CLI：$CliPath"
    Write-Info "Profile：$ProfileDir"

    $running = Get-Process -Name "DeepSeek Harness" -ErrorAction SilentlyContinue
    if ($running) {
        Write-Warn "DSH 正在运行。安装可以完成，但必须完全退出并重开才会加载插件。"
    }

    $specToUse = $null
    $fallbackSpec = $null
    $git = $null
    if ($Spec) {
        $specToUse = $Spec
    }
    elseif ($UseGitSpec) {
        $specToUse = $script:GitSpec
    }
    else {
        $git = Get-Command git -ErrorAction SilentlyContinue
        if ($git) {
            $specToUse = $script:GitSpec
            $fallbackSpec = $script:Tarball
        }
        else {
            $specToUse = $script:Tarball
        }
    }

    Write-Step "安装插件"
    Write-Info "Spec：$specToUse"
    if (-not $git -and -not $Spec -and -not $UseGitSpec) {
        Write-Info "未检测到 git，使用 GitHub tarball。"
    }

    $backupDir = $null
    if ($DryRun) {
        Write-Info "[DryRun] 会备份 profile 文件到临时目录"
        Write-Info "[DryRun] 会执行：dsh plugin --profile $Profile add $specToUse"
    }
    elseif (-not $SkipInstall) {
        $backupDir = Backup-ProfileFiles -Directory $ProfileDir
        Write-Info "备份：$backupDir"

        $exitCode = Invoke-DshCli -Executable $DshExePath -CliPath $CliPath `
            -Arguments @("plugin", "--profile", $Profile, "add", $specToUse) `
            -DshHomePath $DshHome

        if ($exitCode -ne 0 -and $fallbackSpec) {
            Write-Warn "github: 安装失败（退出码 $exitCode），改用 tarball 重试。"
            $specToUse = $fallbackSpec
            $exitCode = Invoke-DshCli -Executable $DshExePath -CliPath $CliPath `
                -Arguments @("plugin", "--profile", $Profile, "add", $specToUse) `
                -DshHomePath $DshHome
        }

        if ($exitCode -ne 0) {
            Fail "插件安装失败（退出码 $exitCode）。备份在：$backupDir"
        }

        $pluginManifest = Join-Path $ProfileDir "node_modules\dsh-splash-animation\package.json"
        if (-not (Test-Path -LiteralPath $pluginManifest)) {
            Fail "安装命令返回 0，但没有找到 dsh-splash-animation/package.json"
        }
    }

    if (-not $SkipConfig) {
        Write-Step "写入开屏配置"
        $block = Get-SplashConfigBlock
        if ($DryRun) {
            Write-Info "[DryRun] 将写入 $PatchPath："
            Write-Host $block -ForegroundColor DarkGray
        }
        else {
            $result = Add-SplashConfigRow -PatchFile $PatchPath -Block $block
            switch ($result) {
                "created" { Write-Info "已创建 $PatchPath" }
                "appended" { Write-Info "已追加配置行到 $PatchPath" }
                "exists" { Write-Warn "已存在 dsh-splash-animation 配置，跳过追加；请手动核对 config。" }
            }
        }
    }

    if ($VideoPath) {
        Write-Step "写入视频路径"
        if ($DryRun) {
            Write-Info "[DryRun] 会验证并写入：$VideoPath"
        }
        else {
            $video = Set-VideoState -HomePath $DshHome -Path $VideoPath
            Write-Info "已选择：$video"
        }
    }
    else {
        Write-Step "视频"
        Write-Info "未指定 -VideoPath；首次启动不会播放示例片，请在设置页选择视频。"
    }

    if (-not $DryRun) {
        Write-Step "检查安装结果"
        $exitCode = Invoke-DshCli -Executable $DshExePath -CliPath $CliPath `
            -Arguments @("plugin", "--profile", $Profile, "list") `
            -DshHomePath $DshHome
        if ($exitCode -ne 0) {
            Write-Warn "dsh plugin list 返回退出码 $exitCode，请手动检查 profile。"
        }
    }

    Write-Step "完成"
    Write-Host "下一步：" -ForegroundColor White
    Write-Host "  1. 右键系统托盘中的 DeepSeek Harness 图标 → 退出" -ForegroundColor White
    Write-Host "  2. 等托盘图标消失后，从开始菜单重新打开 DSH" -ForegroundColor White
    if ($VideoPath) {
        Write-Host "  3. 下次启动应直接播放你指定的视频" -ForegroundColor White
    }
    else {
        Write-Host "  3. 打开 设置 → 插件 → 开屏动画，选择视频并保存" -ForegroundColor White
        Write-Host "  4. 再次完全退出并重开，才会播放" -ForegroundColor White
    }
    if ($backupDir) {
        Write-Host ""
        Write-Host "安装前备份：$backupDir" -ForegroundColor DarkGray
    }
}
catch {
    Fail $_.Exception.Message
}
