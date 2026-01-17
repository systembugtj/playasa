# PowerShell UTF-8 中文支持配置指南

## 快速配置

### 方法 1: 使用安装脚本（推荐）

运行项目根目录下的安装脚本：

```batch
安装PowerShell中文支持.bat
```

### 方法 2: 手动配置

1. **打开 PowerShell 配置文件**
   ```powershell
   notepad $PROFILE
   ```
   
   如果文件不存在，PowerShell 会提示创建。

2. **添加以下内容到配置文件**
   ```powershell
   # UTF-8 Encoding Support
   if ($Host.Name -eq 'ConsoleHost') {
       chcp 65001 | Out-Null
   }
   
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   [Console]::InputEncoding = [System.Text.Encoding]::UTF8
   $OutputEncoding = [System.Text.Encoding]::UTF8
   $env:PYTHONIOENCODING = "utf-8"
   ```

3. **保存文件并重启 PowerShell**

### 方法 3: 临时设置（仅当前会话）

运行以下命令：

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
```

或者运行项目中的脚本：

```powershell
.\setup-powershell-utf8.ps1
```

## 验证配置

运行以下命令测试中文显示：

```powershell
Write-Host "测试中文显示: 你好，世界！" -ForegroundColor Cyan
```

如果正确显示中文，说明配置成功。

## 配置文件位置

PowerShell 配置文件位置取决于版本：

- **PowerShell 5.x**: `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- **PowerShell 7.x (Core)**: `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

查看配置文件路径：

```powershell
$PROFILE
```

## 常见问题

### 问题 1: 执行策略限制

如果遇到 "无法加载配置文件" 错误，需要修改执行策略：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题 2: 配置文件不存在

如果配置文件不存在，创建它：

```powershell
if (-not (Test-Path $PROFILE)) {
    $dir = Split-Path $PROFILE
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force
    }
    New-Item -Path $PROFILE -ItemType File -Force
}
```

### 问题 3: 某些程序仍显示乱码

某些程序可能使用系统默认编码。可以尝试：

1. 在程序启动前设置环境变量：
   ```powershell
   $env:PYTHONIOENCODING = "utf-8"
   ```

2. 或者在系统级别设置（需要管理员权限）：
   ```powershell
   [System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Machine")
   ```

## 相关文件

- `setup-powershell-utf8.ps1` - 临时设置脚本
- `PowerShell-UTF8-Profile.ps1` - 配置文件模板
- `安装PowerShell中文支持.bat` - 自动安装脚本

## 参考

- [PowerShell 配置文件文档](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles)
- [Windows 代码页列表](https://docs.microsoft.com/windows/win32/intl/code-page-identifiers)
