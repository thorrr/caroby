::::::::: Common ::::::::::::::::
@echo off
setlocal
pushd .
:::::::::::::::::::::::::::::::::
set packageName=cygwin
:::::::::::::::::::::::::::::::::

set SETUPEXE=setup-x86_64.exe
:argLoop
if [%1]==[] goto argEndLoop
  if [%1]==[/?] (
      echo Install portable cygwin environment
      echo.
      echo %~nx0 [/32 ^| /64]
      echo.
      echo          defaults:  /64
      echo.
      echo   /32              install 32 bit cygwin
      echo   /64              install 64 bit cygwin
      exit /b
  )
  if [%1]==[/32] (
      echo. 
      echo 32bit installation selected
      set SETUPEXE=setup-x86.exe
      echo. 
      goto argContinue
  )
:argContinue
shift
goto argLoop
:argEndLoop

set SETUPURL=http://cygwin.com/%SETUPEXE%

:: actions start
call :carobyRegistry || goto :error
call :verifyPackageNotInstalled %packageName% || goto :error

call :installPath %packageName%
set CYGWIN_INSTALL_DIR=%_rv%

:checkForCleanup
set CYGWIN_SHORTCUT_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Cygwin
set CYGWIN_SHORTCUT_DIR_X=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Cygwin-X
if not exist "%CYGWIN_SHORTCUT_DIR%" (
    set _DO_SHORTCUT_CLEANUP=true
)
if not exist "%CYGWIN_SHORTCUT_DIR_X%" (
    set _DO_SHORTCUT_CLEANUP_X=true
)

pushd .
cd "%DOWNLOAD_DIR%
call :download %SETUPURL% || goto :error
popd

:postSetup
:: generate install script
call :mktemp || goto :error
set instFile=%_rv%.bat
>"%instFile%"  echo ::
>>"%instFile%" echo "%DOWNLOAD_DIR%\%SETUPEXE%" ^^
>>"%instFile%" echo --no-admin ^^
>>"%instFile%" echo --no-shortcuts ^^
>>"%instFile%" echo --no-startmenu ^^
>>"%instFile%" echo --no-desktop ^^
>>"%instFile%" echo --quiet-mode ^^
>>"%instFile%" echo --root "%CYGWIN_INSTALL_DIR%" ^^
>>"%instFile%" echo --local-package-dir "%DOWNLOAD_DIR%\cygwin-packages" ^^
>>"%instFile%" echo --site http://www.gtlib.gatech.edu/pub/cygwin/ ^^
>>"%instFile%" echo --packages ^^

:: how to generate an installed package list from an existing installation
:: sed -e '1d' -e 's/ .*$//' -e 's/$/,^/' /etc/setup/installed.db > installed-packages.txt
>>"%instFile%" type installed-packages.txt
>>"%instFile%" echo IF %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

call "%instFile%" >nul || goto :cyginstallerror
goto :aftercyginstall
:cyginstallerror
set _err=Error installing cygwin.  To see log do
set _err2=notepad "%CYGWIN_INSTALL_DIR%\var\log\setup.log.full"
goto :error
:aftercyginstall
 
:: copy setup.exe so we can update cygwin inside the caroby environment
copy "%DOWNLOAD_DIR%\%SETUPEXE%" "%CYGWIN_INSTALL_DIR%\"

:mkshortcuts
pushd .
cd /d %CAROBY_DIR%
:: create shortcuts for a bash shell
bin\mkshortcut.vbs /target:cmd /args:"/c bin\caroby-init.bat bash --login -i -c 'cd ~/; exec /bin/bash'" /shortcut:bash
popd

:mkscripts
:: build cygwin's init file
call :initPath %packageName% || goto :error
mkdir "%_rv%"
set fname="%_rv%\cygwin-init.bat"

call :installPathRelative %packageName% || goto :error
::cygdir has %%CAROBY_DIR%% in it
set cygdir=%_rv%

>"%fname%"  echo @echo off
>>"%fname%" echo.
>>"%fname%" echo set CYGBINPATH=%cygdir%\bin-extra
>>"%fname%" echo set PATH=%cygdir%\bin-extra;%cygdir%\bin;%cygdir%\usr\sbin;%cygdir%\shims;%%PATH%%
>>"%fname%" echo set IGNOREEOF=true
>>"%fname%" echo set DISPLAY=:0
>>"%fname%" echo set CYGWIN=nodosfilewarning
>>"%fname%" echo set _TD=%%TMP:\=/%%
>>"%fname%" echo :: you can do rm -rf /tmp because this is either cygwin's (empty) tmp dir or a symbolic link to Temp
>>"%fname%" echo bash -c 'rm -rf /tmp ^&^& ln -s "%%_TD%%" /tmp'
>>"%fname%" echo bash -c 'for d in `ls /cygdrive`; do if [ ! -e "/$d" ]; then ln -s /cygdrive/$d /; fi; done'
>>"%fname%" echo :: get rid of cygdrive prefix
>>"%fname%" echo :: bash -c 'mount -c / ^^^&^^^& mount -m ^^^> /etc/fstab'
>>"%fname%" echo :: make /etc/passwd and /etc/group work correctly
>>"%fname%" echo bash -c '/usr/bin/mkpasswd -l -p "$(/usr/bin/cygpath -H)" ^^^> /etc/passwd; /usr/bin/mkgroup -c ^^^> /etc/group'
>>"%fname%" echo :: reset HOME just in case
>>"%fname%" echo set HOME=%%USERPROFILE%%
>>"%fname%" echo :: make sure /home/USERNAME is mounted because ssh and other tools expect it.  any existing dir will be hidden
>>"%fname%" echo bash -c 'mount -f `cygpath -m "$HOME"` /home/$USERNAME ^^^&^^^& mount -m ^^^> /etc/fstab'

