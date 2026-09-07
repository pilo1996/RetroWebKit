#!/bin/sh

set -u

usage()
{
    echo "usage: $0 --target leopard --arch ppc|ppc7400|ppc970|i386 --configuration debug|release"
}

target=
arch=
configuration=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target|--arch|--configuration)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            option=$1
            value=$2
            case "$option" in
                --target) target=$value ;;
                --arch) arch=$value ;;
                --configuration) configuration=$value ;;
            esac
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

[ "$target" = leopard ] || { echo "error: only target 'leopard' is currently enabled" >&2; exit 2; }
case "$arch" in ppc|ppc7400|ppc970|i386) ;; *) echo "error: unsupported architecture: $arch" >&2; exit 2 ;; esac
case "$configuration" in debug|release) ;; *) echo "error: configuration must be debug or release" >&2; exit 2 ;; esac

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
build_script="$repo_root/Tools/Scripts/build-webkit"
compiler_wrappers="$repo_root/Tools/CompilerWrappers"
diagnostics_dir="$repo_root/Artifacts/diagnostics"
mkdir -p "$diagnostics_dir"

if [ ! -x "$build_script" ]; then
    echo "error: $build_script is missing; the reviewed WebKit baseline has not been imported" >&2
    exit 3
fi

"$script_dir/bootstrap.sh" --target "$target" --arch "$arch"

build_log="$diagnostics_dir/build.log"
compiler_log="$diagnostics_dir/compiler-errors.log"
status_file="$diagnostics_dir/build-status.txt"

echo "Building target=$target arch=$arch configuration=$configuration"
echo "Full output: $build_log"
echo "1" > "$status_file"

(
    cd "$repo_root" || exit 1
    if [ -x /opt/local/bin/gcc-mp-6 ] && [ -x /opt/local/bin/g++-mp-6 ] && [ -x /opt/local/bin/python2.7 ]; then
        PATH="$compiler_wrappers:$PATH"
        export PATH
        "$build_script" "--$configuration" ARCHS="$arch" ONLY_ACTIVE_ARCH=NO \
            GCC_VERSION=4.2 \
            CC="$compiler_wrappers/gcc-mp" \
            CPLUSPLUS="$compiler_wrappers/g++-mp" \
            LDPLUSPLUS="$compiler_wrappers/g++-mp"
    else
        echo "error: MacPorts GCC 6.3 and Python 2.7 are required" >&2
        echo "Run ./Scripts/prepare-macports-gcc6.sh and install gcc6 and python27 first." >&2
        exit 3
    fi
    echo "$?" > "$status_file"
) 2>&1 | tee "$build_log"

if [ -r "$status_file" ]; then
    status=$(sed -n '1p' "$status_file")
else
    status=1
fi

# PIPESTATUS is a Bash feature and is absent from Leopard's /bin/sh. Recover the
# most useful diagnostic portably; build-webkit failures are also extracted below.
rg_command=$(command -v rg 2>/dev/null || true)
if [ -n "$rg_command" ]; then
    "$rg_command" -i "(^|[^a-z])(error:|fatal error:|build failed|command .* failed)" "$build_log" > "$compiler_log" || true
else
    grep -Ei "(^|[^a-z])(error:|fatal error:|build failed|command .* failed)" "$build_log" > "$compiler_log" || true
fi

if [ "$status" -ne 0 ] || grep -Eq "BUILD FAILED|Build failed|fatal error:| error:" "$build_log"; then
    echo "Build appears to have failed. Run ./Scripts/collect-logs.sh" >&2
    exit 1
fi

echo "Build command completed. Review $build_log for warnings."
