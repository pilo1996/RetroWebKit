#!/bin/sh

set -u

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
diagnostics_dir="$repo_root/Artifacts/diagnostics"
state_file="$diagnostics_dir/build-state.txt"
status_file="$diagnostics_dir/build-status.txt"
build_log="$diagnostics_dir/build.log"

build_processes=$(ps axww 2>/dev/null | grep -E '[b]uild-webkit|[x]codebuild' || true)
if [ -n "$build_processes" ]; then
    echo "BUILD IN CORSO"
    echo "$build_processes"
    exit 0
fi

state=unknown
if [ -r "$state_file" ]; then
    state=$(sed -n '1p' "$state_file")
fi

case "$state" in
    succeeded)
        echo "BUILD TERMINATA CON SUCCESSO"
        exit 0
        ;;
    failed)
        echo "BUILD TERMINATA CON ERRORE"
        [ -r "$build_log" ] && tail -40 "$build_log"
        exit 1
        ;;
    running)
        echo "BUILD INTERROTTA: non ci sono processi attivi ma lo stato e' ancora running"
        [ -r "$build_log" ] && tail -40 "$build_log"
        exit 2
        ;;
esac

# Compatibility with build directories created before build-state.txt existed.
if [ -r "$status_file" ] && [ "$(sed -n '1p' "$status_file")" = "0" ]; then
    echo "BUILD TERMINATA CON SUCCESSO"
    exit 0
fi

echo "STATO BUILD SCONOSCIUTO"
[ -r "$build_log" ] && tail -40 "$build_log"
exit 2
