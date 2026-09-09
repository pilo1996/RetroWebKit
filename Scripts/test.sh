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

    for file in README.md Documentation/Architecture.md Documentation/Toolchain.md Documentation/Roadmap.md Documentation/SourceProvenance.md Scripts/bootstrap.sh Scripts/build.sh Scripts/collect-logs.sh Scripts/prepare-macports-gcc6.sh Scripts/verify-source.sh Tools/CompilerWrappers/gcc-mp Tools/CompilerWrappers/g++-mp Tools/CompilerWrappers/python Tools/CompilerWrappers/LeopardMathCompatibility.h Tools/CompilerWrappers/MacPortsHeaders/sqlite3.h; do
        if [ -f "$repo_root/$file" ]; then
            echo "PASS $file"
        else
            echo "FAIL $file missing"
            failures=$((failures + 1))
        fi
    done

    for script in Scripts/bootstrap.sh Scripts/build.sh Scripts/collect-logs.sh Scripts/prepare-macports-gcc6.sh Scripts/test.sh Scripts/verify-source.sh; do
        if sh -n "$repo_root/$script"; then
            echo "PASS syntax $script"
        else
            echo "FAIL syntax $script"
            failures=$((failures + 1))
        fi
    done

    for wrapper in Tools/CompilerWrappers/gcc-mp Tools/CompilerWrappers/g++-mp; do
        if perl -c "$wrapper" >/dev/null 2>&1; then
            echo "PASS syntax $wrapper"
        else
            echo "FAIL syntax $wrapper"
            failures=$((failures + 1))
        fi
    done

    if grep -q 'gcc6-v3-' "$repo_root/Tools/CompilerWrappers/gcc-mp" \
        && grep -q 'symlink($value, $destination)' "$repo_root/Tools/CompilerWrappers/gcc-mp" \
        && grep -q 'gcc6-v3-' "$repo_root/Tools/CompilerWrappers/g++-mp" \
        && grep -q 'symlink($value, $destination)' "$repo_root/Tools/CompilerWrappers/g++-mp"; then
        echo "PASS header-map overlays preserve header identity"
    else
        echo "FAIL header-map overlays do not preserve header identity"
        failures=$((failures + 1))
    fi

    compile_arguments=$(RETROWEBKIT_GXX=/bin/echo "$repo_root/Tools/CompilerWrappers/g++-mp" -c probe.cpp 2>/dev/null)
    link_arguments=$(RETROWEBKIT_GXX=/bin/echo "$repo_root/Tools/CompilerWrappers/g++-mp" probe.o 2>/dev/null)
    if echo "$compile_arguments" | grep -q 'LeopardMathCompatibility.h' \
        && ! echo "$link_arguments" | grep -q 'LeopardMathCompatibility.h'; then
        echo "PASS Leopard math compatibility is compile-only"
    else
        echo "FAIL Leopard math compatibility wrapper behavior"
        failures=$((failures + 1))
    fi

    if echo "$compile_arguments" | grep -q -- '-Wno-error=strict-aliasing' \
        && echo "$compile_arguments" | grep -q -- '-Wno-error=multichar' \
        && ! echo "$link_arguments" | grep -q -- '-Wno-error=strict-aliasing' \
        && ! echo "$link_arguments" | grep -q -- '-Wno-error=multichar'; then
        echo "PASS Leopard source-warning exceptions are compile-only"
    else
        echo "FAIL Leopard source-warning wrapper behavior"
        failures=$((failures + 1))
    fi

    if sh -n Tools/CompilerWrappers/python; then
        echo "PASS syntax Tools/CompilerWrappers/python"
    else
        echo "FAIL syntax Tools/CompilerWrappers/python"
        failures=$((failures + 1))
    fi

    if grep -q 'ENABLE_INTL=' "$repo_root/Scripts/build.sh"; then
        echo "PASS Leopard build disables unsupported modern ICU APIs"
    else
        echo "FAIL Leopard build does not disable unsupported modern ICU APIs"
        failures=$((failures + 1))
    fi

    if grep -q 'uidna_IDNToASCII' "$repo_root/Source/WebCore/platform/URLParser.cpp" \
        && grep -q 'uidna_IDNToUnicode' "$repo_root/Source/WebCore/platform/mac/WebCoreNSURLExtras.mm" \
        && grep -q 'IOPMAssertionCreate(assertionType' "$repo_root/Source/WebCore/platform/cocoa/SleepDisablerCocoa.cpp"; then
        echo "PASS Leopard WebCore uses legacy IDNA and power APIs"
    else
        echo "FAIL Leopard WebCore legacy API fallbacks missing"
        failures=$((failures + 1))
    fi

    if [ -f "$repo_root/WebKitLibraries/Growl.framework/Versions/A/Growl" ] \
        && [ -f "$repo_root/WebKitLibraries/Growl.framework/Versions/A/Headers/GrowlApplicationBridge.h" ] \
        && [ -f "$repo_root/WebKitLibraries/Growl-LICENSE.txt" ] \
        && grep -q '../../WebKitLibraries/Growl.framework' "$repo_root/Source/WebKitLegacy/WebKitLegacy.xcodeproj/project.pbxproj" \
        && grep -q 'FRAMEWORK_SEARCH_PATHS.*WebKitLibraries' "$repo_root/Source/WebKitLegacy/mac/Configurations/WebKitLegacy.xcconfig" \
        && grep -q '\[\[ -e.*WebKitPluginHost.app.*|| -h' "$repo_root/Source/WebKitLegacy/WebKitLegacy.xcodeproj/project.pbxproj"; then
        echo "PASS WebKitLegacy Growl dependency is vendored"
    else
        echo "FAIL WebKitLegacy Growl dependency is incomplete"
        failures=$((failures + 1))
    fi

    if grep -q 'ENABLE_DASHBOARD_SUPPORT=ENABLE_DASHBOARD_SUPPORT' "$repo_root/Scripts/build.sh" \
        && grep -q 'ENABLE_FULLSCREEN_API=ENABLE_FULLSCREEN_API' "$repo_root/Scripts/build.sh"; then
        echo "PASS Leopard derived-source features are explicit"
    else
        echo "FAIL Leopard derived-source feature overrides missing"
        failures=$((failures + 1))
    fi

    echo "failures=$failures"
    echo "$failures" > "$status_file"
} 2>&1 | tee "$results"

failures=$(sed -n '1p' "$status_file")
exit "$failures"
