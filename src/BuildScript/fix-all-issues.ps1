# Fix all build issues: toolset version and solution paths
# 修复所有构建问题：工具集版本和解决方案路径

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptPath
$rootPath = Split-Path -Parent $srcPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fixing All Build Issues" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Fix toolset version: v144 -> v145
Write-Host "[1] Updating toolset from v144 to v145..." -ForegroundColor Yellow

$projectFiles = Get-ChildItem -Path $srcPath -Filter "*.vcxproj" -Recurse -ErrorAction SilentlyContinue
$updated = 0

foreach ($file in $projectFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($content -and $content -match '<PlatformToolset>v144</PlatformToolset>') {
        $newContent = $content -replace '<PlatformToolset>v144</PlatformToolset>', '<PlatformToolset>v145</PlatformToolset>'
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
        $updated++
    }
}

Write-Host "  Updated $updated project files" -ForegroundColor Green
Write-Host ""

# 2. Fix solution file paths
Write-Host "[2] Fixing solution file paths..." -ForegroundColor Yellow

$solutionFile = Join-Path $srcPath "splayer.sln"
if (-not (Test-Path $solutionFile)) {
    Write-Host "  [ERROR] Solution file not found: $solutionFile" -ForegroundColor Red
    exit 1
}

# Backup
$backupFile = "$solutionFile.backup4"
Copy-Item $solutionFile $backupFile -Force

# Read and fix
$content = Get-Content $solutionFile -Raw -Encoding UTF8

# Fix all incorrect paths
$pathFixes = @(
    @{Old = 'Source\\filters\\Source\\d2vsrc\\Source\\d2vsource_vs2005\.vcxproj'; New = 'Source\filters\reader\d2vsource\d2vsource_vs2005.vcxproj'},
    @{Old = 'Source\\filters\\Source\\flicsrc\\Source\\flicsource_vs2005\.vcxproj'; New = 'Source\filters\reader\flicsource\flicsource_vs2005.vcxproj'},
    @{Old = 'Source\\filters\\Source\\basesrc\\Source\\basesource_vs2005\.vcxproj'; New = 'Source\filters\reader\basesource\basesource_vs2005.vcxproj'},
    @{Old = 'Source\\filters\\Source\\dtsac3src\\Source\\dtsac3source_vs2005\.vcxproj'; New = 'Source\filters\reader\dtsac3source\dtsac3source_vs2005.vcxproj'},
    @{Old = 'Source\\filters\\Source\\shoutcastsrc\\Source\\shoutcastsource_vs2005\.vcxproj'; New = 'Source\filters\reader\shoutcastsource\shoutcastsource_vs2005.vcxproj'},
    @{Old = 'Source\\filters\\Source\\flacsrc\\Source\\Flacsource\.vcxproj'; New = 'Source\filters\reader\Flacsource\Flacsource.vcxproj'},
    @{Old = 'Source\\zsrc\\lib\\zlib_vs2005\.vcxproj'; New = 'Source\zlib\zlib_vs2005.vcxproj'},
    @{Old = 'Source\\ui\\Resizablesrc\\lib\\ResizableLib_vs2005\.vcxproj'; New = 'Source\ui\ResizableLib\ResizableLib_vs2005.vcxproj'},
    @{Old = 'Source\\svpsrc\\lib\\svplib\.vcxproj'; New = 'Source\svplib\svplib.vcxproj'},
    @{Old = 'lib\\lyricsrc\\lib\\lyriclib\.vcxproj'; New = 'lib\lyriclib\lyriclib.vcxproj'},
    @{Old = 'lib\\id3src\\lib\\libprj\\id3lib\.vcxproj'; New = 'lib\id3lib\id3lib.vcxproj'},
    @{Old = 'Test\\HotkeySchemeParser_Unitsrc\\Test\\HotkeySchemeParser_UnitTest\.vcxproj'; New = 'Test\HotkeySchemeParser_UnitTest\HotkeySchemeParser_UnitTest.vcxproj'},
    @{Old = 'Test\\RARChunk_unisrc\\Test\\ChuckTest\.vcxproj'; New = 'Test\ChuckTest\ChuckTest.vcxproj'},
    @{Old = 'Test\\sqliteppsrc\\Test\\sqliteppTest\.vcxproj'; New = 'Test\sqliteppTest\sqliteppTest.vcxproj'},
    @{Old = 'Test\\MediaTree_src\\Test\\MediaTree_Test\.vcxproj'; New = 'Test\MediaTree_Test\MediaTree_Test.vcxproj'},
    @{Old = 'Source\\filters\\wavpacksrc\\lib\\wavpacklib\.vcxproj'; New = 'Source\filters\transform\WavPackDecoder\wavpack\wavpacklib.vcxproj'},
    @{Old = 'Source\\apps\\shared\\sharedsrc\\lib\\sharedlib\.vcxproj'; New = 'Source\apps\shared\sharedlib\sharedlib.vcxproj'},
    @{Old = 'Prototype\\SPlayerNewGui\\splayer\\splayer\.vcxproj'; New = 'Prototype\SPlayerNewGui\splayer\splayer.vcxproj'},
    @{Old = 'Prototype\\SPlayerNewGui\\splayer_rsc\\splayer_rsc\.vcxproj'; New = 'Prototype\SPlayerNewGui\splayer_rsc\splayer_rsc.vcxproj'}
)

$pathFixesCount = 0
foreach ($fix in $pathFixes) {
    if ($content -match $fix.Old) {
        $content = $content -replace $fix.Old, $fix.New
        $pathFixesCount++
    }
}

if ($pathFixesCount -gt 0) {
    [System.IO.File]::WriteAllText($solutionFile, $content, [System.Text.Encoding]::UTF8)
    Write-Host "  Fixed $pathFixesCount path issues" -ForegroundColor Green
} else {
    Write-Host "  No path issues found" -ForegroundColor Gray
}

Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - Updated $updated project files to v145" -ForegroundColor White
Write-Host "  - Fixed $pathFixesCount solution paths" -ForegroundColor White
Write-Host ""
