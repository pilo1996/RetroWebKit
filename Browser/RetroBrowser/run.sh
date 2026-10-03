#!/bin/sh

set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/../.." && pwd)
configuration=${CONFIGURATION:-Release}
framework_dir=${RETROWEBKIT_FRAMEWORK_DIR:-"$repo_root/WebKitBuild/$configuration"}
app="$repo_root/Artifacts/RetroBrowser/$configuration/RetroBrowser.app"
[ -x "$app/Contents/MacOS/RetroBrowser" ] || "$script_dir/build.sh"
DYLD_FRAMEWORK_PATH="$framework_dir${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
export DYLD_FRAMEWORK_PATH
exec "$app/Contents/MacOS/RetroBrowser" "$@"
