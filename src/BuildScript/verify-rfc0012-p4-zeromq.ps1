#Requires -Version 5.1
<#
.SYNOPSIS
  RFC-0012 P4：无 MSBuild 时校验 zeromq 2.1.3 ABI 钉扎与 smoke test 入口。
#>
$ErrorActionPreference = 'Stop'

$REPO_ROOT = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$EXPECT_FILE = Join-Path $REPO_ROOT 'src/Thirdparty/zeromq/rfc0012-expected.txt'
$ZMQ_H = Join-Path $REPO_ROOT 'src/include/zmq/zmq.h'
$ZMQ_HPP = Join-Path $REPO_ROOT 'src/include/zmq/zmq.hpp'
$PLATFORM_H = Join-Path $REPO_ROOT 'src/Thirdparty/zeromq/platform.hpp'
$LIBZMQ_PROJ = Join-Path $REPO_ROOT 'src/Thirdparty/zeromq/libzmq.vcxproj'
$SMOKE_SCRIPT = Join-Path $REPO_ROOT 'src/Test/Scripts/test-zeromq-smoke.ps1'
$AF_SERVER = Join-Path $REPO_ROOT 'src/Prototype/AcousticFingerprintServer/AFServer.c'
$AF_ZMQ_HELPER = Join-Path $REPO_ROOT 'src/Prototype/AcousticFingerprintServer/libs/zmqhelper.h'
$AF_AUDIO_DATA = Join-Path $REPO_ROOT 'src/Prototype/AcousticFingerprintServer/libs/audiodata.c'
$MPLAYERC_PROJ = Join-Path $REPO_ROOT 'src/Source/apps/mplayerc/mplayerc_vs2005.vcxproj'

function Read-FirstNonEmptyLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
    $line = (Get-Content -LiteralPath $Path -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1).Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { throw "Empty expectation file: $Path" }
    return $line
}

function Test-RequiredFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
}

foreach ($path in @(
    $EXPECT_FILE,
    $ZMQ_H,
    $ZMQ_HPP,
    $PLATFORM_H,
    $LIBZMQ_PROJ,
    $SMOKE_SCRIPT,
    $AF_SERVER,
    $AF_ZMQ_HELPER,
    $AF_AUDIO_DATA,
    $MPLAYERC_PROJ
)) {
    Test-RequiredFile $path
}

$tag = Read-FirstNonEmptyLine $EXPECT_FILE
if ($tag -ne 'zeromq-2.1.3-abi-pinned') {
    throw "Unknown zeromq rfc0012-expected.txt first line: '$tag'. Add a branch in verify-rfc0012-p4-zeromq.ps1 after zeromq upgrade."
}

$header = Get-Content -LiteralPath $ZMQ_H -Raw -Encoding UTF8
foreach ($required in @(
    '#define ZMQ_VERSION_MAJOR 2',
    '#define ZMQ_VERSION_MINOR 1',
    '#define ZMQ_VERSION_PATCH 3',
    'ZMQ_EXPORT void \*zmq_init \(int io_threads\);',
    'ZMQ_EXPORT int zmq_send \(void \*s, zmq_msg_t \*msg, int flags\);',
    '#define ZMQ_XREQ ZMQ_DEALER',
    '#define ZMQ_XREP ZMQ_ROUTER',
    'ZMQ_EXPORT int zmq_device \(int device, void \* insocket, void\* outsocket\);'
)) {
    if ($header -notmatch $required) {
        throw "zmq.h missing expected 2.1 ABI entry: $required"
    }
}

$project = Get-Content -LiteralPath $LIBZMQ_PROJ -Raw -Encoding UTF8
foreach ($required in @(
    '<ConfigurationType>StaticLibrary</ConfigurationType>',
    '-DFD_SETSIZE=1024',
    'ZMQ_STATIC',
    '<RuntimeLibrary>MultiThreaded</RuntimeLibrary>',
    'Ws2_32.lib',
    'Rpcrt4.lib',
    '<ClCompile Include="zmq.cpp" />',
    '<ClInclude Include="..\..\include\zmq\zmq.h" />'
)) {
    if ($project -notlike "*$required*") {
        throw "libzmq.vcxproj missing expected ABI/build entry: $required"
    }
}

$platform = Get-Content -LiteralPath $PLATFORM_H -Raw -Encoding UTF8
if ($platform -notmatch '#define ZMQ_HAVE_WINDOWS') {
    throw 'zeromq platform.hpp does not pin ZMQ_HAVE_WINDOWS'
}

$smoke = Get-Content -LiteralPath $SMOKE_SCRIPT -Raw -Encoding UTF8
foreach ($required in @(
    'zeromq smoke OK',
    'ZMQ_PAIR',
    'zmq_init\(1\)',
    'zmq_send\(client, &outbound, 0\)',
    'zmq_recv\(server, &inbound, 0\)'
)) {
    if ($smoke -notmatch $required) {
        throw "test-zeromq-smoke.ps1 missing runtime coverage entry: $required"
    }
}

$afServer = Get-Content -LiteralPath $AF_SERVER -Raw -Encoding UTF8
foreach ($required in @(
    'zmq_init\(1\)',
    'ZMQ_XREP',
    'ZMQ_XREQ',
    'zmq_device\(ZMQ_QUEUE',
    'send_msg_vsm',
    'recieve_msg'
)) {
    if ($afServer -notmatch $required) {
        throw "AFServer.c no longer contains expected zeromq 2.1 API usage: $required"
    }
}

$afZmqHelper = Get-Content -LiteralPath $AF_ZMQ_HELPER -Raw -Encoding UTF8
foreach ($required in @(
    'zmq_send\(skt, &msg, 0\)',
    'zmq_send\(skt, &msg, ZMQ_SNDMORE\)',
    'zmq_recv\(skt, &msg, 0\)'
)) {
    if ($afZmqHelper -notmatch $required) {
        throw "zmqhelper.h no longer contains expected zeromq 2.1 message helper usage: $required"
    }
}

$afAudioData = Get-Content -LiteralPath $AF_AUDIO_DATA -Raw -Encoding UTF8
foreach ($required in @(
    'zmq_send\(skt, &cmd_msg, ZMQ_SNDMORE\)',
    'zmq_recv\(skt, &uid_msg, 0\)'
)) {
    if ($afAudioData -notmatch $required) {
        throw "audiodata.c no longer contains expected zeromq 2.1 client usage: $required"
    }
}

$mplayerc = Get-Content -LiteralPath $MPLAYERC_PROJ -Raw -Encoding UTF8
if ($mplayerc -notmatch 'libzmq\.lib') {
    throw 'mplayerc Release Unicode no longer links libzmq.lib; update P4 zeromq verification'
}

Write-Host 'verify-rfc0012-p4-zeromq: OK (zeromq 2.1.3 ABI pin + smoke test entry)' -ForegroundColor Green
