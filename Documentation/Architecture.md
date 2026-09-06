# Architecture

## Product shape

RetroWebKit will be a native Cocoa application embedding WebKitLegacy:

```text
RetroBrowser.app
  Cocoa window and toolbar
  WebView (WebKitLegacy)
    WebCore
    JavaScriptCore
    WTF
```

The browser shell is intentionally separate from Safari. This avoids Safari ABI
and integration constraints while keeping the initial runtime single-process.

## Initial browser surface

The first usable shell should contain only an `NSWindow`, navigation controls,
an address field, and a `WebView`. Features must earn their cost on PowerPC.

## Source boundaries

- `Browser/RetroBrowser/` owns application UI and browser policy.
- `Source/` will hold the reviewed WebKit 604 baseline.
- `Compat/Leopard/` holds project-owned Leopard integration code.
- `Compat/PowerPC/` holds project-owned architecture-specific integration code.
- `Compat/Tiger/` remains empty until the Leopard baseline is reproducible.

Historical changes already contained in the Leopard WebKit patch set must retain
their provenance. New compatibility code should not be mixed into upstream files
unless the build or runtime boundary makes that unavoidable.

## Explicit non-goals for the first milestone

- WebKit2 or multiple processes
- GPU or media processes
- modern sandboxing
- WebRTC, MediaSource, or Metal
- Safari extensions and Apple cloud services
- speculative Tiger compatibility
- upgrading to WebKit 605 or later

## Performance policy

Correctness and reproducibility come before tuning. Separate G4 (`ppc7400`) and
G5 (`ppc970`) builds may be evaluated only after a generic 32-bit PowerPC build
works. Compiler flags must come from the historical toolchain and measured tests,
not assumptions based on modern GCC.
