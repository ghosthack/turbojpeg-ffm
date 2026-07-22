# Publishing to Maven Central

Same pipeline as [ffmpeg-ffm](https://github.com/ghosthack/ffmpeg-ffm): CI
builds the natives from source on GitHub runners, and the `deploy` job signs
and uploads one bundle (parent + core + both natives classifier jars) with
`autoPublish=true`. Release procedure once secrets are in place: **bump the
pom version, push to main** — CI does the rest.

## One-time setup: the four repo secrets

(Settings → Secrets → Actions, or the `gh` commands below. The
`io.github.ghosthack` namespace is already verified on the portal.)

| Secret | Value |
|---|---|
| `MAVEN_CENTRAL_USERNAME` / `MAVEN_CENTRAL_PASSWORD` | central.sonatype.com → Account → user token: the token *username* and token *password*, set **separately** (NOT the base64 `user:pass` combo the portal also offers — that's only for settings.xml `Authorization` headers). Regenerating a token invalidates the old one → update ffmpeg-ffm's copies too. |
| `GPG_PRIVATE_KEY` | ASCII-armored private key export (see below) |
| `GPG_PASSPHRASE` | that key's passphrase |

### Generating a fresh signing key (if the old one/passphrase is lost)

Central accepts any published key; it does not have to match ffmpeg-ffm's.

```sh
# 1. passphrase, kept in a root-only file you also save somewhere durable
PF=~/.gnupg/turbojpeg-ffm-signing-passphrase.txt
openssl rand -base64 24 > "$PF" && chmod 600 "$PF"

# 2. generate + export
gpg --batch --pinentry-mode loopback --passphrase-file "$PF" \
    --quick-generate-key "ghosthack <afclc2@faex.com>" rsa4096 sign 2y
KEYID=$(gpg --list-secret-keys --with-colons ghosthack | awk -F: '/^sec/{print $5}' | tail -1)
gpg --batch --pinentry-mode loopback --passphrase-file "$PF" \
    --armor --export-secret-keys "$KEYID" > /tmp/key.asc

# 3. Central verifies signatures against public keyservers — publish the public half
gpg --keyserver keyserver.ubuntu.com --send-keys "$KEYID"

# 4. set the secrets, then clean up
gh secret set GPG_PRIVATE_KEY -R ghosthack/turbojpeg-ffm < /tmp/key.asc
gh secret set GPG_PASSPHRASE  -R ghosthack/turbojpeg-ffm < "$PF"
rm /tmp/key.asc

# 5. the two portal-token secrets
gh secret set MAVEN_CENTRAL_USERNAME -R ghosthack/turbojpeg-ffm   # paste token username
gh secret set MAVEN_CENTRAL_PASSWORD -R ghosthack/turbojpeg-ffm   # paste token password
```

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
