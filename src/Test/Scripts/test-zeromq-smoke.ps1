#Requires -Version 5.1
<#
.SYNOPSIS
  Build libzmq and run a minimal 0MQ 2.1 inproc PAIR send/receive smoke test.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSupport\SplayerTestSupport.psm1') -Force

$srcRoot = Get-SplayerSrcRoot
$repoRoot = Get-SplayerRepoRoot
$msbuild = Get-SplayerMsBuildPath

$libzmqProject = Join-Path $srcRoot 'Thirdparty\zeromq\libzmq.vcxproj'
Write-Host "Step: build libzmq -> $libzmqProject"
& $msbuild $libzmqProject /t:Build /m /p:Configuration=Release /p:Platform=Win32 "/p:SolutionDir=$srcRoot\" /v:minimal /nologo
if ($LASTEXITCODE -ne 0) {
    throw "libzmq build failed with exit code $LASTEXITCODE"
}

$workRoot = Join-Path $repoRoot 'out\obj\zeromq-smoke'
if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $workRoot | Out-Null

$sourcePath = Join-Path $workRoot 'zmq_smoke.cpp'
$projectPath = Join-Path $workRoot 'zmq_smoke.vcxproj'

@'
#include <cstring>
#include <iostream>
#include <zmq/zmq.h>

namespace {

const char kEndpoint[] = "inproc://playasa-zmq-smoke";
const char kPayload[] = "playasa-zmq-smoke";

bool CheckRc(int rc, const char* what)
{
    if (rc == 0) {
        return true;
    }

    std::cerr << what << " failed: " << zmq_strerror(zmq_errno()) << std::endl;
    return false;
}

}  // namespace

int main()
{
    int major = 0;
    int minor = 0;
    int patch = 0;
    zmq_version(&major, &minor, &patch);
    if (major != 2 || minor != 1 || patch != 3) {
        std::cerr << "unexpected zmq version: " << major << "." << minor << "." << patch << std::endl;
        return 1;
    }

    void* ctx = zmq_init(1);
    if (!ctx) {
        std::cerr << "zmq_init failed: " << zmq_strerror(zmq_errno()) << std::endl;
        return 1;
    }

    void* server = zmq_socket(ctx, ZMQ_PAIR);
    void* client = zmq_socket(ctx, ZMQ_PAIR);
    if (!server || !client) {
        std::cerr << "zmq_socket failed: " << zmq_strerror(zmq_errno()) << std::endl;
        if (server) zmq_close(server);
        if (client) zmq_close(client);
        zmq_term(ctx);
        return 1;
    }

    if (!CheckRc(zmq_bind(server, kEndpoint), "zmq_bind") ||
        !CheckRc(zmq_connect(client, kEndpoint), "zmq_connect")) {
        zmq_close(client);
        zmq_close(server);
        zmq_term(ctx);
        return 1;
    }

    zmq_msg_t outbound;
    zmq_msg_t inbound;
    if (!CheckRc(zmq_msg_init_size(&outbound, sizeof(kPayload)), "zmq_msg_init_size")) {
        zmq_close(client);
        zmq_close(server);
        zmq_term(ctx);
        return 1;
    }
    std::memcpy(zmq_msg_data(&outbound), kPayload, sizeof(kPayload));

    if (!CheckRc(zmq_send(client, &outbound, 0), "zmq_send") ||
        !CheckRc(zmq_msg_close(&outbound), "zmq_msg_close outbound") ||
        !CheckRc(zmq_msg_init(&inbound), "zmq_msg_init inbound")) {
        zmq_close(client);
        zmq_close(server);
        zmq_term(ctx);
        return 1;
    }

    zmq_pollitem_t items[] = {{server, 0, ZMQ_POLLIN, 0}};
    const int poll_rc = zmq_poll(items, 1, 5000);
    if (poll_rc <= 0 || !(items[0].revents & ZMQ_POLLIN)) {
        std::cerr << "zmq_poll timed out or failed" << std::endl;
        zmq_msg_close(&inbound);
        zmq_close(client);
        zmq_close(server);
        zmq_term(ctx);
        return 1;
    }

    if (!CheckRc(zmq_recv(server, &inbound, 0), "zmq_recv")) {
        zmq_msg_close(&inbound);
        zmq_close(client);
        zmq_close(server);
        zmq_term(ctx);
        return 1;
    }

    const bool payload_ok = zmq_msg_size(&inbound) == sizeof(kPayload) &&
        std::memcmp(zmq_msg_data(&inbound), kPayload, sizeof(kPayload)) == 0;

    zmq_msg_close(&inbound);
    zmq_close(client);
    zmq_close(server);
    zmq_term(ctx);

    if (!payload_ok) {
        std::cerr << "payload mismatch" << std::endl;
        return 1;
    }

    std::cout << "zeromq smoke OK: " << major << "." << minor << "." << patch << std::endl;
    return 0;
}
'@ | Set-Content -LiteralPath $sourcePath -Encoding ASCII

