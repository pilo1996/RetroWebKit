#!/bin/sh

set -u

usage()
{
    echo "usage: $0 [--target leopard] [--arch ppc|ppc7400|ppc970|i386]"
}

target=leopard
arch=ppc

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            target=$2
            shift 2
            ;;
        --arch)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            arch=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[ "$target" = leopard ] || {
    echo "error: only the leopard target is enabled during bootstrap" >&2
    exit 2
}

case "$arch" in
    ppc|ppc7400|ppc970|i386) ;;
    *)
        echo "error: unsupported architecture: $arch" >&2
        exit 2
        ;;
esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
diagnostics_dir="$repo_root/Artifacts/diagnostics"
mkdir -p "$diagnostics_dir"

system_log="$diagnostics_dir/system-info.txt"
toolchain_log="$diagnostics_dir/toolchain-info.txt"

{
    echo "RetroWebKit environment probe"
    echo "target=$target"
    echo "arch=$arch"
    echo "date=$(date 2>/dev/null || echo unavailable)"
    echo "uname=$(uname -a 2>/dev/null || echo unavailable)"
    echo "os_version=$(sw_vers -productVersion 2>/dev/null || echo unavailable)"
    echo "os_build=$(sw_vers -buildVersion 2>/dev/null || echo unavailable)"
    echo "machine=$(uname -m 2>/dev/null || echo unavailable)"
    echo "processor=$(uname -p 2>/dev/null || echo unavailable)"
} > "$system_log"

{
    echo "RetroWebKit toolchain probe"
    for tool in xcodebuild gcc g++ ruby python perl flex svn git make nm install_name_tool unifdef; do
        tool_path=$(command -v "$tool" 2>/dev/null || true)
        if [ -n "$tool_path" ]; then
            echo "$tool=$tool_path"
            "$tool" --version 2>&1 | sed -n '1,3p'
        else
            echo "$tool=MISSING"
        fi
    done
    if command -v xcodebuild >/dev/null 2>&1; then
        xcodebuild -version 2>&1 || true
        xcodebuild -showsdks 2>&1 || true
    fi
} > "$toolchain_log"

echo "Wrote $system_log"
echo "Wrote $toolchain_log"

if [ ! -x "$repo_root/Tools/Scripts/build-webkit" ]; then
    echo "Source baseline is not imported yet; build-webkit is unavailable."
    echo "See Documentation/SourceProvenance.md before importing it."
fi
