@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Installs a RhinoJS launcher plus integrations for Sublime Text and VS Code.
rem Usage:
rem   install-rhino-editors.bat
rem   install-rhino-editors.bat [project-folder]
rem   install-rhino-editors.bat "C:\path\to\rhino-all.jar" [project-folder]

if not "%~3"=="" goto :usage

if "%RHINO_VERSION%"=="" set "RHINO_VERSION=1.9.1"
set "RHINO_JAR="
set "PROJECT_DIR=%CD%"

if not "%~1"=="" (
  if "%~2"=="" (
    if /I "%~x1"==".jar" (
      set "RHINO_JAR=%~f1"
    ) else (
      set "PROJECT_DIR=%~f1"
    )
  ) else (
    set "RHINO_JAR=%~f1"
    set "PROJECT_DIR=%~f2"
  )
)

where java.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Java was not found in PATH. Install a JRE/JDK and try again.
  exit /b 1
)

if defined RHINO_JAR (
  if not exist "%RHINO_JAR%" (
    echo ERROR: Rhino JAR not found: "%RHINO_JAR%"
    exit /b 1
  )
)

if not exist "%PROJECT_DIR%" (
  echo ERROR: Project folder not found: "%PROJECT_DIR%"
  exit /b 1
)

if not defined RHINO_JAR (
  call :download_rhino || exit /b 1
)

call :test_rhino || exit /b 1

set "RHINO_HOME=%LOCALAPPDATA%\RhinoJS"
set "RHINO_BIN=%RHINO_HOME%\bin"
set "RHINO_WRAPPER=%RHINO_BIN%\rhino.cmd"
if not exist "%RHINO_BIN%" mkdir "%RHINO_BIN%" || exit /b 1

> "%RHINO_WRAPPER%" echo @echo off
>>"%RHINO_WRAPPER%" echo java -cp "%RHINO_JAR%" org.mozilla.javascript.tools.shell.Main %%*

rem Sublime Text: prefer the current directory name, with a Sublime Text 3 fallback.
set "SUBLIME_PACKAGES=%APPDATA%\Sublime Text\Packages"
if not exist "%SUBLIME_PACKAGES%" if exist "%APPDATA%\Sublime Text 3\Packages" set "SUBLIME_PACKAGES=%APPDATA%\Sublime Text 3\Packages"
set "SUBLIME_USER=%SUBLIME_PACKAGES%\User"
if not exist "%SUBLIME_USER%" mkdir "%SUBLIME_USER%" || exit /b 1

set "RHINO_WRAPPER_JSON=%RHINO_WRAPPER:\=/%"
> "%SUBLIME_USER%\RhinoJS.sublime-build" echo {
>>"%SUBLIME_USER%\RhinoJS.sublime-build" echo   "cmd": ["%RHINO_WRAPPER_JSON%", "$file"],
>>"%SUBLIME_USER%\RhinoJS.sublime-build" echo   "working_dir": "$file_path",
>>"%SUBLIME_USER%\RhinoJS.sublime-build" echo   "file_regex": "^js: \"(.*?)\", line ([0-9]+)",
>>"%SUBLIME_USER%\RhinoJS.sublime-build" echo   "selector": "source.js, source.javascript"
>>"%SUBLIME_USER%\RhinoJS.sublime-build" echo }

rem VS Code: create tasks.json only when doing so cannot overwrite user settings.
set "VSCODE_DIR=%PROJECT_DIR%\.vscode"
if not exist "%VSCODE_DIR%" mkdir "%VSCODE_DIR%" || exit /b 1
set "VSCODE_TASK=%VSCODE_DIR%\tasks.json"
set "VSCODE_NOTE="
if exist "%VSCODE_TASK%" (
  set "VSCODE_TASK=%VSCODE_DIR%\tasks.rhino.example.json"
  set "VSCODE_NOTE=An existing tasks.json was preserved. Merge tasks.rhino.example.json into it."
)

> "%VSCODE_TASK%" echo {
>>"%VSCODE_TASK%" echo   "version": "2.0.0",
>>"%VSCODE_TASK%" echo   "tasks": [
>>"%VSCODE_TASK%" echo     {
>>"%VSCODE_TASK%" echo       "label": "RhinoJS: Run current file",
>>"%VSCODE_TASK%" echo       "type": "process",
>>"%VSCODE_TASK%" echo       "command": "%RHINO_WRAPPER_JSON%",
>>"%VSCODE_TASK%" echo       "args": ["${file}"],
>>"%VSCODE_TASK%" echo       "options": { "cwd": "${fileDirname}" },
>>"%VSCODE_TASK%" echo       "problemMatcher": {
>>"%VSCODE_TASK%" echo         "owner": "javascript",
>>"%VSCODE_TASK%" echo         "fileLocation": ["absolute"],
>>"%VSCODE_TASK%" echo         "pattern": {
>>"%VSCODE_TASK%" echo           "regexp": "^js: \"(.*?)\", line ([0-9]+): (.*)$",
>>"%VSCODE_TASK%" echo           "file": 1,
>>"%VSCODE_TASK%" echo           "line": 2,
>>"%VSCODE_TASK%" echo           "message": 3
>>"%VSCODE_TASK%" echo         }
>>"%VSCODE_TASK%" echo       },
>>"%VSCODE_TASK%" echo       "presentation": { "reveal": "always", "panel": "shared", "clear": true },
>>"%VSCODE_TASK%" echo       "group": { "kind": "build", "isDefault": true }
>>"%VSCODE_TASK%" echo     }
>>"%VSCODE_TASK%" echo   ]
>>"%VSCODE_TASK%" echo }

