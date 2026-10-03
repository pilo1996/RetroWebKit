#!/bin/sh

set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(CDPATH= cd "$script_dir/../.." && pwd)
configuration=${CONFIGURATION:-Release}
framework_dir=${RETROWEBKIT_FRAMEWORK_DIR:-"$repo_root/WebKitBuild/$configuration"}
output_dir="$repo_root/Artifacts/RetroBrowser/$configuration"
app="$output_dir/RetroBrowser.app"
contents="$app/Contents"

if [ ! -f "$framework_dir/WebKit.framework/Versions/A/WebKit" ]; then
    echo "error: build WebKitLegacy first; framework not found in $framework_dir" >&2
    exit 1
fi

mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Frameworks"
cp "$script_dir/Info.plist" "$contents/Info.plist"
if [ -d "$repo_root/WebKitLibraries/Growl.framework" ]; then
    rm -rf "$contents/Frameworks/Growl.framework"
    cp -R "$repo_root/WebKitLibraries/Growl.framework" "$contents/Frameworks/Growl.framework"
fi
compiler=${CC:-/usr/bin/gcc-4.2}
"$compiler" -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk \
    -mmacosx-version-min=10.5 -std=gnu99 -Wall -Wextra \
    -F"$framework_dir" -I"$framework_dir/WebKit.framework/Versions/A/PrivateHeaders" \
    -framework Cocoa -framework WebKit \
    "$script_dir/main.m" "$script_dir/RetroBrowserAppDelegate.m" \
    -o "$contents/MacOS/RetroBrowser"
echo "Built $app"
