#!/usr/bin/env sh
set -eu

# Installs a RhinoJS launcher plus integrations for Sublime Text and VS Code.
# Usage:
#   ./install-rhino-editors.sh
#   ./install-rhino-editors.sh [project-folder]
#   ./install-rhino-editors.sh /path/to/rhino-all.jar [project-folder]

usage() {
  printf '%s\n' "Usage: $0 [project-folder]"
  printf '%s\n' "       $0 /path/to/rhino-all.jar [project-folder]"
  printf '%s\n' "Examples:"
  printf '%s\n' "  $0"
  printf '%s\n' "  $0 \"$PWD\""
  printf '%s\n' "  $0 /opt/rhino/rhino-all.jar \"$PWD\""
}

if [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

RHINO_VERSION=${RHINO_VERSION:-1.9.1}
RHINO_JAR=''
PROJECT_DIR=$PWD

case "$#" in
  0)
    ;;
  1)
    case "$1" in
      *.jar)
        RHINO_JAR=$1
        ;;
      *)
        PROJECT_DIR=$1
        ;;
    esac
    ;;
  2)
    RHINO_JAR=$1
    PROJECT_DIR=$2
    ;;
esac

if [ -n "$RHINO_JAR" ]; then
  if [ ! -f "$RHINO_JAR" ]; then
    printf 'ERROR: Rhino JAR not found: %s\n' "$RHINO_JAR" >&2
    exit 1
  fi
fi

if ! command -v java >/dev/null 2>&1; then
  printf '%s\n' 'ERROR: Java was not found in PATH. Install a JRE/JDK and try again.' >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  printf 'ERROR: Project folder not found: %s\n' "$PROJECT_DIR" >&2
  exit 1
fi

download_file() {
  url=$1
  output=$2

  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --connect-timeout 20 -o "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    printf '%s\n' 'ERROR: curl or wget is required to download RhinoJS automatically.' >&2
    exit 1
  fi
}

verify_sha256() {
  file=$1
  checksum_file=$2
  expected=$(awk '{print tolower($1); exit}' "$checksum_file")

  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print tolower($1)}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | awk '{print tolower($1)}')
  else
    printf '%s\n' 'ERROR: sha256sum or shasum is required to verify the RhinoJS download.' >&2
    exit 1
  fi

  if [ "$actual" != "$expected" ]; then
    rm -f "$file"
    printf '%s\n' 'ERROR: RhinoJS download failed SHA-256 verification.' >&2
    exit 1
  fi
}

test_rhino_jar() {
  jar=$1
  test_file=$(mktemp "${TMPDIR:-/tmp}/rhinojs-test.XXXXXX.js")
  trap 'rm -f "$test_file"' EXIT HUP INT TERM
  printf '%s\n' 'print("rhino-ok");' > "$test_file"
  output=$(java -cp "$jar" org.mozilla.javascript.tools.shell.Main "$test_file" 2>&1) || {
    printf '%s\n' "$output" >&2
    printf 'ERROR: RhinoJS runtime test failed for %s\n' "$jar" >&2
    exit 1
  }
  rm -f "$test_file"
  trap - EXIT HUP INT TERM
  case "$output" in
    *rhino-ok*)
      ;;
    *)
      printf '%s\n' "$output" >&2
      printf 'ERROR: RhinoJS runtime test did not produce the expected output for %s\n' "$jar" >&2
      exit 1
      ;;
  esac
}

if [ -z "$RHINO_JAR" ]; then
  RHINO_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
  RHINO_HOME="$RHINO_DATA_HOME/rhinojs"
  RHINO_JAR="$RHINO_HOME/rhino-all-$RHINO_VERSION.jar"
  RHINO_URL_BASE="https://repo.maven.apache.org/maven2/org/mozilla/rhino-all/$RHINO_VERSION/rhino-all-$RHINO_VERSION.jar"

  mkdir -p "$RHINO_HOME"
  if [ ! -f "$RHINO_JAR" ]; then
    printf 'Downloading RhinoJS %s...\n' "$RHINO_VERSION"
    tmp_jar="$RHINO_JAR.tmp"
    tmp_sha="$RHINO_JAR.sha256.tmp"
    rm -f "$tmp_jar" "$tmp_sha"
    download_file "$RHINO_URL_BASE" "$tmp_jar"
    download_file "$RHINO_URL_BASE.sha256" "$tmp_sha"
    verify_sha256 "$tmp_jar" "$tmp_sha"
    mv "$tmp_jar" "$RHINO_JAR"
    rm -f "$tmp_sha"
  fi
fi

test_rhino_jar "$RHINO_JAR"

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
