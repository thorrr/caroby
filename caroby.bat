@echo off
setlocal
pushd .

set CAROBY_DIR=%USERPROFILE%\caroby
set DOWNLOAD_DIR=%USERPROFILE%\Downloads

set PATH=%CAROBY_DIR%\bin;%PATH%

:argLoop
if [%1]==[] goto argEndLoop
  if [%1]==[/?] (
      echo Install caroby.
      echo.
      echo   Usage:
      echo     caroby [^<environment-path^>]
      echo     caroby [^<environment-path^>] /F
      echo     caroby [^<environment-path^>] /D ^<download-dir^>
      echo     caroby /?
      echo.
      echo   Options:
      echo     environment-path      parent directory of caroby environment [default:  %CAROBY_DIR%]
      echo     /D                    override download directory for internet packages [default:  %DOWNLOAD_DIR%]
      echo     /F                    force overwrite of existing environment path
      echo.    /?                    this help screen
      echo.
      exit /b
  )
  if [%1]==[/F] (
      set _FORCE=true
      goto argContinue
  )
  if [%1]==[/f] (
      set _FORCE=true
      goto argContinue
  )
  if [%1]==[/D] (
      set DOWNLOAD_DIR=%2
      shift
      goto argContinue
  )
  if [%1]==[/d] (
      set DOWNLOAD_DIR=%2
      shift
      goto argContinue
  )
  ::unamed argument
  set CAROBY_DIR=%~1
  exit /b
:argContinue
shift
goto argLoop
:argEndLoop

if not exist "%DOWNLOAD_DIR%" (
    echo ERROR:  download-dir %DOWNLOAD_DIR% doesn't exist.
    exit /b 1
)
if exist "%CAROBY_DIR%" (
    if [%_FORCE%] == [true] (
        echo %CAROBY_DIR% exists.  Doing force installation.
    ) else (
        echo %CAROBY_DIR% exists.  To force installation, use /F
        exit /b 1
    )
) else (
    echo Creating new caroby installation in %CAROBY_DIR%
)
:endArgs

:localState
call :carobyRegistryFilename
set CarobyRegistry="%_rv%"
>%CarobyRegistry%  echo set CAROBY_DIR=%CAROBY_DIR%
>>%CarobyRegistry% echo ::
>>%CarobyRegistry% echo set DOWNLOAD_DIR=%DOWNLOAD_DIR%
>>%CarobyRegistry% echo set PATH=%%CAROBY_DIR%%\bin;%%PATH%%

:createDirs
mkdir "%CAROBY_DIR%" 2>nul
mkdir "%CAROBY_DIR%\packages" 2>nul
mkdir "%CAROBY_DIR%\bin" 2>nul
mkdir "%CAROBY_DIR%\init.d" 2>nul

:createMakeShortcut
set _f="%CAROBY_DIR%\bin\mkshortcut.vbs"

