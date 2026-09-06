#!/bin/sh

set -eu

usage()
{
    echo "usage: $0 [--current-tree PATH]"
}

current_tree=/opt/local/var/macports/sources/rsync.macports.org/macports/release/tarballs/ports

while [ "$#" -gt 0 ]; do
    case "$1" in
        --current-tree)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            current_tree=$2
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

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
source_overlay="$repo_root/Tools/MacPortsOverlay/ports-2017-gcc6"
compatibility_patch="$repo_root/Tools/MacPortsOverlay/patches/macports-2.12-cpp-env.diff"
isl_patch="$repo_root/Tools/MacPortsOverlay/patches/use-compatible-isl14.diff"
generated_dir="$repo_root/Artifacts/macports"
work_overlay="$generated_dir/ports-2017-gcc6"
sources_conf="$generated_dir/sources.conf"
macports_conf="$generated_dir/macports.conf"

case "$repo_root$current_tree" in
    *" "*)
        echo "error: repository and current-tree paths must not contain spaces" >&2
        exit 2
        ;;
esac

[ -d "$source_overlay/lang/gcc6" ] || {
    echo "error: historical GCC 6 overlay is missing: $source_overlay" >&2
    exit 3
}

[ -d "$current_tree" ] || {
    echo "error: current MacPorts tree is missing: $current_tree" >&2
    echo "Run 'sudo port sync' first, or pass --current-tree PATH." >&2
    exit 3
}

portindex=$(command -v portindex 2>/dev/null || true)
[ -n "$portindex" ] || {
    echo "error: portindex is unavailable; install MacPorts first" >&2
    exit 3
}

mkdir -p "$work_overlay"
cp -R "$source_overlay"/. "$work_overlay"/
(
    cd "$work_overlay"
    /usr/bin/patch -p0 < "$compatibility_patch"
    /usr/bin/patch -p0 < "$isl_patch"
)
(
    cd "$work_overlay"
    "$portindex"
)

{
    echo "file://$work_overlay [nosync]"
    echo "file://$current_tree [default]"
} > "$sources_conf"

echo "sources_conf        $sources_conf" > "$macports_conf"

echo "Prepared the GCC 6.3 MacPorts overlay."
echo "Inspect the install plan with:"
echo "  PORTSRC=$macports_conf /opt/local/bin/port -y install gcc6"
echo "Install with:"
echo "  sudo env PORTSRC=$macports_conf /opt/local/bin/port install gcc6"
