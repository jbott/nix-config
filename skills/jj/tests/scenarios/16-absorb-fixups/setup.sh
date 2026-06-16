#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/api

cat > services/api/users.py <<'EOF'
def list_users():
    return []
EOF
commit_with "services/api: add /v1/users"

cat > services/api/orders.py <<'EOF'
def list_orders():
    return []
EOF
commit_with "services/api: add /v1/orders"

cat > services/api/products.py <<'EOF'
def list_products():
    return []
EOF
commit_with "services/api: add /v1/products"

# Now in @, modify each file with a single-line fixup.
sed -i 's/return \[\]/return list()  # canonical empty list/' services/api/users.py
sed -i 's/return \[\]/return list()  # canonical empty list/' services/api/orders.py
sed -i 's/return \[\]/return list()  # canonical empty list/' services/api/products.py

# Stack height: A + B + C + @ = 4, wc dirty.
assert_starting_state 4 dirty

echo "Setup complete: $REPO_ROOT"
echo "@ has 3 small fixups, one per file, each touching a line introduced in its file's origin commit."