:: create the other cygwin bin path and put update-shims.bat into it
set cygbinpath=%CYGWIN_INSTALL_DIR%\bin-extra
mkdir "%cygbinpath%" 2>nul
set updateShims=%cygbinpath%\update-shims.bat

>"%updateShims%" echo @echo off
>>"%updateShims%" echo ^>"%%TMP%%\shim-with-convert-args.bat" echo @echo off
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo setlocal
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo pushd .
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _n=%%%%~n0
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo :argLoop
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo if [%%%%1]==[] goto argEndLoop
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _arg=%%%%1
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _argnoquotes=%%%%~1
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo if [%%%%_argnoquotes:~1,1%%%%] == [:] set _driveLetter=%%%%_argnoquotes:~0,1%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo if [%%%%_argnoquotes:~1,1%%%%] == [:] set _restofpath=%%%%_argnoquotes:~3%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo if [%%%%_argnoquotes:~1,1%%%%] == [:] set _restofpath=%%%%_restofpath:\=/%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo if not [%%%%_driveLetter%%%%] == [] set _arg=/cygdrive/%%%%_driveLetter%%%%/%%%%_restofpath%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _args=%%%%_args%%%% %%%%_arg%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo shift
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _arg=
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _argnoquotes=
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _driveLetter=
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _rop=
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set _restofpath=
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo goto argLoop
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo :argEndLoop
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo set __CWD=%%%%CD:\=/%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo bash --login -c 'cd %%%%__CWD%%%% ; %%%%_n%%%% $_args'
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo @rem %%%%_CYGPATH%%%%\bin\%%%%_n%%%% %%%%_args%%%%
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo.
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo endlocal
>>"%updateShims%" echo ^>^>"%%TMP%%\shim-with-convert-args.bat" echo popd
>>"%updateShims%" echo.
>>"%updateShims%" echo mkdir "%cygdir%\shims" ^>nul
>>"%updateShims%" echo FOR /f %%%%a IN ('dir /b /a %cygdir%\bin\* ^^^| findstr /vi ".exe$ .ico$ .dll$"') do (
>>"%updateShims%" echo    copy "%%TMP%%\shim-with-convert-args.bat" "%cygdir%\shims\%%%%a.bat" ^>nul
>>"%updateShims%" echo )

:: create update-apt-cyg.sh
set iac=%cygbinpath%\update-apt-cyg.sh
>"%iac%" echo #!/bin/bash
>>"%iac%" echo wget https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg -O "$CYGBINPATH/apt-cyg"

:: create install-fakecygpty and run it
set ifcpty=%cygbinpath%\install-fakecygpty.sh
>"%ifcpty%" echo #!/bin/bash
>>"%ifcpty%" echo cd /tmp
>>"%ifcpty%" echo wget https://raw.githubusercontent.com/d5884/fakecygpty/master/fakecygpty.c -O fakecygpty.c
>>"%ifcpty%" echo gcc -D_GNU_SOURCE -o fakecygpty fakecygpty.c
>>"%ifcpty%" echo cp fakecygpty.exe "$CYGBINPATH"
"%CYGWIN_INSTALL_DIR%\bin\bash" -c '/usr/bin/dos2unix $(/usr/bin/cygpath -u $cygbinpath/install-fakecygpty.sh)'
"%CYGWIN_INSTALL_DIR%\bin\bash" -c 'PATH=/usr/bin CYGBINPATH=$(/usr/bin/cygpath -u $cygbinpath) $(/usr/bin/cygpath -u $cygbinpath/install-fakecygpty.sh)'

:: create cygwin-list-installed-packages.bat
set clip=%cygbinpath%\cygwin-list-installed-packages.bat
>"%clip%" echo @echo off
>>"%clip%" echo.
>>"%clip%" echo bash -c "sed -e '1d' -e 's/ .*$//' -e 's/$/,^^/' /etc/setup/installed.db > installed-packages.txt"

:: download apt-cyg
pushd .
set APTCYGURL=https://raw.githubusercontent.com/transcode-open/apt-cyg/master/apt-cyg
cd "%cygbinpath%"
call :download %APTCYGURL% "%cygbinpath%\apt-cyg" || goto :error
"%CYGWIN_INSTALL_DIR%\bin\bash" -c '/usr/bin/dos2unix apt-cyg'
popd

:endmkscripts

:: call update-shims.bat once to set up our shims
call "%cygbinpath%\update-shims.bat"

:: make /etc/passwd and /etc/group work correctly
"%CYGWIN_INSTALL_DIR%\bin\bash" -c '/usr/bin/mkpasswd -l -p "$(/usr/bin/cygpath -H)" ^> /etc/passwd; /usr/bin/mkgroup -c ^> /etc/group'

:: get rid of start menu shortcuts
if [%_DO_SHORTCUT_CLEANUP%] == [true] (
    if exist "%CYGWIN_SHORTCUT_DIR%" (
        echo Removing shortcuts from start menu
        rmdir /s /q "%CYGWIN_SHORTCUT_DIR%"
    )
)
if [%_DO_SHORTCUT_CLEANUP_X%] == [true] (
    if exist "%CYGWIN_SHORTCUT_DIR_X%" (
        echo Removing XWindow shortcuts from start menu
        rmdir /s /q "%CYGWIN_SHORTCUT_DIR_X%"
    )
)

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
    call :wget %~1 "%filename%"
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
    set _err=must initialize a caroby installation by first running caroby.bat
    exit /b 1
)
GOTO:EOF

:verifyInCarobyEnvironment
set _err=
if [%CAROBY_DIR%] == [] (
    set _err=must initialize a caroby installation by first running caroby.bat
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
