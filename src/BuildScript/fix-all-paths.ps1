# Fix all path issues in solution file
# 修复解决方案文件中的所有路径问题

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Split-Path -Parent $scriptDir
$solutionFile = Join-Path $srcPath "splayer.sln"

Write-Host "Fixing all path issues in solution file..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $solutionFile)) {
    Write-Host "ERROR: Solution file not found: $solutionFile" -ForegroundColor Red
    exit 1
}

# Backup
$backupFile = "$solutionFile.backup3"
Copy-Item $solutionFile $backupFile -Force
Write-Host "Backup created: $backupFile" -ForegroundColor Green

# Read solution file
$content = Get-Content $solutionFile -Raw -Encoding UTF8
$originalContent = $content

# Fix all path patterns
# 解决方案位于 src/，工程路径为 Source\、lib\ 等（相对 src）
$fixes = @(
    @{Pattern = 'Source\\filters\\Source\\d2vsrc\\Source\\d2vsource_vs2005\.vcxproj'; Replacement = 'Source\filters\reader\d2vsource\d2vsource_vs2005.vcxproj'},
    @{Pattern = 'Source\\filters\\Source\\flicsrc\\Source\\flicsource_vs2005\.vcxproj'; Replacement = 'Source\filters\reader\flicsource\flicsource_vs2005.vcxproj'},
    @{Pattern = 'Source\\filters\\Source\\basesrc\\Source\\basesource_vs2005\.vcxproj'; Replacement = 'Source\filters\reader\basesource\basesource_vs2005.vcxproj'},
    @{Pattern = 'Source\\filters\\Source\\dtsac3src\\Source\\dtsac3source_vs2005\.vcxproj'; Replacement = 'Source\filters\reader\dtsac3source\dtsac3source_vs2005.vcxproj'},
    @{Pattern = 'Source\\filters\\Source\\shoutcastsrc\\Source\\shoutcastsource_vs2005\.vcxproj'; Replacement = 'Source\filters\reader\shoutcastsource\shoutcastsource_vs2005.vcxproj'},
    @{Pattern = 'Source\\filters\\Source\\flacsrc\\Source\\Flacsource\.vcxproj'; Replacement = 'Source\filters\reader\Flacsource\Flacsource.vcxproj'},
    @{Pattern = 'Source\\zsrc\\lib\\zlib_vs2005\.vcxproj'; Replacement = 'Source\zlib\zlib_vs2005.vcxproj'},
    @{Pattern = 'Source\\ui\\Resizablesrc\\lib\\ResizableLib_vs2005\.vcxproj'; Replacement = 'Source\ui\ResizableLib\ResizableLib_vs2005.vcxproj'},
    @{Pattern = 'Source\\svpsrc\\lib\\svplib\.vcxproj'; Replacement = 'Source\svplib\svplib.vcxproj'},
    @{Pattern = 'lib\\lyricsrc\\lib\\lyriclib\.vcxproj'; Replacement = 'lib\lyriclib\lyriclib.vcxproj'},
    @{Pattern = 'lib\\id3src\\lib\\libprj\\id3lib\.vcxproj'; Replacement = 'lib\id3lib\id3lib.vcxproj'},
    @{Pattern = 'Test\\HotkeySchemeParser_Unitsrc\\Test\\HotkeySchemeParser_UnitTest\.vcxproj'; Replacement = 'Test\HotkeySchemeParser_UnitTest\HotkeySchemeParser_UnitTest.vcxproj'},
    @{Pattern = 'Test\\RARChunk_unisrc\\Test\\ChuckTest\.vcxproj'; Replacement = 'Test\ChuckTest\ChuckTest.vcxproj'},
    @{Pattern = 'Test\\sqliteppsrc\\Test\\sqliteppTest\.vcxproj'; Replacement = 'Test\sqliteppTest\sqliteppTest.vcxproj'},
    @{Pattern = 'Test\\MediaTree_src\\Test\\MediaTree_Test\.vcxproj'; Replacement = 'Test\MediaTree_Test\MediaTree_Test.vcxproj'},
    @{Pattern = 'Source\\filters\\wavpacksrc\\lib\\wavpacklib\.vcxproj'; Replacement = 'Source\filters\transform\WavPackDecoder\wavpack\wavpacklib.vcxproj'},
    @{Pattern = 'Source\\apps\\shared\\sharedsrc\\lib\\sharedlib\.vcxproj'; Replacement = 'Source\apps\shared\sharedlib\sharedlib.vcxproj'},
    @{Pattern = 'Prototype\\SPlayerNewGui\\splayer\\splayer\.vcxproj'; Replacement = 'Prototype\SPlayerNewGui\splayer\splayer.vcxproj'},
    @{Pattern = 'Prototype\\SPlayerNewGui\\splayer_rsc\\splayer_rsc\.vcxproj'; Replacement = 'Prototype\SPlayerNewGui\splayer_rsc\splayer_rsc.vcxproj'}
)

$totalFixes = 0
foreach ($fix in $fixes) {
    if ($content -match $fix.Pattern) {
        $content = $content -replace $fix.Pattern, $fix.Replacement
        $totalFixes++
        Write-Host "Fixed: $($fix.Pattern)" -ForegroundColor Green
    }
}

if ($totalFixes -gt 0) {
    [System.IO.File]::WriteAllText($solutionFile, $content, [System.Text.Encoding]::UTF8)
    Write-Host ""
    Write-Host "Fixed $totalFixes path issues!" -ForegroundColor Green
} else {
    Write-Host "No path issues found" -ForegroundColor Gray
}

Write-Host ""
