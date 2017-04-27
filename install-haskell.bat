::::::::: Common ::::::::::::::::
@echo off
setlocal
pushd .
:::::::::::::::::::::::::::::::::
set version=8.0.2
set md5hash=a2a9652228739e4e40bf5adc5875638f
:::::::::::::::::::::::::::::::::

set haskellUrl=https://downloads.haskell.org/~platform/%version%/HaskellPlatform-%version%-full-x86_64-setup.exe
set packageName=haskell-%version%
::::::::::::::::::::::::::::::::
call :carobyRegistry || goto :error
call :verifyPackageNotInstalled %packageName% || goto :error

::download
pushd .
cd "%DOWNLOAD_DIR%
echo Downloading ^(may take a while^)
call :download %haskellUrl% || goto :error
set exeName=%_rv%
call :verifyMD5Hash "%CD%\%exeName%" %md5hash% || goto :error
popd

::unzipAndInstall
pushd .
call :mktemp /D
set tmpDir=%_rv%
cd "%tmpDir%"
copy "%DOWNLOAD_DIR%\%exeName%" . >nul
echo Extracting Haskell archive ^(may take a while^)
7z x -y "%exeName%" >nul || goto :error
7z x -y temp\GHC-setup.exe >nul || goto :error
7z x -y temp\Extralibs-setup.exe >nul || goto :error
del /f /q temp\GHC-setup.exe || goto :error
del /f /q temp\Extralibs-setup.exe || goto :error

call :installPath %packageName%
cd ..
move "%tmpDir%" "%_rv%"
echo done.
popd

::build init
call :initPath %packageName% || goto :error
mkdir "%_rv%"
set initName=%_rv%\haskell-init.bat
call :installPathRelative %packageName% || goto :error
set haskellDir=%_rv%
>"%initName%" echo @echo off
>>"%initName%" echo.
>>"%initName%" echo set PATH=%%PATH%%;%haskellDir%\bin;%haskellDir%\lib;%haskellDir%\lib\extralibs\bin;%haskellDir%\mingw\bin;%haskellDir%\code
>>"%initName%" echo set CABAL_CONFIG=%%USERPROFILE%%\.cabal\config

:: create a unix-like default cabal location ~/.cabal
:: rather than the roaming profile location, %APPDATA%\cabal
:createGoodCabalConfig
:: source in the haskell path
call "%initName%"
:: initialize ghc's local package database
ghc-pkg init "%GHC_PACKAGE_PATH%" || goto :error
:: then call cabal user-config diff to create the default file at ~/.cabal/config
echo Setting up cabal
cabal user-config diff || goto :error

:: now do the substitutions
call :installPath %packageName% || goto :error
set haskellPath=%_rv%
call :mktemp || goto :error
set tmpfile=%_rv%
call :mktemp || goto :error
set tmpfile2=%_rv%
call :mktemp || goto :error
set tmpfile3=%_rv%

set cabalDir=%USERPROFILE%\.cabal
set cabalConfig=%cabalDir%\config
set defaultCabalDir=%APPDATA%\cabal

:: replace all remaining roaming profile paths with ~/.cabal
call :replaceStringInFile "%cabalConfig%" "%tmpfile%" "%defaultCabalDir%" "%cabalDir%" || goto :error
:: now fix install-dirs global
call :replaceStringInFile "%tmpfile%" "%tmpfile2%" "-- prefix: c:\Program Files\Haskell" "   prefix: %haskellPath%" || goto :error
:: "" "" install-dirs user
call :replaceStringInFile "%tmpfile2%" "%tmpfile3%" "-- prefix: %cabalDir%" "   prefix: %cabalDir%" || goto :error
:: add logs-dir
call :replaceStringInFile "%tmpfile3%" "%cabalConfig%" "-- logs-dir: %cabalDir%" "logs-dir: %cabalDir%" || goto :error


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

:replaceStringInFile <inputfile> <outputfile> <oldstring> <newstring>
:: surround inputfile, outputfile, oldstring, and newstring in double quotes!
SETLOCAL
::obliterate output file
copy /y nul %2 >nul
:: now iterate through line by line, constructing line=<string_replacement_var>
:: and echoing it to target file
for /f "tokens=1,* delims=]" %%A in ('"type %1|find /n /v """') do (
    set "line=%%B"
    if defined line (
        call set "line=echo.%%line:%~3=%~4%%"
        for /f "delims=" %%X in ('"echo."%%line%%""') do %%~X >>%2
    ) ELSE echo.>>%2
)
ENDLOCAL
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
FOR /L %%A IN (0,1,9) DO SET TempFile=!TempFile!!Random!
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
::This only applies to oracle's java download
echo objXMLHTTP.setRequestHeader "Cookie", "oraclelicense=accept-securebackup-cookie">> %_rv%.vbs
echo objXMLHTTP.setRequestHeader "Cookie", "gpw_e24=http%%3A%%2F%%2Fwww.oracle.com%%2F">> %_rv%.vbs
::
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

:installPath    -- return the install path for a package name
::              -- %1: package name

SETLOCAL
call :verifyInCarobyEnvironment
set _rv=%CAROBY_DIR%\packages\%1
ENDLOCAL&set _rv=%_rv%&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:installPathRelative    -- return this package's path to its installation.  With %%CAROBY_DIR%% as the base.
::                      -- %1: package name
::use this for init scripts that need to access their relative location.  For install scripts use :installPath

SETLOCAL
call :verifyInCarobyEnvironment
set _rv=%%CAROBY_DIR%%\packages\%1
ENDLOCAL&set _rv=%_rv%&set _err=%_err%
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
