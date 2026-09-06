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
verify_sha256 b22946ebb6e6a44dbe5d8c251e8d1c3802220c1358635d8b5fa0d1de3e33ef65 Tools/MacPortsOverlay/ports-2017-gcc6/lang/gcc6/Portfile
verify_sha256 6d2f0eaa4fe4beba0686b68102dc4ed3d829f912f66480e6b95a7e5c1f6185f6 Tools/MacPortsOverlay/ports-2017-gcc6/lang/gcc6/files/mp-gcc6
verify_sha256 cc7dfbd00c2eb94f76c1277e75a9769bdbfc75e7c7179ca3383741fa7ad03f1d Tools/MacPortsOverlay/ports-2017-gcc6/_resources/port1.0/group/compiler_blacklist_versions-1.0.tcl
verify_sha256 529be470b4262ccf0c4de2a25dcd59163c2bdef7c9852316b4dc9653efaa778e Tools/MacPortsOverlay/patches/macports-2.12-cpp-env.diff
verify_sha256 612555e8e256bac17977917bd227bfe8c466b085e810c4a1624d33af1f65f2c5 Tools/MacPortsOverlay/patches/use-compatible-isl14.diff
verify_sha256 6ee763245b63d5da8ea41d68c7d37cfb6f3cc7e57305399f6acba4c3e4158501 Tools/MacPortsOverlay/ports-2017-gcc6/lang/gcc6/files/patch-isl14-library.diff

if find "$repo_root/Source" -type d -name .svn -print | sed -n '1p' | grep . >/dev/null 2>&1; then
    echo "FAIL Subversion working-copy metadata found under Source" >&2
    failures=$((failures + 1))
else
    echo "PASS no Subversion working-copy metadata"
fi

echo "failures=$failures"
exit "$failures"
