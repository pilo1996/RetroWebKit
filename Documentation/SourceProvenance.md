# Source provenance

## Proposed baseline

| Layer | Upstream identity | Status |
| --- | --- | --- |
| WebKit | tag `Safari-604.5.6` | imported on the engine import branch |
| WebKit Git commit | `3f76b1214e0deb75a2f813be9bd96b56d9da84df` | verified in official mirror |
| WebKit annotated tag object | `4ba61fea6db30297bd111e11a6701b66817cd0a8` | verified in official mirror |
| WebKit SVN | tag created by changeset `r226724` | identified |
| Leopard port | `Patches_604.5.6.tar.bz2` | archived; main WebKit patch applied |
| Final binary | `WebKit-604.5.6_2-Leopard-PowerPC.dmg` | identified, not imported |

WebKit's `Safari-604.5.6` tag was created on 11 January 2018 as SVN changeset
`r226724`. The matching Leopard WebKit patch archive was published on 2 February
2018. The final `_2` binary was published on 10 June 2018; the release notes
describe stability, relinking, TLS-priority, and disk-image changes, while the
file area exposes no separate `_2` source patch set.

The official WebKit Git mirror resolves the tag to annotated tag object
`4ba61fea6db30297bd111e11a6701b66817cd0a8`, which points to commit
`3f76b1214e0deb75a2f813be9bd96b56d9da84df`. This immutable commit is the input
used for the deterministic source import.

The imported vendor subset contains `Source`, `Tools`, `WebKitLibraries`, and the
root build files `CMakeLists.txt`, `Makefile`, `Makefile.shared`, `ChangeLog`, and
`ChangeLog-2012-05-22`. A Git archive of exactly those paths from the pinned commit
has SHA-256:

```text
6e86730dc6edc287721da3fea4e8d5f8982f364da63197fd90502662e0ef7a6a
```

`LayoutTests` is intentionally excluded, matching the historical project's advice
that the test-suite checkout is unnecessary for a framework build.

## Leopard patch application

`WebKit_604.5.6.diff` applies cleanly to the pinned baseline with Git's binary
patch support. The applied source state omits `Source/ThirdParty/lz4/.svn`, a set
of 111 Subversion working-copy administration files embedded by the historical
patch. The corresponding LZ4 source, build files, and license are retained; only
the redundant checkout database and pristine cache are excluded.

The separate OTS and LZ4 patch files remain archived but unapplied. Their paths
target external `tags/v6.1.1` and `tags/v1.8.0` repository layouts, so their exact
upstream inputs must be pinned before use.

## Import policy

The safest initial import is a mechanically reproducible vendor baseline:

1. obtain the official `Safari-604.5.6` tag;
2. record its immutable Git commit or SVN revision and archive checksum;
3. import the minimum buildable directories without rewriting files;
4. preserve all license, copying, and attribution files;
5. import the unmodified Leopard patch archive in a distinct historical area;
6. apply the patch in a separate logical commit;
7. record rejected or locally adjusted hunks explicitly.

This keeps three reviewable states: upstream WebKit, the historical Leopard port,
and RetroWebKit-owned changes. A Git subtree-style import or a deterministic
archive import is preferable to a submodule because the historical tag and patch
must remain buildable even if an external host changes.

## License handling

WebKit is a collection of components under multiple licenses. File-level notices
are authoritative. The Leopard patch also introduces third-party PowerPC code
with its own notices. No bulk reformatting, header replacement, or squashing of
those notices is permitted during import.

Before publishing an engine import, inventory at least:

- top-level WebKit license files;
- JavaScriptCore, WebCore, WTF, WebKitLegacy, and third-party notices;
- OpenType Sanitizer and LZ4 licensing;
- license blocks introduced by the PowerPC patch;
- binary-only libraries, if any, and whether redistribution is allowed.

## Open provenance questions

- Does the official Git commit preserve the historical SVN tag byte-for-byte
  for every file needed by the Leopard build?
- Which exact patch or commit produced the `_2` framework binaries?
- Are the required WebKitSystemInterface libraries redistributable in source or
  binary form?
- Which external Security.framework work is required for the standalone browser?
