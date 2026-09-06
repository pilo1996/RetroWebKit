#!/bin/sh

set -u

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/.." && pwd)
failures=0

require_file()
{
    relative_path=$1
    if [ -f "$repo_root/$relative_path" ]; then
        echo "PASS $relative_path"
    else
        echo "FAIL $relative_path is missing" >&2
        failures=$((failures + 1))
    fi
}

verify_sha256()
{
    expected=$1
    relative_path=$2

    if [ ! -f "$repo_root/$relative_path" ]; then
        echo "FAIL $relative_path is missing" >&2
        failures=$((failures + 1))
        return
    fi

    if ! command -v shasum >/dev/null 2>&1; then
        echo "WARN shasum is unavailable; cannot verify $relative_path"
        return
    fi

    actual=$(shasum -a 256 "$repo_root/$relative_path" | sed -n '1s/[[:space:]].*//p')
    if [ "$actual" = "$expected" ]; then
        echo "PASS checksum $relative_path"
    else
        echo "FAIL checksum $relative_path" >&2
        echo "     expected $expected" >&2
        echo "     actual   $actual" >&2
        failures=$((failures + 1))
    fi
}

echo "RetroWebKit source verification"

require_file Source/JavaScriptCore/COPYING.LIB
require_file Source/WebCore/LICENSE-APPLE
require_file Source/WebKitLegacy/LICENSE
require_file Source/JavaScriptCore/assembler/MacroAssemblerPPC.h
require_file Source/ThirdParty/lz4/LICENSE
require_file Source/ThirdParty/ots/LICENSE
require_file Source/ThirdParty/ots/ots.xcodeproj/project.pbxproj
require_file WebKitLibraries/libWebKitSystemInterfaceLeopard.a
require_file Tools/Scripts/build-webkit

verify_sha256 e87a4ffbad7fafdfab759122875aee84434de3f51fc64c361fde30a109ecb69e Vendor/LeopardWebKit/Patches/604.5.6/WebKit_604.5.6.diff
verify_sha256 f9a9cd1e29a62e062cd2eb8da9012b7a0da0e77d585e0fc04bf7b54de9c769a4 Vendor/LeopardWebKit/Patches/604.5.6/Source/ThirdParty/ots/ots_604.5.6.diff
verify_sha256 081f88db983cf5446c802c822355395ff3f55eddd2826a0859d1d3d2ab46e46d Vendor/LeopardWebKit/Patches/604.5.6/Source/ThirdParty/lz4/lz4_604.5.6.diff

if find "$repo_root/Source" -type d -name .svn -print | sed -n '1p' | grep . >/dev/null 2>&1; then
    echo "FAIL Subversion working-copy metadata found under Source" >&2
    failures=$((failures + 1))
else
    echo "PASS no Subversion working-copy metadata"
fi

echo "failures=$failures"
exit "$failures"
