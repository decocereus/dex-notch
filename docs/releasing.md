# Releasing Dex

Dex releases are created only from version tags and only after the protected
`release` GitHub environment is approved. The workflow tests the source, builds
a universal app, signs every Sparkle helper and the app with Developer ID,
notarizes and staples the DMG, verifies a quarantined installation, signs the
Sparkle feed, and then publishes the GitHub release.

```text
v0.1.0 tag
  └─ protected release environment
      ├─ test
      ├─ arm64 + x86_64 build → universal Dex.app
      ├─ Developer ID sign → notarize → staple
      ├─ quarantined clean-install launch
      └─ GitHub Release
          ├─ Dex-0.1.0.dmg
          ├─ Dex-0.1.0.sha256
          └─ appcast.xml → Sparkle updates
```

## One-time GitHub setup

Create a GitHub environment named `release`, restrict it to protected tags, and
require a reviewer. Store these environment secrets there:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Base64-encoded Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | Password used when exporting that `.p12` |
| `NOTARY_API_KEY_P8` | Base64-encoded App Store Connect API `.p8` key |
| `NOTARY_KEY_ID` | App Store Connect API key ID |
| `NOTARY_ISSUER_ID` | App Store Connect API issuer ID |
| `SPARKLE_PRIVATE_KEY` | Private key exported from the Dex Sparkle account |

The matching Sparkle public key is committed in `Support/Info.plist`. The
private key must never be committed. Export it without printing it:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account app.dex.notch \
  -x /path/to/private-key
gh secret set SPARKLE_PRIVATE_KEY \
  --env release \
  --body-file /path/to/private-key
```

Delete the exported file after GitHub confirms the secret exists. Keep an
offline backup: losing the Sparkle key makes future update signing and key
rotation harder.

## Publish a release

Update release notes and ensure `main` is green. Then create and push an
annotated version tag:

```bash
git tag -a v0.1.0 -m "Dex 0.1.0"
git push origin v0.1.0
```

Approve the waiting `release` environment deployment in GitHub Actions. Never
reuse a version tag or decrease the generated `CFBundleVersion`.

Existing installations check the stable URL below. It redirects to the signed
feed attached to the latest GitHub release:

<https://github.com/decocereus/dex-notch/releases/latest/download/appcast.xml>

## Local artifact check

This checks universal packaging without using distribution credentials. The
result is intentionally ad-hoc signed and cannot pass Gatekeeper or
notarization:

```bash
DEX_ALLOW_ADHOC=1 ./script/package_release.sh 0.1.0 1
```
