# Known-good Leopard build

This record describes the first successful generic PowerPC build and browser
launch verification. It is evidence for M1, not yet the second clean-checkout
reproduction required to complete that milestone.

## Environment

```text
Mac OS X 10.5.8 (9L31a)
Power Macintosh
Xcode 3.1.4 (9M2809)
MacPorts GCC 6.3.0_0
Configuration: Release
Architecture: ppc
```

The build used `Scripts/build.sh` and its WebKitLegacy-only project selection.
The final Xcode results for all selected projects were `BUILD SUCCEEDED`.

## Runtime verification

The WebKit, WebCore, and JavaScriptCore framework executables were identified as
PowerPC Mach-O dynamic libraries. `Browser/RetroBrowser/build.sh` produced the
application bundle, and `Browser/RetroBrowser/smoke-test.sh` reported:

```text
PASS RetroBrowser launched and remained alive
```

## Artifact checksums

SHA-256 checksums from the verified build tree:

```text
a2104befc26ecd5ed59cda446590fc6e8ef5f5b2c4f558049ead5f58bad48111  WebKit.framework/Versions/A/WebKit
f6d1d9564cd5ff0b3816f6aec7e4e6325febdf80f09c640c56dc5d0fc8320eae  WebCore.framework/Versions/A/WebCore
cd03e78bcd5807a40e8810762ee452a7fc64bd2dabc75333665776fc2452e22c  JavaScriptCore.framework/Versions/A/JavaScriptCore
7f6e1d33cae8c03a38334fece8814c6ea6a3bd80bef5037cbc4033d015f3d7a6  RetroBrowser.app/Contents/MacOS/RetroBrowser
```

Framework checksums can legitimately change after source, compiler-wrapper, or
link-order changes. Reproducibility comparisons must use the same committed
source and documented toolchain.
