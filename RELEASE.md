# Release process

## One-time setup

CI (`.github/workflows/release.yml`) builds, signs, and notarizes on every
`v*` tag push, then attaches the notarized `.zip` to a GitHub Release. It
needs these repo secrets set once (Settings > Secrets and variables >
Actions) — see the comment block at the top of that workflow file for exactly
how to generate each one:

- `MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`
- `CI_KEYCHAIN_PASSWORD`
- `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`

For a local notarized build instead (e.g. to sanity-check before tagging),
`App/build.sh --notarize` needs the same Apple credentials available via a
keychain profile — see the comment block at the top of `App/build.sh`.

## Cutting a release

1. Make sure `CHANGELOG.md`'s `[Unreleased]` section is accurate and
   complete — it should already be, if changes were logged as they landed.
2. Bump the version in `App/Info.plist` (`CFBundleShortVersionString` and
   `CFBundleVersion`).
3. Move the `[Unreleased]` section's contents under a new dated heading:
   ```
   ## [X.Y.Z] - YYYY-MM-DD
   ```
   and add a fresh empty `## [Unreleased]` above it. Add the version's
   comparison link at the bottom, next to the existing `[Unreleased]` link.
4. Commit: `Release vX.Y.Z` (bump + changelog together).
5. Tag and push: `git tag vX.Y.Z && git push origin main vX.Y.Z`. The tag
   push triggers CI, which runs the test suite, builds, codesigns,
   notarizes, and attaches `Redspire.zip` to a new GitHub Release for that
   tag automatically.
6. Verify the release: download the attached `.zip` fresh, `xattr -d
   com.apple.quarantine` isn't needed for a properly notarized+stapled
   build, but `spctl -a -vvv -t install Redspire.app` should report
   `accepted` / `source=Notarized Developer ID`.
