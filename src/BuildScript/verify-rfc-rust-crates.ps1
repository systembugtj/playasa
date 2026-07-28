#Requires -Version 5.1
<#
.SYNOPSIS
  Rust RFC track gate (0013/0014/0016/0020–0023): workspace layout + cargo test.

.DESCRIPTION
  Validates the four Playasa Rust cdylib crates, their MSBuild props wiring,
  and runs `cargo test --workspace` (no MSBuild required).
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$cargoToml = Join-Path $repoRoot 'Cargo.toml'

# RFC-0013..0023 workspace members and MSBuild props (must stay in sync).
$expectedCrates = @(
    @{ Name = 'sphash'; Props = 'src\Thirdparty\sphash.props'; Dll = 'playasa_sphash.dll' },
    @{ Name = 'playlist_parser'; Props = 'src\Thirdparty\playlist_parser_rust.props'; Dll = 'playasa_playlist_parser.dll' },
    @{ Name = 'subtitle_text_probe'; Props = 'src\Thirdparty\subtitle_text_probe_rust.props'; Dll = 'playasa_subtitle_text_probe.dll' },
    @{ Name = 'archive_helper'; Props = 'src\Thirdparty\archive_helper_rust.props'; Dll = 'playasa_archive_helper.dll' }
)

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required file: $Path"
    }
}

Assert-FileExists $cargoToml

$cargoRaw = Get-Content -LiteralPath $cargoToml -Raw -Encoding UTF8
foreach ($crate in $expectedCrates) {
    $crateToml = Join-Path $repoRoot "crates\$($crate.Name)\Cargo.toml"
    Assert-FileExists $crateToml

    $memberPath = "crates/$($crate.Name)"
    if ($cargoRaw -notmatch [regex]::Escape($memberPath)) {
        throw "Cargo.toml workspace missing member: $memberPath"
    }

    $propsPath = Join-Path $repoRoot $crate.Props
    Assert-FileExists $propsPath
    $propsRaw = Get-Content -LiteralPath $propsPath -Raw -Encoding UTF8
    if ($propsRaw -notmatch [regex]::Escape($crate.Dll)) {
        throw "$($crate.Props) must reference $($crate.Dll)"
    }
}

Push-Location $repoRoot
try {
    & cargo test --workspace
    if ($LASTEXITCODE -ne 0) {
        throw "cargo test --workspace failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

Write-Host "verify-rfc-rust-crates: OK ($($expectedCrates.Count) crates, cargo test --workspace)" -ForegroundColor Green
