@echo off

set PATH=%CD%/hg_bin;%PATH%
set TOPDIR=%CD%/../

call "%VS120COMNTOOLS%vsvars32.bat"

echo Building sphash project of splayer-pkg ...
"%DevEnvDir%/devenv.com" ../thirdparty/pkg/trunk/sphash/sphash.sln /build "Release|Win32"
if %ERRORLEVEL% NEQ 0 goto error

echo Building sinet project of sinet ...
"%DevEnvDir%/devenv.com" ../thirdparty/sinet/trunk/sinet.sln  /build "Release|Win32"
if %ERRORLEVEL% NEQ 0 goto error


copy "..\thirdparty\pkg\trunk\unrar\unrar.hpp" "..\thirdparty\pkg\"
copy "..\thirdparty\pkg\trunk\unrar\unrar.lib" "..\thirdparty\pkg\"
copy "..\thirdparty\pkg\trunk\unrar\unrar.dll" "..\..\"
copy "..\thirdparty\pkg\trunk\sphash\release\sphash.lib" "..\thirdparty\pkg\"
copy "..\thirdparty\pkg\trunk\sphash\release\sphash.dll" "..\..\"
copy "..\thirdparty\pkg\trunk\sphash\sphash\sphash.h" "..\thirdparty\pkg\"
copy "..\thirdparty\sinet\trunk\release\sinet_dyn.lib" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\release\sinet_dyn_wrapper.lib" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\api_base.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\api_refptr.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\api_types.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\config.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\pool.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\postdata.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\postdataelem.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\request.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\sinet.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\task.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\sinet\task_observer.h" "..\thirdparty\sinet\"
copy "..\thirdparty\sinet\trunk\release\sinet.dll" "..\..\"

set /p ans=Do you want to build SPlayer now? Building splayer will take much longer time [y/n]^>
if "%ans%"== "y" (
goto buildsplayer
) else (
goto end
)
:buildsplayer

call "pre-build.cmd"
call "revision.cmd"

call "%VS120COMNTOOLS%vsvars32.bat"

echo Building SPlayer project ...
"%DevEnvDir%/devenv.com" ../splayer.sln  /build "Release Unicode|Win32"
if %ERRORLEVEL% NEQ 0 goto error

goto end

:error
echo ERROR: an error occurred during building
goto finished

:end
echo SPlayer built successfully

:finished
pause