>%_f%  echo 'create windows shortcuts from the command line
>>%_f% echo 'mkshortcut /target:TargetName /args:ArgumentString /shortcut:ShortcutName
>>%_f% echo 'example usage:
>>%_f% echo 'G:\^>mkshortcut.vbs /target:C:\Users\foobar\cygwin-env.bat
>>%_f% echo '                   /args:"^%%USERPROFILE^%%\emacs-24.3\bin\runemacs.exe" /shortcut:emacsnew
>>%_f% echo.
>>%_f% echo set WshShell = WScript.CreateObject("WScript.Shell" )
>>%_f% echo set oShellLink = WshShell.CreateShortcut(Wscript.Arguments.Named("shortcut") ^& ".lnk")
>>%_f% echo oShellLink.TargetPath = Wscript.Arguments.Named("target")
>>%_f% echo s = Wscript.Arguments.Named("args")
>>%_f% echo 'hilariously, VBS eats all double quotes in arguments even if they're escaped.  so we'll do our own escaping.
>>%_f% echo s = replace(s, "^%%", "%%")
>>%_f% echo s = replace(s, "^'", "'")
>>%_f% echo s = replace(s, "'", """")
>>%_f% echo oShellLink.Arguments = s
>>%_f% echo oShellLink.WindowStyle = 1
>>%_f% echo oShellLink.Save

set _f="%CAROBY_DIR%\make-shortcut.bat"

>%_f%  echo @echo off
>>%_f% echo setlocal
>>%_f% echo ::
>>%_f% echo pushd .
>>%_f% echo cd %%~dp0
>>%_f% echo set _DIR=%%CD%%\
>>%_f% echo set ARG=%%1
>>%_f% echo if [%%2]==[] (
>>%_f% echo     set SHORTCUT_NAME=%%~n1
>>%_f% echo ) else (
>>%_f% echo     set SHORTCUT_NAME=%%2
>>%_f% echo )
>>%_f% echo. 
>>%_f% echo ::strip out the current directory name from the argument, which is a full path
>>%_f% echo setlocal enabledelayedexpansion
>>%_f% echo set RELARG=!ARG:%%_DIR%%=!
>>%_f% echo %%_DIR%%\bin\mkshortcut.vbs /target:cmd /args:"/c bin\caroby-init.bat %%RELARG%%" /shortcut:"%%SHORTCUT_NAME%%"
>>%_f% echo endlocal
>>%_f% echo popd

:makeCarobyInit
set _f="%CAROBY_DIR%\bin\caroby-init.bat"
>%_f%  echo @echo off
>>%_f% echo pushd .
>>%_f% echo cd /d %%~dp0\..
>>%_f% echo set CAROBY_DIR=%%CD%%
>>%_f% echo popd
>>%_f% echo.
>>%_f% echo set PATH=%%CAROBY_DIR%%\bin;%%PATH%%
>>%_f% echo pushd .
>>%_f% echo cd "%%CAROBY_DIR%%\init.d"
>>%_f% echo :: first pick up global setup files
>>%_f% echo for %%%%v in ("*.bat") do call "%%%%~v"
>>%_f% echo.
>>%_f% echo :: then run package specific files.  must build a tmp batch file to overcome the setlocal barrier
>>%_f% echo set _f=%%TEMP%%\_.bat
>>%_f% echo ^>%%_f%% echo @echo off
>>%_f% echo.
>>%_f% echo setlocal enabledelayedexpansion
>>%_f% echo for /f "tokens=*" %%%%G in ('dir /b /s /a:d') do (
>>%_f% echo     set dir=%%%%G
>>%_f% echo     set ign=!dir:.ignore=!
>>%_f% echo     if [!dir!] == [!ign!] (
>>%_f% echo         cd "!dir!"
>>%_f% echo          for %%%%v in ("*.bat") do echo call "!dir!\%%%%~v"^>^> %%_f%%
>>%_f% echo      ) else (
>>%_f% echo         echo ignoring package !dir!
>>%_f% echo     )
>>%_f% echo )
>>%_f% echo endlocal
>>%_f% echo call %%_f%%
>>%_f% echo set _f=
>>%_f% echo popd
>>%_f% echo.
>>%_f% echo :: command line argument is command to run in the caroby environment.  run cmd.exe by default.
>>%_f% echo if [%%1] == [] (
>>%_f% echo      cmd.exe
>>%_f% echo      goto :end
>>%_f% echo )
>>%_f% echo. 
>>%_f% echo shift
>>%_f% echo start /b %%*
>>%_f% echo goto :end
>>%_f% echo. 
>>%_f% echo :end

:downloadandTestFCIV
:: download the checksum integrity tool from microsoft
:: this is potentially unsafe if your dns is spoofed because MS is using http rather than https
set fcivURL=http://download.microsoft.com/download/c/f/4/cf454ae0-a4bb-4123-8333-a1b6737712f7/Windows-KB841290-x86-ENU.exe
pushd .
cd "%DOWNLOAD_DIR%"
call :download %fcivURL% || goto :error
call :verifyMD5Hash "%exeName%" 58dc4df814685a165f58037499c89e76 || goto :error

set exeName=%_rv%
"%exeName%" /q /t:"%CAROBY_DIR%\bin\"
set PATH=%CAROBY_DIR%\bin;%PATH%
popd

:downloadAndInstall7Zip
set zipURL=http://www.7-zip.org/a/7z920.msi
pushd .
cd "%DOWNLOAD_DIR%"
call :download %zipURL% || goto :error
set installerName=%_rv%
call :verifyMD5Hash "%installerName%" 9bd44a22bffe0e4e0b71b8b4cf3a80e2 || goto :error
call :mktemp /D || goto :error
msiexec /a "%installerName%" TARGETDIR="%_rv%" /q
copy "%_rv%\Files\7-Zip\7z.dll" "%CAROBY_DIR%\bin\" > nul
copy "%_rv%\Files\7-Zip\7z.exe" "%CAROBY_DIR%\bin\" > nul
popd

:downloadAndInstallCurl
set curlURL=http://www.paehl.com/open_source/?download=curl_741_0_rtmp_ssh2_ssl_sspi.zip
pushd .
cd "%DOWNLOAD_DIR%"
call :download "%curlURL%" curl.zip || goto :error
call :verifyMD5Hash curl.zip ac7dc67ade0ffda67589cf082a2ed17d || goto :error
call :unzipFile "%CAROBY_DIR%\bin\" "%DOWNLOAD_DIR%\curl.zip" || goto :error
popd

:createCmdShortcut
bin\mkshortcut.vbs /target:cmd /args:"/c bin\caroby-init.bat" /shortcut:cmd 

:::::::::: End of script :::::::
:error
echo.
echo ERROR:  %_err%
if "%_err2%" neq "" echo %_err2%
echo.
popd
endlocal
exit /b -1

:end
endlocal
popd
GOTO:EOF
::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::::
:: Functions
::::::::::::::::::::::::::::::::::::::::::::::::::

:UnzipFile <ExtractTo> <newzipfile>
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

:download          -- download a file.  Skip with message if file already exists
::                 -- %~1 - URL
::                 -- %2 - filename (optional)
SETLOCAL
call :filenameFromURL "%~1"
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
    call :wget "%~1" "%filename%"
)
ENDLOCAL&set _rv=%filename%
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

call %_rv%.vbs "%~1" %2

if %errorlevel% neq 0 (exit /b 1)
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
if [%match%] neq [true] set _err=got MD5 sum of %sum% but expected %~2%
endlocal&set _rv=&set _err=%_err%
if "%_err%" neq "" exit /b 1
GOTO:EOF

:carobyRegistryFilename
set _rv=%TEMP%\caroby.bat
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
