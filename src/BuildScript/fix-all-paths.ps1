# Fix all path issues in solution file
# 修复解决方案文件中的所有路径问题

$ErrorActionPreference = "Continue"
$rootPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$solutionFile = Join-Path $rootPath "splayer.sln"

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
$fixes = @(
    @{Pattern = 'src\\Source\\filters\\src\\Source\\d2vsrc\\Source\\d2vsource_vs2005\.vcxproj'; Replacement = 'src\Source\filters\reader\d2vsource\d2vsource_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\src\\Source\\flicsrc\\Source\\flicsource_vs2005\.vcxproj'; Replacement = 'src\Source\filters\reader\flicsource\flicsource_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\src\\Source\\basesrc\\Source\\basesource_vs2005\.vcxproj'; Replacement = 'src\Source\filters\reader\basesource\basesource_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\src\\Source\\dtsac3src\\Source\\dtsac3source_vs2005\.vcxproj'; Replacement = 'src\Source\filters\reader\dtsac3source\dtsac3source_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\src\\Source\\shoutcastsrc\\Source\\shoutcastsource_vs2005\.vcxproj'; Replacement = 'src\Source\filters\reader\shoutcastsource\shoutcastsource_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\src\\Source\\flacsrc\\Source\\Flacsource\.vcxproj'; Replacement = 'src\Source\filters\reader\Flacsource\Flacsource.vcxproj'},
    @{Pattern = 'src\\Source\\zsrc\\lib\\zlib_vs2005\.vcxproj'; Replacement = 'src\Source\zlib\zlib_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\ui\\Resizablesrc\\lib\\ResizableLib_vs2005\.vcxproj'; Replacement = 'src\Source\ui\ResizableLib\ResizableLib_vs2005.vcxproj'},
    @{Pattern = 'src\\Source\\svpsrc\\lib\\svplib\.vcxproj'; Replacement = 'src\Source\svplib\svplib.vcxproj'},
    @{Pattern = 'src\\lib\\lyricsrc\\lib\\lyriclib\.vcxproj'; Replacement = 'src\lib\lyriclib\lyriclib.vcxproj'},
    @{Pattern = 'src\\lib\\id3src\\lib\\libprj\\id3lib\.vcxproj'; Replacement = 'src\lib\id3lib\id3lib.vcxproj'},
    @{Pattern = 'src\\Test\\HotkeySchemeParser_Unitsrc\\Test\\HotkeySchemeParser_UnitTest\.vcxproj'; Replacement = 'src\Test\HotkeySchemeParser_UnitTest\HotkeySchemeParser_UnitTest.vcxproj'},
    @{Pattern = 'src\\Test\\RARChunk_unisrc\\Test\\ChuckTest\.vcxproj'; Replacement = 'src\Test\ChuckTest\ChuckTest.vcxproj'},
    @{Pattern = 'src\\Test\\sqliteppsrc\\Test\\sqliteppTest\.vcxproj'; Replacement = 'src\Test\sqliteppTest\sqliteppTest.vcxproj'},
    @{Pattern = 'src\\Test\\MediaTree_src\\Test\\MediaTree_Test\.vcxproj'; Replacement = 'src\Test\MediaTree_Test\MediaTree_Test.vcxproj'},
    @{Pattern = 'src\\Source\\filters\\wavpacksrc\\lib\\wavpacklib\.vcxproj'; Replacement = 'src\Source\filters\transform\WavPackDecoder\wavpack\wavpacklib.vcxproj'},
    @{Pattern = 'src\\Source\\apps\\shared\\sharedsrc\\lib\\sharedlib\.vcxproj'; Replacement = 'src\Source\apps\shared\sharedlib\sharedlib.vcxproj'},
    @{Pattern = 'Prototype\\SPlayerNewGui\\splayer\\splayer\.vcxproj'; Replacement = 'src\Prototype\SPlayerNewGui\splayer\splayer.vcxproj'},
    @{Pattern = 'Prototype\\SPlayerNewGui\\splayer_rsc\\splayer_rsc\.vcxproj'; Replacement = 'src\Prototype\SPlayerNewGui\splayer_rsc\splayer_rsc.vcxproj'}
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
