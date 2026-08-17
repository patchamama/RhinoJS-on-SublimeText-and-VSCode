# RhinoJS on Sublime Text and VS Code

Run JavaScript files with [Mozilla Rhino](https://github.com/mozilla/rhino) directly from **Sublime Text** or **Visual Studio Code** on Windows, Linux, and macOS.

The installers verify the runtime, download RhinoJS when necessary, create a reusable command-line launcher, and configure both editors automatically.

## Features

- Automatic detection and installation of Java 17 or newer.
- Automatic download of `rhino-all` from Maven Central.
- SHA-256 verification and a runtime test of the downloaded JAR.
- Sublime Text Build System with file and line error matching.
- VS Code build task for the currently active JavaScript file.
- Existing `.vscode/tasks.json` files are preserved.
- Optional support for a custom Rhino JAR.
- No editor extensions are required.

## Quick installation

Open a terminal in the project where you want to create the VS Code task, then run the command for your operating system.

### Windows — PowerShell

```powershell
$f = Join-Path $env:TEMP 'install-rhino-editors.bat'; Invoke-WebRequest 'https://raw.githubusercontent.com/patchamama/RhinoJS-on-SublimeText-and-VSCode/main/install-rhino-editors.bat' -OutFile $f; & $f
```

### Linux or macOS

```bash
curl -fsSL https://raw.githubusercontent.com/patchamama/RhinoJS-on-SublimeText-and-VSCode/main/install-rhino-editors.sh | sh
```

If `curl` is unavailable but `wget` is installed:

```bash
wget -qO- https://raw.githubusercontent.com/patchamama/RhinoJS-on-SublimeText-and-VSCode/main/install-rhino-editors.sh | sh
```

> The installer may request administrator privileges when Java or another system dependency must be installed.

## Manual installation

```bash
git clone https://github.com/patchamama/RhinoJS-on-SublimeText-and-VSCode.git
cd RhinoJS-on-SublimeText-and-VSCode
```

### Windows

Install for the current directory:

```bat
install-rhino-editors.bat
```

Install the VS Code task in another project:

```bat
install-rhino-editors.bat "C:\projects\my-rhino-project"
```

Use an existing Rhino JAR:

```bat
install-rhino-editors.bat "C:\tools\rhino\rhino-all.jar" "C:\projects\my-rhino-project"
```

### Linux or macOS

```bash
chmod +x install-rhino-editors.sh
./install-rhino-editors.sh
```

Install the VS Code task in another project:

```bash
./install-rhino-editors.sh ~/projects/my-rhino-project
```

Use an existing Rhino JAR:

```bash
./install-rhino-editors.sh /opt/rhino/rhino-all.jar ~/projects/my-rhino-project
```

## What the installer does

1. Detects Java and verifies that its major version is at least 17.
2. If necessary, installs OpenJDK/Temurin using an available package manager.
3. Downloads RhinoJS `rhino-all` from Maven Central unless a custom JAR was provided.
4. Verifies the download checksum and executes a small RhinoJS runtime test.
5. Creates a local `rhino` launcher.
6. Creates the Sublime Text Build System.
7. Creates the VS Code task inside the selected project.

The default Rhino version can be overridden on Linux or macOS:

```bash
RHINO_VERSION=1.9.1 ./install-rhino-editors.sh
```

## Running JavaScript

Create or open a JavaScript file:

```javascript
print("Hello from RhinoJS!");
```

### Sublime Text

1. Open **Tools → Build System → RhinoJS**.
2. Open the JavaScript file you want to execute.
3. Press <kbd>Ctrl</kbd> + <kbd>B</kbd>, or <kbd>Cmd</kbd> + <kbd>B</kbd> on macOS.

### Visual Studio Code

1. Open the configured project folder.
2. Open the JavaScript file you want to execute.
3. Press <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>B</kbd>.
4. Select **RhinoJS: Run current file** if VS Code asks for a task.

You can also use **Terminal → Run Build Task**.

## Installed files

| Platform | Component | Location |
| --- | --- | --- |
| Windows | RhinoJS JAR | `%LOCALAPPDATA%\RhinoJS\lib` |
| Windows | Launcher | `%LOCALAPPDATA%\RhinoJS\bin\rhino.cmd` |
| Windows | Sublime Build System | `%APPDATA%\Sublime Text\Packages\User\RhinoJS.sublime-build` |
| Linux/macOS | RhinoJS JAR | `~/.local/share/rhinojs` |
| Linux/macOS | Launcher | `~/.local/bin/rhino` |
| Linux | Sublime Build System | `~/.config/sublime-text/Packages/User/RhinoJS.sublime-build` |
| macOS | Sublime Build System | `~/Library/Application Support/Sublime Text/Packages/User/RhinoJS.sublime-build` |
| All platforms | VS Code task | `<project>/.vscode/tasks.json` |

If `.vscode/tasks.json` already exists, the installer creates `.vscode/tasks.rhino.example.json` instead of overwriting it. Copy the generated task object into the existing `tasks` array.

## Dependency installation support

The Linux/macOS installer supports `apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`, and Homebrew. The Windows installer tries `winget`, Chocolatey, and Scoop, in that order.

Sublime Text and VS Code themselves are not installed. You only need the editor or editors that you intend to use.

## Troubleshooting

### `Java 17 or newer was not found`

Install a Java 17 or Java 21 runtime, open a new terminal, and run the installer again:

```bash
java -version
```

### Rhino task does not appear in VS Code

Check whether the installer created `.vscode/tasks.rhino.example.json`. This happens when the project already contains `.vscode/tasks.json`; merge the generated task into the existing file.

### Sublime Text does not show RhinoJS

Restart Sublime Text and select **Tools → Build System → RhinoJS**. Also verify that the generated `RhinoJS.sublime-build` file is in the platform-specific directory listed above.

### Testing the launcher directly

Windows:

```bat
"%LOCALAPPDATA%\RhinoJS\bin\rhino.cmd" example.js
```

Linux or macOS:

```bash
~/.local/bin/rhino example.js
```

## Security notes

- RhinoJS is downloaded over HTTPS from Maven Central.
- The downloaded file is checked against Maven Central's SHA-256 checksum.
- The Rhino shell can read files and execute Java-integrated code. Only run JavaScript files that you trust.
- Review remote installation scripts before piping them into a shell if required by your security policy.

## License

This integration project can be distributed under the license selected by its repository owner. Mozilla Rhino is licensed separately under the [Mozilla Public License 2.0](https://github.com/mozilla/rhino/blob/master/LICENSE.txt).
