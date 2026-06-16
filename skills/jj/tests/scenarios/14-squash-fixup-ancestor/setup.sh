#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/api

# A: add /users (with typo `liste_users`).
cat > services/api/users.py <<'EOF'
def liste_users():
    return []
EOF
commit_with "services/api: add /users endpoint"
# Capture A's change-id immediately after committing.
A_change=$(jj log -r '@-' --no-graph --no-pager -T 'change_id ++ "\n"' | head -n1)

# B: add /orders.
cat > services/api/orders.py <<'EOF'
def list_orders():
    return []
EOF
commit_with "services/api: add /orders endpoint"

# C: add /products.
cat > services/api/products.py <<'EOF'
def list_products():
    return []
EOF
commit_with "services/api: add /products endpoint"

# @ now empty. Apply fixup for typo in A: edit users.py.
sed -i 's/liste_users/list_users/' services/api/users.py

# Save A_change for the verify step (it's stable across rewrites).
echo "$A_change" > .A-change-id

# Stack height: trunk()..@ = A + B + C + @ = 4.
assert_starting_state 4 dirty

echo "Setup complete: $REPO_ROOT"
echo "Stack: A (users, with typo) -> B (orders) -> C (products) -> @ (typo fix)."
echo "A's change-id: $A_change"
