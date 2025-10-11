# Troubleshooting

## "no more rows available" build error

If Xcode or `xcodebuild` fails with an error similar to:

```
error: accessing build database ".../Build/Intermediates.noindex/XCBuildData/build.db": no more rows available
The build service has encountered an internal inconsistency error: unexpected incomplete target ...
```

the derived data cache has likely become corrupted. You can clean it safely with the helper script in `Scripts/clean_build.sh`:

```bash
./Scripts/clean_build.sh
```

After running the script, re-run the build and Xcode will regenerate the cache. The
script removes both the local `Build` cache inside the repository and any
`DerivedData` folders matching `scoremyday2-*` in
`~/Library/Developer/Xcode/DerivedData`, which are the most common sources of the
database corruption.

