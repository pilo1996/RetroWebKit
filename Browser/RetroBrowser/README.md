# RetroBrowser

RetroBrowser is the minimal single-process Cocoa shell for RetroWebKit. It uses
the WebKitLegacy `WebView` API and does not replace the system WebKit framework.

On the Leopard build host, after building the engine:

```sh
./Browser/RetroBrowser/build.sh
./Browser/RetroBrowser/run.sh
```

For a non-interactive launch check:

```sh
./Browser/RetroBrowser/smoke-test.sh
```

The application bundle is written to `Artifacts/RetroBrowser/Release`. The run
scripts select `WebKitBuild/Release` through `DYLD_FRAMEWORK_PATH`, keeping the
system frameworks untouched.
