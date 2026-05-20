#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/inventory
cat > services/inventory/handler.py <<'EOF'
def get_item(item_id):
    return None
EOF
commit_with "services/inventory: scaffold handler"

# Now modify in @ (uncommitted).
cat > services/inventory/handler.py <<'EOF'
def get_item(item_id):
    if not isinstance(item_id, int):
        raise TypeError("item_id must be int")
    return {"id": item_id, "name": "stub"}
EOF

assert_starting_state 2 dirty
echo "Setup complete: $REPO_ROOT"
echo "@ has uncommitted changes adding type validation to get_item."
