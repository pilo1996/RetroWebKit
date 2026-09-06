#!/bin/sh

set -u

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
artifacts_dir="$repo_root/Artifacts"
diagnostics_dir="$artifacts_dir/diagnostics"
mkdir -p "$diagnostics_dir"

if [ ! -f "$diagnostics_dir/system-info.txt" ] || [ ! -f "$diagnostics_dir/toolchain-info.txt" ]; then
    "$script_dir/bootstrap.sh" --target leopard --arch ppc
fi

if [ ! -f "$diagnostics_dir/test-results.txt" ]; then
    echo "Tests have not been run." > "$diagnostics_dir/test-results.txt"
fi

if [ ! -f "$diagnostics_dir/build.log" ]; then
    echo "No build has been run." > "$diagnostics_dir/build.log"
fi

if [ ! -f "$diagnostics_dir/compiler-errors.log" ]; then
    echo "No compiler error summary is available." > "$diagnostics_dir/compiler-errors.log"
fi

stamp=$(date +%Y%m%d-%H%M%S 2>/dev/null || echo unknown-date)
archive="$artifacts_dir/retrowebkit-diagnostics-$stamp.tar.gz"

(
    cd "$artifacts_dir" || exit 1
    tar -czf "$archive" diagnostics
)

echo "Created $archive"
echo "Send this archive back with the command that produced the failure."