$includeDir = (Join-Path $srcRoot 'include') -replace '&', '&amp;'
$libraryDir = (Join-Path $repoRoot 'out\bin\Win32\Release') -replace '&', '&amp;'
$escapedSourcePath = $sourcePath -replace '&', '&amp;'

@"
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="12.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Release|Win32">
      <Configuration>Release</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{7F40D657-9682-4BA0-A2AC-095C54D95B29}</ProjectGuid>
    <RootNamespace>zmq_smoke</RootNamespace>
    <Keyword>Win32Proj</Keyword>
  </PropertyGroup>
  <Import Project="`$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
  <PropertyGroup Condition="'`$(Configuration)|`$(Platform)'=='Release|Win32'" Label="Configuration">
    <ConfigurationType>Application</ConfigurationType>
    <PlatformToolset>v145</PlatformToolset>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  <Import Project="`$(VCTargetsPath)\Microsoft.Cpp.props" />
  <PropertyGroup>
    <OutDir>$workRoot\out\</OutDir>
    <IntDir>$workRoot\obj\</IntDir>
  </PropertyGroup>
  <ItemDefinitionGroup Condition="'`$(Configuration)|`$(Platform)'=='Release|Win32'">
    <ClCompile>
      <AdditionalIncludeDirectories>$includeDir;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>WIN32;NDEBUG;ZMQ_STATIC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
      <WarningLevel>Level3</WarningLevel>
    </ClCompile>
    <Link>
      <AdditionalOptions>/LTCG /ignore:4099 %(AdditionalOptions)</AdditionalOptions>
      <AdditionalLibraryDirectories>$libraryDir;%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>
      <AdditionalDependencies>libzmq.lib;Ws2_32.lib;Rpcrt4.lib;%(AdditionalDependencies)</AdditionalDependencies>
      <SubSystem>Console</SubSystem>
      <TargetMachine>MachineX86</TargetMachine>
    </Link>
  </ItemDefinitionGroup>
  <ItemGroup>
    <ClCompile Include="$escapedSourcePath" />
  </ItemGroup>
  <Import Project="`$(VCTargetsPath)\Microsoft.Cpp.targets" />
</Project>
"@ | Set-Content -LiteralPath $projectPath -Encoding ASCII

Write-Host "Step: build zeromq smoke -> $projectPath"
& $msbuild $projectPath /t:Rebuild /m /p:Configuration=Release /p:Platform=Win32 /v:minimal /nologo
if ($LASTEXITCODE -ne 0) {
    throw "zeromq smoke build failed with exit code $LASTEXITCODE"
}

$exePath = Join-Path $workRoot 'out\zmq_smoke.exe'
Write-Host "Step: run zeromq smoke -> $exePath"
& $exePath
if ($LASTEXITCODE -ne 0) {
    throw "zeromq smoke failed with exit code $LASTEXITCODE"
}
