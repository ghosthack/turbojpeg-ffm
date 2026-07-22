# Publishing to Maven Central

Same pipeline as [ffmpeg-ffm](https://github.com/ghosthack/ffmpeg-ffm): CI
builds the natives from source on GitHub runners, and the `deploy` job signs
and uploads one bundle (parent + core + both natives classifier jars) with
`autoPublish=true`. Release procedure once secrets are in place: **bump the
pom version, push to main** — CI does the rest.

## One-time setup: the four repo secrets

(Settings → Secrets → Actions. The `io.github.ghosthack` namespace is
already verified on the portal.)

| Secret | Value |
|---|---|
| `MAVEN_CENTRAL_USERNAME` / `MAVEN_CENTRAL_PASSWORD` | central.sonatype.com → Account → user token: the token *username* and token *password*, set **separately** (NOT the base64 `user:pass` combo the portal also offers — that's only for settings.xml `Authorization` headers). Regenerating a token invalidates the old one → update ffmpeg-ffm's copies too. |
| `GPG_PRIVATE_KEY` | ASCII-armored private key export (`gpg --armor --export-secret-keys <KEYID>`) |
| `GPG_PASSPHRASE` | that key's passphrase |

### Re-running a deploy that failed on missing secrets

```sh
gh run rerun <run-id> --failed -R ghosthack/turbojpeg-ffm
# or force a fresh full run of the current version:
gh workflow run ci.yml -R ghosthack/turbojpeg-ffm
```

## Local fallback

`mvn -Prelease -Dgpg.skip=true clean verify` dry-runs sources/javadoc/packaging
with no keys. A full local deploy additionally needs the portal token in
`~/.m2/settings.xml` (server id `central`) and a local gpg key — prefer the CI
path.
