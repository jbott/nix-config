#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/search
cat > services/search/index.py <<'EOF'
def search(q):
    return []  # stub
EOF
commit_with "services/search: scaffold module"

cat >> services/search/index.py <<'EOF'

def index(doc):
    # add to inverted index
    pass

def query(terms):
    # match against index
    pass
EOF
commit_with "services/search: add index and query stubs"

# Starting state: 2 prior commits (scaffold + index) + empty @ = stack height 3, wc clean.
assert_starting_state 3 clean
echo "Setup complete: $REPO_ROOT"
echo "@ is empty on top of two real commits about a search service."
