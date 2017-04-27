::::::::: Common ::::::::::::::::
@echo off
setlocal
pushd .
:: User modifiable ::::::::::::::
set PYTHON_VERSION=2.7.12
set md5sum_x64=8fa13925db87638aa472a3e794ca4ee3
set md5sum_x32=4ba2c79b103f6003bc4611c837a08208
:::::::::::::::::::::::::::::::::

:checkForCleanup
if not exist "%PYTHON_START_MENU_LOCATION%" (
    set _DO_SHORTCUT_CLEANUP=true
)

set bits=.amd64
set arch=_x64
set md5sum=%md5sum_x64%
:argLoop
if [%1]==[] goto argEndLoop
  if [%1]==[/?] (
      echo Install %packageName%
      echo.
      echo %~nx0 [/32 ^| /64]
      echo.
      echo          defaults:  /64
      echo.
      echo   /32              install 32 bit
      echo   /64              install 64 bit
      exit /b
  )
  if [%1]==[/32] (
      echo.
      echo 32bit installation selected
      echo.
      set bits=
      set arch=_x86
      set md5sum=%md5sum_x32%
      goto argContinue
  )
:argContinue
shift
goto argLoop
:argEndLoop

set PYTHON_MAJOR_VERSION=%PYTHON_VERSION:~-0,-2%
set PYTHON_START_MENU_LOCATION=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Python %PYTHON_MAJOR_VERSION%
set packageName=python-%PYTHON_VERSION%%arch%

set URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%%bits%.msi

call :carobyRegistry || goto :error
call :verifyPackageNotInstalled %packageName% || goto :error

::downloadAndInstall
pushd .
cd "%DOWNLOAD_DIR%
call :download %URL% || goto :error
set msiFile=%_rv%
call :verifyMD5Hash "%CD%\%msiFile%" %md5sum% || goto :error

call :installPath %packageName%
set installDir=%_rv%
echo Installing...
msiexec /a "%msiFile%" TARGETDIR="%installDir%" /q
echo Done.
popd

::shortcutCleanup
if [%_DO_SHORTCUT_CLEANUP%] == [%_DO_SHORTCUT_CLEANUP%] (
    if exist "%PYTHON_START_MENU_LOCATION%" (
        del /q "%PYTHON_START_MENU_LOCATION%"
        rmdir /s /q "%PYTHON_START_MENU_LOCATION%"
    )
)

::build init
call :initPath %packageName% || goto :error
mkdir "%_rv%"
set initName=%_rv%\python-init.bat
call :installPathRelative %packageName% || goto :error
set pythonDir=%_rv%
>"%initName%" echo @echo off
>>"%initName%" echo.
>>"%initName%" echo set PATH=%pythonDir%;%pythonDir%\Scripts;%%PATH%%
:: we need PYTHON_DIR to support relocate-python.bat
>>"%initName%" echo set PYTHON_DIR=%pythonDir%
>>"%initName%" echo set TCL_LIBRARY=%pythonDir%\tcl\tcl8.5
>>"%initName%" echo set TK_LIBRARY=%pythonDir%\tcl\tk8.5
>>"%initName%" echo.
>>"%initName%" echo call %%CAROBY_DIR%%\bin\relocate-python.bat

::setupTools
set oldPRV=%PIP_REQUIRE_VIRTUALENV%
set PIP_REQUIRE_VIRTUALENV=
pushd .
cd "%DOWNLOAD_DIR%"
call :download https://bootstrap.pypa.io/get-pip.py || goto :error
call :verifyMD5Hash "%CD%\get-pip.py" 3b74f5cd0740a05802a23b019ce579a3 || goto :error
"%installDir%\python.exe" get-pip.py || goto :error
"%installDir%\Scripts\pip.exe" install virtualenv || goto :error
::finally, install pywin32
"%installDir%\Scripts\pip.exe" install pypiwin32 || goto :error
copy get-pip.py "%installDir%\Scripts" >nul || goto :error

set PIP_REQUIRE_VIRTUALENV=%oldPRV%
popd.

::create relocate-python.bat
set rpbat=%CAROBY_DIR%\bin\relocate-python.bat
>"%rpbat%" echo @echo off
>>"%rpbat%" echo.
>>"%rpbat%" echo setlocal
>>"%rpbat%" echo pushd .
>>"%rpbat%" echo :: easy_install, virtualenv, and pip all have hardcoded paths when they're installed.
>>"%rpbat%" echo :: If you relocate your devEnvironment you have to reinstall them.
>>"%rpbat%" echo cd "%%PYTHON_DIR%%"
>>"%rpbat%" echo set pycdir=Lib
>>"%rpbat%" echo if exist Lib\__pycache__ set pycdir=Lib\__pycache__
>>"%rpbat%" echo.
>>"%rpbat%" echo set _VAR_SET=0
>>"%rpbat%" echo FOR /F "tokens=3" %%%%G IN ('%%WINDIR%%\System32\find.exe /C /I "%%PYTHON_DIR%%" %%pycdir%%\os*.pyc') do (
>>"%rpbat%" echo     set _VAR_SET=%%%%G
>>"%rpbat%" echo )
>>"%rpbat%" echo.
>>"%rpbat%" echo if [%%_VAR_SET%%] == [0] (
>>"%rpbat%" echo     :: didn't find a string with the python dir in our compiled .pyc file
>>"%rpbat%" echo     echo Relocating python to %%PYTHON_DIR%%
>>"%rpbat%" echo     set PIP_REQUIRE_VIRTUALENV=
>>"%rpbat%" echo     python.exe Scripts\get-pip.py --force-reinstall ^>nul
>>"%rpbat%" echo     pip.exe install -U --force-reinstall virtualenv ^>nul
>>"%rpbat%" echo     pip.exe install -U --force-reinstall setuptools ^>nul
>>"%rpbat%" echo.
>>"%rpbat%" echo     :: system .pyc all have hardcoded paths too
>>"%rpbat%" echo     del /S /Q %%pycdir%%\*.pyc ^>nul
>>"%rpbat%" echo     :: force regeneration of os.pyc
>>"%rpbat%" echo     python.exe -c "import os"
>>"%rpbat%" echo )
>>"%rpbat%" echo.
>>"%rpbat%" echo popd
>>"%rpbat%" echo endlocal

:: optional - disable pip outside of virtualenvs but give an escape hatch with "gpip"
>>"%initName%" echo set PIP_REQUIRE_VIRTUALENV=true

set gpipbat=%CAROBY_DIR%\bin\gpip.bat
>"%gpipbat%" echo @echo off
>>"%gpipbat%" echo.
>>"%gpipbat%" echo setlocal
>>"%gpipbat%" echo set PIP_REQUIRE_VIRTUALENV=
>>"%gpipbat%" echo pip %%*
>>"%gpipbat%" echo endlocal

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
