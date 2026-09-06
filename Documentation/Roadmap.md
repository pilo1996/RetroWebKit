# Roadmap

## M0 — Repository bootstrap (current)

- establish project boundaries and directory layout;
- identify the WebKit and Leopard WebKit baselines;
- add non-mutating environment diagnostics;
- define source and license import policy.

Exit condition: repository checks pass and unresolved provenance questions are
documented rather than guessed.

## M1 — Reproduce Leopard WebKit 604 on PowerPC

- archive and checksum the official upstream tag and historical patch set;
- import upstream source and licensing in a dedicated commit;
- apply the historical Leopard patch in a dedicated commit;
- reconstruct the modified GCC 6.3 and dependency toolchain;
- build WebKitLegacy on Mac OS X 10.5.8, first with generic `ppc`;
- collect deterministic logs and record a known-good environment.

Exit condition: a clean checkout builds twice on Leopard PowerPC using documented
commands and produces equivalent framework outputs.

## M2 — Minimal RetroBrowser shell

- native Cocoa window and toolbar;
- back, forward, reload, and address controls;
- embedded WebKitLegacy `WebView`;
- launch and smoke tests on Leopard PowerPC.

## M3 — Leopard architecture coverage

- validate G4 (`ppc7400`) and G5 (`ppc970`) variants;
- add and test Leopard i386;
- benchmark before adopting architecture-specific compiler tuning.

## M4 — Web compatibility and packaging

- define representative HTML, CSS, JavaScript, storage, font, and TLS tests;
- package the app without replacing system frameworks;
- document known limitations and recovery procedures.

## M5 — Tiger feasibility

Only after M1–M4 are stable:

- inventory missing Tiger APIs and runtime symbols;
- prefer isolated shims under `Compat/Tiger/`;
- establish a Tiger PowerPC build without regressing Leopard.

Moving beyond WebKit 604 is a separate investigation, not an implied milestone.
