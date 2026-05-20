#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Stand up a bare git remote and wire it as origin.
REMOTE_PATH="$(dirname "$REPO_ROOT")/04-push-alias-remote.git"
rm -rf "$REMOTE_PATH"
git init --bare "$REMOTE_PATH" >/dev/null
jj git remote add origin "$REMOTE_PATH" >/dev/null

# Push the trunk seed so origin has the main branch.
jj git push --bookmark main --allow-new >/dev/null 2>&1 || true

# Add a stack of work and a john/ bookmark on the tip.
mkdir -p services/notifier
cat > services/notifier/email.py <<'EOF'
def send(to, subject, body):
    pass  # TODO: implement
EOF
commit_with "services/notifier: scaffold email sender"

cat >> services/notifier/email.py <<'EOF'

def send_html(to, subject, html):
    pass  # TODO: implement
EOF
commit_with "services/notifier: add html sender"

jj bookmark create john/add-email-notifier -r '@-' >/dev/null

# Apply the local jj aliases so the `jj push` alias is available.
jj config set --repo aliases.push '["git", "push", "-r", "::@ & bookmarks()"]' >/dev/null

# Starting state: trunk seed + 2 work commits + empty @ = stack height 3, wc clean.
assert_starting_state 3 clean

# Sanity: bookmark exists, not yet on origin.
jj bookmark list --no-pager | grep -q '^john/add-email-notifier' \
  || { echo "SETUP ERROR: bookmark missing"; exit 2; }

echo "Setup complete: $REPO_ROOT"
echo "Remote at $REMOTE_PATH"
echo "Bookmark john/add-email-notifier exists locally but not on origin yet."
