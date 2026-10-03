#!/bin/sh

set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/../.." && pwd)
log="$repo_root/Artifacts/RetroBrowser/smoke-test.log"
mkdir -p "$(dirname "$log")"
"$script_dir/build.sh"
"$script_dir/run.sh" >"$log" 2>&1 &
pid=$!
sleep 8
if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    echo "PASS RetroBrowser launched and remained alive"
    exit 0
fi
wait "$pid" || status=$?
echo "FAIL RetroBrowser exited during launch (status ${status:-0})" >&2
tail -n 50 "$log" >&2
exit 1
