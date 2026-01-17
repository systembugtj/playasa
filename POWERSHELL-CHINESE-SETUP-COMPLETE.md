# ✅ PowerShell 全局中文支持配置完成

## 配置状态

✅ **PowerShell 全局中文支持已配置完成！**

### 配置文件位置

- **路径**: `C:\Users\alber\Documents\WindowsPowerShell\profile.ps1`
- **状态**: ✅ 已创建并配置 UTF-8 支持

## 配置内容

配置文件已包含以下 UTF-8 支持设置：

```powershell
# PowerShell UTF-8 Chinese Support Configuration
# Set console code page to UTF-8
if ($Host.Name -eq 'ConsoleHost') {
    chcp 65001 | Out-Null
}

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Set environment variables
$env:PYTHONIOENCODING = "utf-8"
```

## ⚠️ 重要提示

### 必须重启 PowerShell

配置完成后，**必须重新启动 PowerShell** 才能使配置生效！

当前会话可能仍显示乱码，这是正常的。重启后就会正常显示中文。

## 验证配置

### 步骤 1: 重启 PowerShell

关闭当前 PowerShell 窗口，重新打开一个新的 PowerShell 窗口。

### 步骤 2: 测试中文显示

运行以下命令：

```powershell
Write-Host "测试中文: 你好，世界！" -ForegroundColor Cyan
```

或运行测试脚本：

```powershell
.\test-chinese.ps1
```

### 步骤 3: 检查编码设置

```powershell
[Console]::OutputEncoding
[Console]::InputEncoding
$OutputEncoding
chcp
```

应该显示：
- OutputEncoding: Unicode (UTF-8) (65001)
- InputEncoding: Unicode (UTF-8) (65001)
- CodePage: 65001

## 如果重启后仍显示乱码

### 检查 1: 确认配置文件存在

```powershell
Test-Path $PROFILE
Get-Content $PROFILE
```

### 检查 2: 检查执行策略

```powershell
Get-ExecutionPolicy
```

如果为 Restricted，运行：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 检查 3: 手动应用配置

如果配置文件未自动加载，可以手动运行：

```powershell
chcp 65001
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
```

### 检查 4: 检查 PowerShell 字体

某些 PowerShell 字体可能不支持中文。可以：
1. 右键 PowerShell 标题栏 → 属性
2. 字体 → 选择支持中文的字体（如 "新宋体"、"Microsoft YaHei Mono"）

## 配置文件作用范围

- ✅ **用户级别**: 对所有 PowerShell 会话有效
- ✅ **自动加载**: 每次启动 PowerShell 时自动应用
- ⚠️ **需要重启**: 配置后必须重启 PowerShell

## 相关文件

- `setup-powershell-chinese-global.ps1` - 全局配置脚本
- `安装PowerShell中文支持-全局.bat` - 自动安装脚本
- `test-chinese.ps1` - 测试脚本
- `docs/POWERSHELL-CHINESE-GLOBAL.md` - 详细文档

## 快速参考

### 查看配置文件

```powershell
notepad $PROFILE
```

### 重新配置

```powershell
.\setup-powershell-chinese-global.ps1
```

### 测试配置

```powershell
.\test-chinese.ps1
```

---

**状态**: ✅ **配置完成**

**下一步**: **请重启 PowerShell 使配置生效**
