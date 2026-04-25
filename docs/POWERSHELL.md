# PowerShell UTF-8 与中文输出

本页合并旧的 PowerShell 中文支持和 UTF-8 配置说明。目标是让构建脚本、中文日志和路径输出在 Windows PowerShell / PowerShell 7 中保持一致。

## 临时配置

只影响当前 PowerShell 会话：

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
```

## 用户级配置

编辑当前用户的 PowerShell profile：

```powershell
notepad $PROFILE
```

如果 profile 不存在：

```powershell
$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}
```

追加：

```powershell
if ($Host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
```

保存后重新打开 PowerShell。

## 项目脚本

如果本地仍保留这些脚本，可以直接运行：

```powershell
.\setup-powershell-utf8.ps1
.\setup-powershell-chinese-global.ps1
```

或运行对应批处理入口：

```batch
安装PowerShell中文支持.bat
安装PowerShell中文支持-全局.bat
```

## 验证

```powershell
Write-Host "测试中文显示: 你好，世界！" -ForegroundColor Cyan
[Console]::OutputEncoding
[Console]::InputEncoding
$OutputEncoding
chcp
```

预期代码页为 `65001`，输入/输出编码为 UTF-8。

## 常见问题

### 执行策略阻止 profile

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 中文仍然乱码

1. 确认已重启 PowerShell。
2. 确认 `$PROFILE` 中的配置存在。
3. 确认当前终端字体支持中文。
4. 临时执行本页“临时配置”中的命令，判断是否是 profile 未加载。
