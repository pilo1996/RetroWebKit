#!/bin/sh

set -u

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
diagnostics_dir="$repo_root/Artifacts/diagnostics"
results="$diagnostics_dir/test-results.txt"
status_file="$diagnostics_dir/test-status.txt"
mkdir -p "$diagnostics_dir"

{
    echo "RetroWebKit bootstrap checks"
    echo "date=$(date 2>/dev/null || echo unavailable)"
    failures=0

    for file in README.md Documentation/Architecture.md Documentation/Toolchain.md Documentation/Roadmap.md Documentation/SourceProvenance.md Scripts/bootstrap.sh Scripts/build.sh Scripts/collect-logs.sh Scripts/verify-source.sh; do
        if [ -f "$repo_root/$file" ]; then
            echo "PASS $file"
        else
            echo "FAIL $file missing"
            failures=$((failures + 1))
        fi
    done

    for script in Scripts/bootstrap.sh Scripts/build.sh Scripts/collect-logs.sh Scripts/test.sh Scripts/verify-source.sh; do
        if sh -n "$repo_root/$script"; then
            echo "PASS syntax $script"
        else
            echo "FAIL syntax $script"
            failures=$((failures + 1))
        fi
    done

    echo "failures=$failures"
    echo "$failures" > "$status_file"
} 2>&1 | tee "$results"

failures=$(sed -n '1p' "$status_file")
exit "$failures"
