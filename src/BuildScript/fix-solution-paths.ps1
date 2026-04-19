# Fix incorrect paths in solution file
# 修复解决方案文件中的错误路径

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptDir
$solutionFile = Join-Path $srcPath "splayer.sln"

Write-Host "Fixing solution file paths..." -ForegroundColor Cyan
Write-Host "Solution: $solutionFile" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $solutionFile)) {
    Write-Host "ERROR: Solution file not found!" -ForegroundColor Red
    exit 1
}

# Backup
$backupFile = "$solutionFile.backup2"
Copy-Item $solutionFile $backupFile -Force
Write-Host "Backup created: $backupFile" -ForegroundColor Green

# Read solution file
$content = Get-Content $solutionFile -Raw -Encoding UTF8
$originalContent = $content

# 解决方案在 src/ 下，路径以 Source\、lib\、Test\ 开头
# Fix: Source\filters\Source\... 重复段
$content = $content -replace 'Source\\([^"]+)\\Source\\', 'Source\$1\'

# Fix: Source\zsrc\lib\... -> Source\zlib\...
$content = $content -replace 'Source\\zsrc\\lib\\', 'Source\zlib\'

# Fix: Source\ui\Resizablesrc\lib\... -> Source\ui\ResizableLib\...
$content = $content -replace 'Source\\ui\\Resizablesrc\\lib\\', 'Source\ui\ResizableLib\'

# Fix: Source\svpsrc\lib\... -> Source\svplib\...
$content = $content -replace 'Source\\svpsrc\\lib\\', 'Source\svplib\'

# Fix: lib\lyricsrc\lib\... -> lib\lyriclib\...
$content = $content -replace 'lib\\lyricsrc\\lib\\', 'lib\lyriclib\'

# Fix: lib\id3src\lib\libprj\... -> lib\id3lib\...
$content = $content -replace 'lib\\id3src\\lib\\libprj\\', 'lib\id3lib\'

# Fix: Test\HotkeySchemeParser_Unitsrc\Test\... -> Test\HotkeySchemeParser_UnitTest\...
$content = $content -replace 'Test\\HotkeySchemeParser_Unitsrc\\Test\\', 'Test\HotkeySchemeParser_UnitTest\'

# Fix: Test\RARChunk_unisrc\Test\... -> Test\ChuckTest\...
$content = $content -replace 'Test\\RARChunk_unisrc\\Test\\', 'Test\ChuckTest\'

# Fix: Test\sqliteppsrc\Test\... -> Test\sqliteppTest\...
$content = $content -replace 'Test\\sqliteppsrc\\Test\\', 'Test\sqliteppTest\'

# Fix: Test\MediaTree_src\Test\... -> Test\MediaTree_Test\...
$content = $content -replace 'Test\\MediaTree_src\\Test\\', 'Test\MediaTree_Test\'

# Fix: Source\filters\wavpacksrc\lib\... -> Source\filters\transform\WavPackDecoder\wavpack\...
$content = $content -replace 'Source\\filters\\wavpacksrc\\lib\\', 'Source\filters\transform\WavPackDecoder\wavpack\'

# Fix: Source\apps\shared\sharedsrc\lib\... -> Source\apps\shared\sharedlib\...
$content = $content -replace 'Source\\apps\\shared\\sharedsrc\\lib\\', 'Source\apps\shared\sharedlib\'

# Fix: 若出现错误前缀 src\Source\（从根目录方案迁入），去掉 src\
$content = $content -replace '"src\\Source\\', '"Source\'
$content = $content -replace '"src\\lib\\', '"lib\'
$content = $content -replace '"src\\Test\\', '"Test\'
$content = $content -replace '"src\\Thirdparty\\', '"Thirdparty\'
$content = $content -replace '"src\\Prototype\\', '"Prototype\'

# Count changes
$changes = 0
if ($content -ne $originalContent) {
    $changes = (Compare-Object ($originalContent -split "`n") ($content -split "`n")).Count
    Write-Host "Found $changes path issues to fix" -ForegroundColor Yellow
} else {
    Write-Host "No path issues found" -ForegroundColor Green
}

# Write fixed content
if ($content -ne $originalContent) {
    [System.IO.File]::WriteAllText($solutionFile, $content, [System.Text.Encoding]::UTF8)
    Write-Host "Solution file updated!" -ForegroundColor Green
} else {
    Write-Host "No changes needed" -ForegroundColor Gray
}

Write-Host ""
