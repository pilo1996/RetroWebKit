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

## Still to obtain or verify

- the exact modified GCC 6.3 source/patch set and reproducible build recipe;
- the Xcode version and SDK combination used for the final Leopard build;
- required MacPorts versions or archived ports;
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
