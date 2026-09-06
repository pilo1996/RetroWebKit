# Leopard WebKit 604.5.6 patch set

These files are an unmodified extraction of the historical SourceForge archive:

```text
Patches_604.5.6.tar.bz2
```

Source:
<https://sourceforge.net/projects/leopard-webkit/files/604/Sources/Patches_604.5.6.tar.bz2/download>

Archive SHA-256:

```text
faac7ff994fadcff53df35f41d149f32cc4db4e4213ca01074ec860f9383ab52
```

Extracted file SHA-256 values:

```text
e87a4ffbad7fafdfab759122875aee84434de3f51fc64c361fde30a109ecb69e  WebKit_604.5.6.diff
f9a9cd1e29a62e062cd2eb8da9012b7a0da0e77d585e0fc04bf7b54de9c769a4  Source/ThirdParty/ots/ots_604.5.6.diff
081f88db983cf5446c802c822355395ff3f55eddd2826a0859d1d3d2ab46e46d  Source/ThirdParty/lz4/lz4_604.5.6.diff
```

`WebKit_604.5.6.diff` applies cleanly, including its binary patches, to the pinned
`Safari-604.5.6` WebKit baseline.

The OTS and LZ4 patches do not target the WebKit root. Their paths begin at
`tags/v6.1.1` and `tags/v1.8.0`, respectively, and presuppose separate historical
source layouts. They must not be applied until those upstream inputs have been
identified and checksummed.

Do not reformat these patches or remove notices embedded in them.