echo.
echo RhinoJS integration installed successfully.
echo Launcher: "%RHINO_WRAPPER%"
echo Sublime Text: Tools ^> Build System ^> RhinoJS, then Ctrl+B.
echo VS Code: Terminal ^> Run Build Task, then select "RhinoJS: Run current file".
if defined VSCODE_NOTE echo NOTE: %VSCODE_NOTE%
exit /b 0

:usage
echo Usage: %~nx0 [project-folder]
echo        %~nx0 "C:\path\to\rhino-all.jar" [project-folder]
echo Examples:
echo   %~nx0
echo   %~nx0 "C:\projects\my-rhino-project"
echo   %~nx0 "C:\tools\rhino\rhino-all.jar" "C:\projects\my-rhino-project"
exit /b 2

:download_rhino
set "RHINO_HOME=%LOCALAPPDATA%\RhinoJS"
if not exist "%RHINO_HOME%" mkdir "%RHINO_HOME%" || exit /b 1
set "RHINO_JAR=%RHINO_HOME%\rhino-all-%RHINO_VERSION%.jar"
if exist "%RHINO_JAR%" exit /b 0

echo Downloading RhinoJS %RHINO_VERSION%...
set "PS_SCRIPT=%TEMP%\rhinojs-download-%RANDOM%-%RANDOM%.ps1"
> "%PS_SCRIPT%" echo param([string]$Version, [string]$Jar)
>>"%PS_SCRIPT%" echo $ErrorActionPreference = 'Stop'
>>"%PS_SCRIPT%" echo $dir = Split-Path -Parent $Jar
>>"%PS_SCRIPT%" echo New-Item -ItemType Directory -Force -Path $dir ^| Out-Null
>>"%PS_SCRIPT%" echo $base = "https://repo.maven.apache.org/maven2/org/mozilla/rhino-all/$Version/rhino-all-$Version.jar"
>>"%PS_SCRIPT%" echo $tmpJar = "$Jar.tmp"
>>"%PS_SCRIPT%" echo $tmpSha = "$Jar.sha256.tmp"
>>"%PS_SCRIPT%" echo Remove-Item -Force -ErrorAction SilentlyContinue $tmpJar, $tmpSha
>>"%PS_SCRIPT%" echo Invoke-WebRequest -Uri $base -OutFile $tmpJar
>>"%PS_SCRIPT%" echo Invoke-WebRequest -Uri "$base.sha256" -OutFile $tmpSha
>>"%PS_SCRIPT%" echo $expected = ((Get-Content -Raw $tmpSha).Trim() -split '\s+')[0].ToLowerInvariant()
>>"%PS_SCRIPT%" echo $actual = (Get-FileHash -Algorithm SHA256 $tmpJar).Hash.ToLowerInvariant()
>>"%PS_SCRIPT%" echo if ($actual -ne $expected) { Remove-Item -Force -ErrorAction SilentlyContinue $tmpJar; throw "RhinoJS download failed SHA-256 verification." }
>>"%PS_SCRIPT%" echo Move-Item -Force $tmpJar $Jar
>>"%PS_SCRIPT%" echo Remove-Item -Force -ErrorAction SilentlyContinue $tmpSha
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -Version "%RHINO_VERSION%" -Jar "%RHINO_JAR%"
set "PS_EXIT=%ERRORLEVEL%"
del "%PS_SCRIPT%" >nul 2>&1
if not "%PS_EXIT%"=="0" exit /b %PS_EXIT%
exit /b 0

:test_rhino
set "RHINO_TEST=%TEMP%\rhinojs-test-%RANDOM%-%RANDOM%.js"
set "RHINO_TEST_OUT=%TEMP%\rhinojs-test-%RANDOM%-%RANDOM%.out"
> "%RHINO_TEST%" echo print("rhino-ok"^);
java -cp "%RHINO_JAR%" org.mozilla.javascript.tools.shell.Main "%RHINO_TEST%" >"%RHINO_TEST_OUT%" 2>&1
if errorlevel 1 (
  type "%RHINO_TEST_OUT%"
  del "%RHINO_TEST%" "%RHINO_TEST_OUT%" >nul 2>&1
  echo ERROR: RhinoJS runtime test failed for "%RHINO_JAR%"
  exit /b 1
)
findstr /C:"rhino-ok" "%RHINO_TEST_OUT%" >nul 2>&1
if errorlevel 1 (
  type "%RHINO_TEST_OUT%"
  del "%RHINO_TEST%" "%RHINO_TEST_OUT%" >nul 2>&1
  echo ERROR: RhinoJS runtime test did not produce the expected output for "%RHINO_JAR%"
  exit /b 1
)
del "%RHINO_TEST%" "%RHINO_TEST_OUT%" >nul 2>&1
exit /b 0
