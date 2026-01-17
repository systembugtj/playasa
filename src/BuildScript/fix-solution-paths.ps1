# Fix incorrect paths in solution file
# 修复解决方案文件中的错误路径

$ErrorActionPreference = "Continue"
$rootPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$solutionFile = Join-Path $rootPath "splayer.sln"

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

# Fix common path issues
# Fix: src\Source\filters\src\Source\... -> src\Source\filters\...
$content = $content -replace 'src\\Source\\([^"]+)\\src\\Source\\', 'src\Source\$1\'

# Fix: src\Source\zsrc\lib\... -> src\Source\zlib\...
$content = $content -replace 'src\\Source\\zsrc\\lib\\', 'src\Source\zlib\'

# Fix: src\Source\ui\Resizablesrc\lib\... -> src\Source\ui\ResizableLib\...
$content = $content -replace 'src\\Source\\ui\\Resizablesrc\\lib\\', 'src\Source\ui\ResizableLib\'

# Fix: src\Source\svpsrc\lib\... -> src\Source\svplib\...
$content = $content -replace 'src\\Source\\svpsrc\\lib\\', 'src\Source\svplib\'

# Fix: src\lib\lyricsrc\lib\... -> src\lib\lyriclib\...
$content = $content -replace 'src\\lib\\lyricsrc\\lib\\', 'src\lib\lyriclib\'

# Fix: src\lib\id3src\lib\libprj\... -> src\lib\id3lib\...
$content = $content -replace 'src\\lib\\id3src\\lib\\libprj\\', 'src\lib\id3lib\'

# Fix: src\Test\HotkeySchemeParser_Unitsrc\Test\... -> src\Test\HotkeySchemeParser_UnitTest\...
$content = $content -replace 'src\\Test\\HotkeySchemeParser_Unitsrc\\Test\\', 'src\Test\HotkeySchemeParser_UnitTest\'

# Fix: src\Test\RARChunk_unisrc\Test\... -> src\Test\ChuckTest\...
$content = $content -replace 'src\\Test\\RARChunk_unisrc\\Test\\', 'src\Test\ChuckTest\'

# Fix: src\Test\sqliteppsrc\Test\... -> src\Test\sqliteppTest\...
$content = $content -replace 'src\\Test\\sqliteppsrc\\Test\\', 'src\Test\sqliteppTest\'

# Fix: src\Test\MediaTree_src\Test\... -> src\Test\MediaTree_Test\...
$content = $content -replace 'src\\Test\\MediaTree_src\\Test\\', 'src\Test\MediaTree_Test\'

# Fix: src\Source\filters\wavpacksrc\lib\... -> src\Source\filters\transform\WavPackDecoder\wavpack\...
$content = $content -replace 'src\\Source\\filters\\wavpacksrc\\lib\\', 'src\Source\filters\transform\WavPackDecoder\wavpack\'

# Fix: src\Source\apps\shared\sharedsrc\lib\... -> src\Source\apps\shared\sharedlib\...
$content = $content -replace 'src\\Source\\apps\\shared\\sharedsrc\\lib\\', 'src\Source\apps\shared\sharedlib\'

# Fix: Prototype\SPlayerNewGui\splayer\... -> src\Prototype\SPlayerNewGui\splayer\...
$content = $content -replace 'Prototype\\SPlayerNewGui\\', 'src\Prototype\SPlayerNewGui\'

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
