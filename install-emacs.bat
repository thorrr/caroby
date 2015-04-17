::::::::: Common ::::::::::::::::
@echo off
setlocal
pushd .
:: User modifiable ::::::::::::::
set emacsVersion=24.4
set zlibVersion=1.2.7-1
set pngVersion=1.4.3-1
::set emacsMD5=06033dc7a9869dacb10299a8df99b9c2
set emacsMD5=39a74019f10739b7563af733cb379902
set zlibMD5=f7cdd2d5a7b2645ac9bc8b981b596de5
set pngMD5=44ee062641a204f65f0e96720fe57282
:::::::::::::::::::::::::::::::::

if %emacsVersion% geq 24.4 (
    set urlStub=i686-pc-mingw32
) else (
    set urlStub=i386
)

set packageName=emacs-%emacsVersion%
set emacsUrl=http://mirrors.kernel.org/gnu/emacs/windows/emacs-%emacsVersion%-bin-%urlStub%.zip
set zlibUrl=http://win32builder.gnome.org/packages/3.6/zlib_%zlibVersion%_win32.zip
set libpngUrl=http://ftp.gnome.org/pub/gnome/binaries/win32/dependencies/libpng_%pngVersion%_win32.zip

call :carobyRegistry || goto :error
call :verifyPackageNotInstalled %packageName% || goto :error

::download
pushd .
cd "%DOWNLOAD_DIR%
call :download %emacsUrl% || goto :error
set emacsZip=%_rv%
call :verifyMD5Hash "%CD%\%emacsZip%" %emacsMD5% || goto :error

call :download %zlibUrl% || goto :error
set zlibZip=%_rv%
call :verifyMD5Hash "%CD%\%zlibZip%" %zlibMD5% || goto :error

call :download %libpngUrl% || goto :error
set pngZip=%_rv%
call :verifyMD5Hash "%CD%\%pngZip%" %pngMD5% || goto :error

popd

::unzipAndInstall
pushd .
call :installPath %packageName%
set packageDir=%_rv%
call :mktemp /D || goto :error
set tmp=%_rv%\tmp
call :UnZipFile "%tmp%" "%DOWNLOAD_DIR%\%emacsZip%" || goto :error
cd "%tmp%"
::pre 24.4 zip files have emacs-%emacsVersion% as a top level folder in the zip
move emacs-%emacsVersion% tmp 2>nul
cd tmp 2>nul
cd ..
move "%CD%\tmp" "%packageDir%" >nul || goto :error
popd

call :mktemp /D || goto :error
call :UnZipFile "%_rv%" "%DOWNLOAD_DIR%\%zlibZip%" || goto :error
copy "%_rv%\bin\*" "%packageDir%\bin\" >nul

call :mktemp /D || goto :error
call :UnZipFile "%_rv%" "%DOWNLOAD_DIR%\%pngZip%" || goto :error
copy "%_rv%\bin\*" "%packageDir%\bin\" >nul

:mkshortcut
pushd .
cd /d %CAROBY_DIR%
call :shortInstallPath %packageName% || goto :error
bin\mkshortcut.vbs /target:cmd /args:"/c bin\caroby-init.bat %_rv%\bin\runemacs.exe" /shortcut:emacs
popd

:::::::::: End of script :::::::
echo. Done.
goto :end
:error
echo.
if "%_err%" neq "" (
    echo ERROR:  %_err%
    if "%_err2%" neq "" echo %_err2%
) else (
    if %errorlevel% neq 0 echo errorlevel is %errorlevel%
)
echo.
popd
endlocal
exit /b -1

:end

endlocal
popd
GOTO:EOF
::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::
:: Function Library
::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::--------------------------------------------------------
::---- Some patterns and conventions are borrowed from:
::           http://www.dostips.com/DtTutoFunctions.php
:: ---- use _rv for return value
:: ---- use _err[n] for error messages
:: ---- if variable is a path don't store the surrounding double quotes
:: ---- surround all paths with quotes when passing them into functions.  
:: ---- ---- example: call :bazFn "%FOOPATH%"
:: ---- if needed, the function can strip quotes by using tilde.
:: ---- ---- example:  %~2, not %2
:: ---- if you need caroby environment state do call :carobyRegistry at the top
:: ---- to strip double quotes in an ordinary variable do:
:: ---- ---- set EX=%EX:"=%
::--------------------------------------------------------

:myFunctionName    -- function description here
::                 -- %~1: argument description here (strip quotes)
::                 -- %2 : second argument, this keeps double quotes intact
SETLOCAL
REM.--function body here
set LocalVar1=...
set LocalVar2=...
(ENDLOCAL & REM -- RETURN VALUES
    IF "%~1" NEQ "" SET %~1=%LocalVar1%
    IF "%~2" NEQ "" SET %~2=%LocalVar2%
)
GOTO:EOF

