# Leopard build toolchain

## Confidence levels

This file separates verified historical facts from open questions. Do not use
the older SourceForge instructions as a literal installation script: the page
explicitly says its instructions predate WebKit 601 and that 601+ switched to a
modified GCC 6.

## Verified from primary project material

The Leopard WebKit project published:

- a final PowerPC binary named `WebKit-604.5.6_2-Leopard-PowerPC.dmg`;
- a source patch archive named `Patches_604.5.6.tar.bz2`;
- instructions to start from a WebKit Safari tag and apply the corresponding
  WebKit patch;
- a note that WebKit 601 and later use a modified GCC 6;
- PowerPC build architecture names including `ppc`, `ppc7400`, and `ppc970`.

The inspected patch archive has SHA-256:

```text
faac7ff994fadcff53df35f41d149f32cc4db4e4213ca01074ec860f9383ab52
```

It contains:

```text
WebKit_604.5.6.diff
Source/ThirdParty/ots/ots_604.5.6.diff
Source/ThirdParty/lz4/lz4_604.5.6.diff
```

The main patch configures Leopard and Snow Leopard builds to use an Xcode
compiler identifier named `GCC_50`, selects GNU++14, and includes substantial
PowerPC-specific work. The project's ticket history clarifies that its PowerPC
compiler was GCC 6.3 with patches for Xcode and Objective-C++ compatibility.
The `GCC_50` Xcode identifier therefore must not be read as proof that ordinary,
unmodified GCC 5 is sufficient.

## Verified on the reference PowerPC host

The current reference host is Mac OS X 10.5.8 build `9L31a` on PowerPC. Xcode
3.1.4 (`DevToolsCore-1204.0`, build `9M2809`) is installed under `/Developer`,
with the Mac OS X 10.5 SDK, Apple GCC 4.0.1 build 5493, Apple GCC 4.2.1 build
5577, and GNU Make 3.81.

MacPorts 2.12.4 is installed under `/opt/local`. On Leopard, `port selfupdate`
can fail while fetching the MacPorts base over HTTPS even though the ports
catalog remains available. `sudo port sync` successfully downloads the catalog
over rsync. The checked-in overlay in `Tools/MacPortsOverlay/` selects the
official MacPorts GCC 6.3.0 port from 7 January 2017 while retaining the current
tree for its dependencies. A dry-run on the reference host resolves the full
dependency plan without selecting the unsupported current `libgcc11` runtime.

Prepare the isolated configuration with:

```sh
./Scripts/prepare-macports-gcc6.sh
```

The script prints separate dry-run and installation commands. It writes only to
ignored `Artifacts/macports/`; selecting or installing the compiler remains an
explicit operation.

`Scripts/build.sh` exposes the installed `gcc-mp-6` and `g++-mp-6` to Xcode
3.1.4 through repository-local wrappers. Xcode is told to use its GCC 4.2
compiler specification while the compiler executable settings point to GCC 6.
The wrappers discard Apple-specific or obsolete flags which upstream GCC 6 does
not accept, including `-fpascal-strings`, `-Wnewline-eof`, and
`-Wshorten-64-to-32`. They also remove
Xcode header-map arguments, whose binary format is supported by Apple GCC but
not upstream GCC; the generated and product include directories remain intact.
This avoids
installing an unverified compiler plugin under `/Developer` or replacing system
compiler links.

Inspection of the final PowerPC application confirms that its bundled
`libgcc_s.1.dylib` and `libstdc++.6.dylib` use `/opt/local/lib/libgcc` install
names. The latter has compatibility version 7.0.0 and corresponds to the
`libstdc++.6.0.22` generation shipped by GCC 6.3. This independently supports
the project's ticket history.

## Still to obtain or verify

- the exact modified GCC 6.3 source/patch set and reproducible build recipe;
- whether Xcode 3.1.4 exactly matches the version used for the final release;
- the complete MacPorts port-version set used for the final release;
- the complete non-system dependency inventory and how each dependency was built;
- whether the final `_2` disk image contains build metadata absent from the
  published patch archive;
- WebKitSystemInterface and JavaScriptGlue requirements for this exact tag.

Until these are resolved, `bootstrap.sh` reports capabilities but does not alter
`/usr/bin`, Xcode, or MacPorts selections.

## Historical requirements (not yet a prescriptive recipe)

The older project instructions list Ruby 1.9+, Python 2.6+ with JSON, Perl 5.10+,
flex 2.5.35+, `developer_cmds`, Subversion, and MacPorts. They also describe
JavaScriptGlue from WebKit SVN revision 105839 and restoring WebKitSystemInterface
files removed at revision 133670. These details need validation against the 604
patch before automation.

## Environment probe

Run on the target machine:

```sh
./Scripts/bootstrap.sh --target leopard --arch ppc
```

The command writes `Artifacts/diagnostics/system-info.txt` and
`Artifacts/diagnostics/toolchain-info.txt`. It never installs packages or changes
system tools.

## Sources

- [Leopard WebKit build instructions](https://sourceforge.net/p/leopard-webkit/wiki/BuildInstructions/)
- [Leopard WebKit project home and release notes](https://sourceforge.net/p/leopard-webkit/wiki/Home/)
- [Leopard WebKit 604 source patches](https://sourceforge.net/projects/leopard-webkit/files/604/Sources/)
- [WebKit tag creation for Safari-604.5.6](https://trac.webkit.org/changeset/226724/webkit)
- [Safari-604.5.6 in the official WebKit Git mirror](https://github.com/WebKit/WebKit/releases/tag/Safari-604.5.6)
- [Leopard WebKit toolchain discussion](https://sourceforge.net/p/leopard-webkit/tickets/113/)
