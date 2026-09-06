# MacPorts GCC 6.3 overlay

This directory preserves the minimal official MacPorts metadata needed to make
the historical `gcc6 @6.3.0` and `libgcc @6.3.0` ports selectable ahead of the
current ports tree. Current MacPorts makes `libgcc6` depend on a newer runtime
that is known not to build on PowerPC, so it cannot reproduce the toolchain used
by Leopard WebKit 604.

The files come from MacPorts commit
`f0751811eab8f96f656eeedddcb5858afa60c1ed` (7 January 2017):

- `lang/gcc6/Portfile`
- `lang/gcc6/files/mp-gcc6`
- `_resources/port1.0/group/compiler_blacklist_versions-1.0.tcl`

Their SHA-256 digests are:

```text
b22946ebb6e6a44dbe5d8c251e8d1c3802220c1358635d8b5fa0d1de3e33ef65  lang/gcc6/Portfile
6d2f0eaa4fe4beba0686b68102dc4ed3d829f912f66480e6b95a7e5c1f6185f6  lang/gcc6/files/mp-gcc6
cc7dfbd00c2eb94f76c1277e75a9769bdbfc75e7c7179ca3383741fa7ad03f1d  _resources/port1.0/group/compiler_blacklist_versions-1.0.tcl
```

Run `Scripts/prepare-macports-gcc6.sh` on Leopard after `sudo port sync`.
Generated indices and configuration stay under ignored `Artifacts/`; the script
does not modify the global MacPorts configuration or install any port.

This overlay is the unmodified MacPorts GCC 6.3 baseline. It does not claim to
contain the additional Xcode and Objective-C++ patches described by the Leopard
WebKit project; those remain to be recovered or reconstructed and validated.

