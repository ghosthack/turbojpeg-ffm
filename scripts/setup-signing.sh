#!/bin/sh
# All-in-one release-credentials setup for ghosthack/turbojpeg-ffm:
# generates a signing key if needed, publishes it, sets the four repo
# secrets (prompting only for what is missing), and reruns the deploy.
#
# Safe to rerun: every step skips what is already in place.
# See PUBLISHING.md for the background.
set -eu

REPO="ghosthack/turbojpeg-ffm"
UID_STR="ghosthack <ghosthack@users.noreply.github.com>"
PF="$HOME/.gnupg/turbojpeg-ffm-signing-passphrase.txt"
ASC="$(mktemp)/key.asc"; mkdir -p "$(dirname "$ASC")"

gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated"; exit 1; }

# --- signing key ------------------------------------------------------------
if [ ! -f "$PF" ]; then
  echo "==> generating passphrase into $PF (save a copy somewhere durable)"
  openssl rand -base64 24 > "$PF" && chmod 600 "$PF"
fi

KEYID=$(gpg --list-secret-keys --with-colons "$UID_STR" 2>/dev/null | awk -F: '/^sec/{print $5}' | tail -1 || true)
if [ -z "${KEYID:-}" ]; then
  echo "==> generating signing key for: $UID_STR"
  gpg --batch --pinentry-mode loopback --passphrase-file "$PF" \
      --quick-generate-key "$UID_STR" rsa4096 sign 2y
  KEYID=$(gpg --list-secret-keys --with-colons "$UID_STR" | awk -F: '/^sec/{print $5}' | tail -1)
fi
echo "==> signing key: $KEYID"

echo "==> publishing public key to keyserver.ubuntu.com (Central verifies against it)"
gpg --keyserver keyserver.ubuntu.com --send-keys "$KEYID" || \
  echo "    (send-keys failed — retry later; deploy will fail validation until it is published)"

# --- repo secrets -----------------------------------------------------------
have() { gh secret list -R "$REPO" | awk '{print $1}' | grep -qx "$1"; }

echo "==> setting GPG secrets on $REPO"
gpg --batch --pinentry-mode loopback --passphrase-file "$PF" \
    --armor --export-secret-keys "$KEYID" > "$ASC"
gh secret set GPG_PRIVATE_KEY -R "$REPO" < "$ASC"
rm -f "$ASC"
gh secret set GPG_PASSPHRASE -R "$REPO" < "$PF"

for s in MAVEN_CENTRAL_USERNAME MAVEN_CENTRAL_PASSWORD; do
  if have "$s"; then
    echo "==> $s already set — keeping it"
  else
    printf '==> paste value for %s (from central.sonatype.com user token): ' "$s"
    gh secret set "$s" -R "$REPO"
  fi
done

echo "==> secrets now on $REPO:"
gh secret list -R "$REPO"

# --- redeploy ---------------------------------------------------------------
FAILED_RUN=$(gh run list -R "$REPO" --workflow ci.yml --limit 5 \
  --json databaseId,conclusion -q '[.[] | select(.conclusion == "failure")][0].databaseId' || true)
if [ -n "${FAILED_RUN:-}" ] && [ "$FAILED_RUN" != "null" ]; then
  echo "==> rerunning failed jobs of run $FAILED_RUN"
  gh run rerun "$FAILED_RUN" --failed -R "$REPO"
else
  echo "==> no failed run found; dispatching a fresh CI run"
  gh workflow run ci.yml -R "$REPO"
fi

echo "==> watch with: gh run watch -R $REPO"