:UnZipFile <ExtractTo> <newzipfile>
SETLOCAL
set vbs="%temp%\_.vbs"
if exist %vbs% del /f /q %vbs%
>%vbs%  echo Set fso = CreateObject("Scripting.FileSystemObject")
>>%vbs% echo If NOT fso.FolderExists(%1) Then
>>%vbs% echo fso.CreateFolder(%1)
>>%vbs% echo End If
>>%vbs% echo set objShell = CreateObject("Shell.Application")
>>%vbs% echo set FilesInZip=objShell.NameSpace(%2).items
>>%vbs% echo objShell.NameSpace(%1).CopyHere(FilesInZip)
>>%vbs% echo Set fso = Nothing
>>%vbs% echo Set objShell = Nothing
cscript //nologo %vbs%
if exist %vbs% del /f /q %vbs%
ENDLOCAL
GOTO:EOF

:download          -- download a file.  Skip with message if file already exists.  Return filename.
::                 -- %~1 - URL
::                 -- %2 - filename (optional)
set _rv=
SETLOCAL
call :filenameFromURL %~1
if [%2]==[] (
    set filename=%_rv%
) else (
    set filename=%~2
)
if exist %filename% (
    echo.
    echo %CD%\%filename% exists.  Do
    echo.
    echo del /q "%CD%\%filename%"
    echo.
    echo to refresh it.
    echo.
) else (
    echo Downloading %filename%
    call :wget %~1 "%filename%"
    echo Done.
)
ENDLOCAL&set _rv=%filename%
GOTO:EOF



:filenameFromURL   -- extract the filename from a URL by parsing the token past the last backslash
::                 -- %~1 - URL
setlocal enabledelayedexpansion
for /f "tokens=1-26 delims=/" %%a in ("%~1") do (
    if [%%b]==[] set filename=!filename!%%a
    if [%%c]==[] set filename=!filename!%%b
    if [%%d]==[] set filename=!filename!%%c
    if [%%e]==[] set filename=!filename!%%d
    if [%%f]==[] set filename=!filename!%%e
    if [%%g]==[] set filename=!filename!%%f
    if [%%h]==[] set filename=!filename!%%g
    if [%%i]==[] set filename=!filename!%%h
    if [%%j]==[] set filename=!filename!%%i
    if [%%k]==[] set filename=!filename!%%j
    if [%%l]==[] set filename=!filename!%%k
    if [%%m]==[] set filename=!filename!%%l
    if [%%n]==[] set filename=!filename!%%m
    if [%%o]==[] set filename=!filename!%%n
    if [%%p]==[] set filename=!filename!%%o
    if [%%q]==[] set filename=!filename!%%p
    if [%%r]==[] set filename=!filename!%%q
    if [%%s]==[] set filename=!filename!%%r
    if [%%t]==[] set filename=!filename!%%s
    if [%%u]==[] set filename=!filename!%%t
    if [%%v]==[] set filename=!filename!%%u
    if [%%w]==[] set filename=!filename!%%v
    if [%%x]==[] set filename=!filename!%%w
    if [%%y]==[] set filename=!filename!%%x
    if [%%z]==[] set filename=!filename!%%y
)
ENDLOCAL & set _rv=%filename%
GOTO:EOF

:mktemp            -- create temporary file.  Return filename in _rv
::                 -- %1:  /D to create a directory, unset to create a file ending in .tmp
:: Shamelessly borrowed from the great Rob Vanderwoude at http://www.robvanderwoude.com/files/maketemp_nt.txt

SETLOCAL ENABLEDELAYEDEXPANSION
:Again
:: Use creation time as prefix
:: Note: spaces are replaced by zeroes, a bugfix by Michael Krailo
SET TempFile=~~%Time: =0%
:: Remove time delimiters
SET TempFile=%TempFile::=%
SET TempFile=%TempFile:.=%
SET TempFile=%TempFile:,=%
:: Create a really large random number and append it to the prefix
FOR /L %%A IN (0,1,2) DO SET TempFile=!TempFile!!Random!
:: If temp file with this name already exists, try again
IF EXIST "%Temp%.\%TempFile%" (
	GOTO Again
)
:: Retrieve the fully qualified path of the new temp file
FOR %%A IN ("%Temp%.\%TempFile%") DO SET TempFile=%%~fA
:: Return the fully qualified path of the new temp file
if [%1]==[] (
    TYPE NUL > "%TempFile%.tmp" || SET TempFile=
    set TempFile=%TempFile%.tmp
)
if [%1]==[/D] (
    mkdir "%TempFile%" || SET TempFile=
)
:: Retrieve the fully qualified path of the new temp file
FOR %%A IN ("%TempFile%") DO SET TempFile=%%~fA
:: Return the fully qualified path of the new temp file
ENDLOCAL & SET _rv=%TempFile%
:: Done
GOTO:EOF

