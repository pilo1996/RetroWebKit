# RetroWebKit

RetroWebKit is an effort to build a small, native browser for classic Mac OS X
around the last Leopard WebKit 604 release. The first target is Mac OS X 10.5.8
on PowerPC; Leopard i386 follows, and Tiger support is deliberately deferred.

## Status

The repository is in its bootstrap and source-provenance phase. No WebKit engine
source has been imported yet. The intended baseline is the upstream WebKit tag
`Safari-604.5.6` plus the Leopard WebKit `Patches_604.5.6` patch set.

The `_2` suffix in the final Leopard WebKit binary release describes a later
packaging/stability release. SourceForge exposes `Patches_604.5.6.tar.bz2`, not a
separate `_2` engine patch archive.

## First build target

```text
Mac OS X 10.5.8
PowerPC (32-bit)
WebKitLegacy / WebView
Release configuration
```

## Repository layout

- `Browser/RetroBrowser/` — the future minimal Cocoa browser shell.
- `Compat/` — isolated Leopard, Tiger, and PowerPC compatibility work.
- `Documentation/` — architecture, provenance, toolchain, and roadmap notes.
- `Scripts/` — environment checks, builds, tests, and diagnostic collection.
- `Source/` — reserved for the reviewed WebKit source baseline.

## Current commands

On a target Mac, inspect the environment with:

```sh
./Scripts/bootstrap.sh --target leopard --arch ppc
```

After the source baseline is imported, build it with:

```sh
./Scripts/build.sh --target leopard --arch ppc --configuration release
```

If a build fails, collect the reproducible diagnostics with:

```sh
./Scripts/collect-logs.sh
```

See [Documentation/Toolchain.md](Documentation/Toolchain.md) before installing or
replacing any compiler tools on Leopard.

## Scope

RetroWebKit initially uses WebKitLegacy in a single-process native Cocoa shell.
WebKit2, a multiprocess architecture, Tiger shims, and forward-porting beyond the
604 baseline are out of scope until the Leopard build is reproducible.

## Licensing

This bootstrap code is not a distribution of WebKit. When upstream source and
historical patches are imported, their existing copyright and license notices
must remain intact. See [Documentation/SourceProvenance.md](Documentation/SourceProvenance.md).
