# PowerShell 全局中文支持配置

## ✅ 配置完成

PowerShell 全局中文支持已配置完成！

### 配置文件位置

- **配置文件**: `C:\Users\<用户名>\Documents\WindowsPowerShell\profile.ps1`
- **配置类型**: 用户级别（所有 PowerShell 会话）

## 配置内容

配置文件已添加以下内容：

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

## 使用方法

### 方法 1: 自动配置（已完成）

运行项目中的配置脚本：

```batch
安装PowerShell中文支持-全局.bat
```

或直接运行 PowerShell 脚本：

```powershell
.\setup-powershell-chinese-global.ps1
```

### 方法 2: 手动验证

1. **重新启动 PowerShell**（重要！）
2. **测试中文显示**:
   ```powershell
   Write-Host "测试中文: 你好，世界！" -ForegroundColor Cyan
   ```

或运行测试脚本：

```powershell
.\test-chinese.ps1
```

## 验证配置

### 检查配置文件

```powershell
# 查看配置文件
notepad $PROFILE

# 或
Get-Content $PROFILE
```

### 检查编码设置

```powershell
# 检查当前编码
[Console]::OutputEncoding
[Console]::InputEncoding
$OutputEncoding

# 检查代码页
chcp
```

应该显示：
- OutputEncoding: Unicode (UTF-8) (65001)
- InputEncoding: Unicode (UTF-8) (65001)
- CodePage: 65001

## 重要提示

### ⚠️ 必须重启 PowerShell

配置完成后，**必须重新启动 PowerShell** 才能使配置生效！

### 配置文件作用范围

- **用户级别**: 配置对所有 PowerShell 会话有效
- **系统级别**: 需要管理员权限（可选）

### 如果中文仍显示乱码

1. **确认已重启 PowerShell**
2. **检查配置文件是否存在**:
   ```powershell
   Test-Path $PROFILE
   ```
3. **检查执行策略**:
   ```powershell
   Get-ExecutionPolicy
   ```
   如果为 Restricted，运行：
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. **手动应用配置**:
   ```powershell
   chcp 65001
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   ```

## 系统级别配置（可选）

如果需要为所有用户配置（需要管理员权限）：

```powershell
# 以管理员身份运行 PowerShell
[System.Environment]::SetEnvironmentVariable("PYTHONIOENCODING", "utf-8", "Machine")
```

## 相关文件

- `setup-powershell-chinese-global.ps1` - 全局配置脚本
- `安装PowerShell中文支持-全局.bat` - 自动安装脚本
- `test-chinese.ps1` - 测试脚本
- `setup-powershell-utf8.ps1` - 临时设置脚本（仅当前会话）

## 故障排除

### 问题 1: 配置文件无法加载

**错误**: "无法加载配置文件"

**解决**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题 2: 重启后仍显示乱码

**解决**:
1. 检查配置文件是否正确创建
2. 确认配置文件路径正确
3. 手动编辑配置文件添加 UTF-8 设置

### 问题 3: 某些程序仍显示乱码

某些程序可能使用系统默认编码。可以：
1. 在程序启动前设置环境变量
2. 或在系统级别设置（需要管理员权限）

## 参考

- [PowerShell 配置文件文档](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_profiles)
- [Windows 代码页列表](https://docs.microsoft.com/windows/win32/intl/code-page-identifiers)

---

**状态**: ✅ **配置完成，请重启 PowerShell 使配置生效**
