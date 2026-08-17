#!/usr/bin/env sh
set -eu

# Installs a RhinoJS launcher plus integrations for Sublime Text and VS Code.
# Usage: ./install-rhino-editors.sh /path/to/js.jar [project-folder]

usage() {
  printf '%s\n' "Usage: $0 /path/to/js.jar [project-folder]"
  printf '%s\n' "Example: $0 /opt/rhino/js.jar \"$PWD\""
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

RHINO_JAR=$1
PROJECT_DIR=${2:-$PWD}

if [ ! -f "$RHINO_JAR" ]; then
  printf 'ERROR: Rhino JAR not found: %s\n' "$RHINO_JAR" >&2
  exit 1
fi

if ! command -v java >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: Java was not found in PATH. Install a JRE/JDK and try again.' >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  printf 'ERROR: Project folder not found: %s\n' "$PROJECT_DIR" >&2
  exit 1
fi

# Convert paths to absolute paths without requiring realpath.
RHINO_JAR_DIR=$(CDPATH= cd -- "$(dirname -- "$RHINO_JAR")" && pwd)
RHINO_JAR="$RHINO_JAR_DIR/$(basename -- "$RHINO_JAR")"
PROJECT_DIR=$(CDPATH= cd -- "$PROJECT_DIR" && pwd)

RHINO_BIN="$HOME/.local/bin"
RHINO_WRAPPER="$RHINO_BIN/rhino"
mkdir -p "$RHINO_BIN"

# Quote a path safely for embedding in the generated POSIX-shell launcher.
RHINO_JAR_QUOTED=$(printf '%s' "$RHINO_JAR" | sed "s/'/'\\\\''/g")
{
  printf '%s\n' '#!/usr/bin/env sh'
  printf "exec java -cp '%s' org.mozilla.javascript.tools.shell.Main \"\$@\"\n" "$RHINO_JAR_QUOTED"
} > "$RHINO_WRAPPER"
chmod 755 "$RHINO_WRAPPER"

case "$(uname -s)" in
  Darwin)
    SUBLIME_PACKAGES="$HOME/Library/Application Support/Sublime Text/Packages"
    ;;
  *)
    if [ -d "$HOME/.config/sublime-text-3/Packages" ] && [ ! -d "$HOME/.config/sublime-text/Packages" ]; then
      SUBLIME_PACKAGES="$HOME/.config/sublime-text-3/Packages"
    else
      SUBLIME_PACKAGES="$HOME/.config/sublime-text/Packages"
    fi
    ;;
esac

SUBLIME_USER="$SUBLIME_PACKAGES/User"
mkdir -p "$SUBLIME_USER"
cat > "$SUBLIME_USER/RhinoJS.sublime-build" <<EOF
{
  "cmd": ["$RHINO_WRAPPER", "\$file"],
  "working_dir": "\$file_path",
  "file_regex": "^js: \\"(.*?)\\", line ([0-9]+)",
  "selector": "source.js, source.javascript"
}
EOF

VSCODE_DIR="$PROJECT_DIR/.vscode"
mkdir -p "$VSCODE_DIR"
VSCODE_TASK="$VSCODE_DIR/tasks.json"
VSCODE_NOTE=''
if [ -e "$VSCODE_TASK" ]; then
  VSCODE_TASK="$VSCODE_DIR/tasks.rhino.example.json"
  VSCODE_NOTE='An existing tasks.json was preserved. Merge tasks.rhino.example.json into it.'
fi

cat > "$VSCODE_TASK" <<EOF
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "RhinoJS: Run current file",
      "type": "process",
      "command": "$RHINO_WRAPPER",
      "args": ["\${file}"],
      "options": { "cwd": "\${fileDirname}" },
      "problemMatcher": {
        "owner": "javascript",
        "fileLocation": ["absolute"],
        "pattern": {
          "regexp": "^js: \\"(.*?)\\", line ([0-9]+): (.*)\$",
          "file": 1,
          "line": 2,
          "message": 3
        }
      },
      "presentation": { "reveal": "always", "panel": "shared", "clear": true },
      "group": { "kind": "build", "isDefault": true }
    }
  ]
}
EOF

printf '\n%s\n' 'RhinoJS integration installed successfully.'
printf 'Launcher: %s\n' "$RHINO_WRAPPER"
printf '%s\n' 'Sublime Text: Tools > Build System > RhinoJS, then Ctrl+B (Cmd+B on macOS).'
printf '%s\n' 'VS Code: Terminal > Run Build Task, then select "RhinoJS: Run current file".'
if [ -n "$VSCODE_NOTE" ]; then
  printf 'NOTE: %s\n' "$VSCODE_NOTE"
fi
