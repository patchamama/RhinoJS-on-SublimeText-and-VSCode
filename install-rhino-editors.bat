@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Installs a RhinoJS launcher plus integrations for Sublime Text and VS Code.
rem Usage: install-rhino-editors.bat "C:\path\to\js.jar" [project-folder]

if "%~1"=="" goto :usage

set "RHINO_JAR=%~f1"
if not exist "%RHINO_JAR%" (
  echo ERROR: Rhino JAR not found: "%RHINO_JAR%"
  exit /b 1
)

where java.exe >nul 2>&1
if errorlevel 1 (
  echo ERROR: Java was not found in PATH. Install a JRE/JDK and try again.
  exit /b 1
)

if "%~2"=="" (
  set "PROJECT_DIR=%CD%"
) else (
  set "PROJECT_DIR=%~f2"
)

if not exist "%PROJECT_DIR%" (
  echo ERROR: Project folder not found: "%PROJECT_DIR%"
  exit /b 1
)

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
echo Usage: %~nx0 "C:\path\to\js.jar" [project-folder]
echo Example: %~nx0 "C:\tools\rhino\js.jar" "C:\projects\my-rhino-project"
exit /b 2
