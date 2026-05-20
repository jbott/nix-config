#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

# Editor trap: when JJ_EDITOR is set to this script, any jj command that
# tries to open the description editor fails immediately with the message.
# Stage this BEFORE the agent's work so it doesn't pollute the agent's
# working copy.
cat > "$REPO_ROOT/.jj-editor-trap.sh" <<'TRAP'
#!/usr/bin/env bash
cat >&2 <<'MSG'
jj invoked the description editor, but Claude cannot use interactive editors.
Re-run the command with -m "<message>".
MSG
exit 1
TRAP
chmod +x "$REPO_ROOT/.jj-editor-trap.sh"
echo ".jj-editor-trap.sh" >> .gitignore

mkdir -p services/payments
cat > services/payments/handler.py <<'EOF'
def charge(amount):
    return {"ok": True}
EOF
commit_with "services/payments: scaffold handler and ignore trap script"
jj bookmark set main -r '@-' >/dev/null

# Modify in @ (uncommitted). This is the only change the agent should commit.
cat > services/payments/handler.py <<'EOF'
def charge(amount):
    if amount <= 0:
        return {"ok": False, "reason": "amount must be positive"}
    return {"ok": True, "amount": amount}
EOF

assert_starting_state 1 dirty
echo "Setup complete: $REPO_ROOT"
echo "Editor trap script: $REPO_ROOT/.jj-editor-trap.sh"
echo "Agent must run jj commands with JJ_EDITOR=$REPO_ROOT/.jj-editor-trap.sh"