:wget              -- like wget but implemented in vbscript
::                 -- %~1 - url to download
::                 -- %~2 - file to save to (optional)
SETLOCAL
call :mktemp
echo. > %_rv%.vbs
echo URL = WScript.Arguments(0)>> %_rv%.vbs
echo if WScript.Arguments.Count ^> 1 then>> %_rv%.vbs
echo   saveTo = WScript.Arguments(1)>> %_rv%.vbs
echo else>> %_rv%.vbs
echo   parts = split(url,"/") >> %_rv%.vbs
echo   saveTo = parts(ubound(parts))>> %_rv%.vbs
echo end if>> %_rv%.vbs
echo Set objXMLHTTP = CreateObject("MSXML2.ServerXMLHTTP")>> %_rv%.vbs
echo objXMLHTTP.open "GET", URL, false>> %_rv%.vbs
echo objXMLHTTP.send()>> %_rv%.vbs
echo If objXMLHTTP.Status = 200 Then>> %_rv%.vbs
echo Set objADOStream = CreateObject("ADODB.Stream")>> %_rv%.vbs
echo objADOStream.Open>> %_rv%.vbs
echo objADOStream.Type = 1 'adTypeBinary>> %_rv%.vbs
echo objADOStream.Write objXMLHTTP.ResponseBody>> %_rv%.vbs
echo objADOStream.Position = 0 >> %_rv%.vbs
echo Set objFSO = Createobject("Scripting.FileSystemObject")>> %_rv%.vbs
echo If objFSO.Fileexists(saveTo) Then objFSO.DeleteFile saveTo>> %_rv%.vbs
echo Set objFSO = Nothing>> %_rv%.vbs
echo objADOStream.SaveToFile saveTo>> %_rv%.vbs
echo objADOStream.Close>> %_rv%.vbs
echo Set objADOStream = Nothing>> %_rv%.vbs
echo End if>> %_rv%.vbs
echo Set objXMLHTTP = Nothing>> %_rv%.vbs
echo WScript.Quit>> %_rv%.vbs

call %_rv%.vbs %~1 %2

if %errorlevel% neq 0 (exit /b 1)
GOTO:EOF

:carobyRegistryFilename
set _rv=%TEMP%\caroby.bat
GOTO:EOF

:carobyRegistry    -- initialize variables for the local default caroby installation
if [%CAROBY_DIR%] neq [] (
    :: we're inside the caroby environment already
    GOTO:EOF
)
call :carobyRegistryFilename
set crfn=%_rv%
if exist "%crfn%" (
    call "%crfn%"
)
if [%CAROBY_DIR%] == [] (
    set _err=must initialize a caroby installation by first running %carobyRegistryFilename%
    exit /b 1
)
GOTO:EOF

:verifyInCarobyEnvironment
set _err=
if [%CAROBY_DIR%] == [] (
    set _err=must initialize a caroby installation by first running %carobyRegistryFilename%
)
GOTO:EOF

:shortInstallPath --return the relative install path for a package name
::              -- %1: package name
SETLOCAL
call :verifyInCarobyEnvironment
set _rv=packages\%1
ENDLOCAL&set _rv=%_rv%&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:installPath    -- return the full install path for a package name
::              -- %1: package name

SETLOCAL
call :verifyInCarobyEnvironment
call :shortInstallPath %1
set installDir=%CAROBY_DIR%\%_rv%
ENDLOCAL&set _rv=%installDir%&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:installPathRelative    -- return this package's path to its installation.  With %%CAROBY_DIR%% as the base.
::                      -- %1: package name
::use this for init scripts that need to access their relative location.  For install scripts use :installPath

SETLOCAL
call :verifyInCarobyEnvironment
call :shortInstallPath %1
set installDir=%%CAROBY_DIR%%\%_rv%
ENDLOCAL&set _rv=%installDir%&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:initPath    -- return this package's path to init
::           -- %1: package name

SETLOCAL
call :verifyInCarobyEnvironment
set _rv=%CAROBY_DIR%\init.d\%1
ENDLOCAL&set _rv=%_rv%&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:verifyPackageNotInstalled    -- fail with error message if package exists in caroby environment
::                            -- %1: package name

SETLOCAL
call :verifyInCarobyEnvironment
if "%_err%" neq "" exit /b 1
call :installPath %1
if exist "%_rv%" (
    set _err=package %1 already installed.  To refresh do
    set _err2=rmdir /s /q "%_rv%"
)
ENDLOCAL&set _err=%_err%&set _err2=%_err2%
if "%_err%" neq "" exit /b 1

SETLOCAL
call :initPath %1
if exist "%_rv%" (
    set _err=package %1 init files exist.  To refresh do
    set _err2=rmdir /s /q "%_rv%"
)
ENDLOCAL&set _err=%_err%&set _err2=%_err2%
if "%_err%" neq "" exit /b 1

GOTO:EOF

:verifyMD5Hash    -- verify cryptographic hash of the file
::                -- %~1  file to verify
::                -- %~2 md5 hash
fciv.exe 2>NUL 1>NUL
if %ERRORLEVEL%==9009 (
    echo WARNING:  MD5 sum not checked for file %~1
    exit /b 0
)
setlocal enabledelayedexpansion
set match=false
set sum=
for /f "tokens=1,2" %%a in ('fciv.exe "%~1"') do (
    if [%%a] neq [//] (
        set sum=%%a
        if [%%a] == [%~2] (
            set match=true
        )
    )
)
set _err=
if [%match%] neq [true] set _err=got MD5 sum of %sum% but expected %~2
endlocal&set _rv=&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF
