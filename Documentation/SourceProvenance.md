# Source provenance

## Proposed baseline

| Layer | Upstream identity | Status |
| --- | --- | --- |
| WebKit | tag `Safari-604.5.6` | identified, not imported |
| WebKit Git commit | `3f76b1214e0deb75a2f813be9bd96b56d9da84df` | verified in official mirror |
| WebKit annotated tag object | `4ba61fea6db30297bd111e11a6701b66817cd0a8` | verified in official mirror |
| WebKit SVN | tag created by changeset `r226724` | identified |
| Leopard port | `Patches_604.5.6.tar.bz2` | inspected, not imported |
| Final binary | `WebKit-604.5.6_2-Leopard-PowerPC.dmg` | identified, not imported |

WebKit's `Safari-604.5.6` tag was created on 11 January 2018 as SVN changeset
`r226724`. The matching Leopard WebKit patch archive was published on 2 February
2018. The final `_2` binary was published on 10 June 2018; the release notes
describe stability, relinking, TLS-priority, and disk-image changes, while the
file area exposes no separate `_2` source patch set.

The official WebKit Git mirror resolves the tag to annotated tag object
`4ba61fea6db30297bd111e11a6701b66817cd0a8`, which points to commit
`3f76b1214e0deb75a2f813be9bd96b56d9da84df`. This immutable commit is the proposed
input for a deterministic source import.

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
