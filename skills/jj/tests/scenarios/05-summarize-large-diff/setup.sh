#!/usr/bin/env bash
# shellcheck disable=SC1091  # dynamic/generated source paths, not followable at lint time
source "$(dirname "$0")/../../lib/common.sh"

init_repo

mkdir -p services/{auth,billing,search,notifier} lib/utils
# 8 files, ~75 lines each = 600 lines.
for mod in services/auth services/billing services/search services/notifier; do
  cat > "$mod/handler.py" <<EOF
def handle(req):
    # ~75 lines of $mod handler code
    user = req.get("user")
    if not user:
        return {"status": "error", "reason": "missing user"}
    body = req.get("body", {})
    if not isinstance(body, dict):
        return {"status": "error", "reason": "body must be object"}

    result = {}
    for k, v in body.items():
        if k in ("amount", "value", "count"):
            try:
                result[k] = int(v)
            except (TypeError, ValueError):
                return {"status": "error", "reason": f"bad number: {k}"}
        elif k in ("email", "address"):
            if not isinstance(v, str) or "@" not in v:
                return {"status": "error", "reason": f"bad string: {k}"}
            result[k] = v
        else:
            result[k] = v

    audit = {
        "module": "$mod",
        "user": user,
        "keys": sorted(result.keys()),
        "size": len(result),
    }

    return {
        "status": "ok",
        "user": user,
        "result": result,
        "audit": audit,
    }


def handle_batch(reqs):
    return [handle(r) for r in reqs]
EOF
done

# 4 more files in lib/utils.
for util in helpers parsers validators serializers; do
  cat > "lib/utils/$util.py" <<EOF
# $util.py — utility module
import json
import re

def $util(value, **opts):
    if value is None:
        return None
    if isinstance(value, (list, tuple)):
        return [$util(v, **opts) for v in value]
    if isinstance(value, dict):
        return {k: $util(v, **opts) for k, v in value.items()}
    return value


def $util\_strict(value):
    out = $util(value)
    if out is None:
        raise ValueError("$util: rejected None")
    return out


_PATTERN = re.compile(r"^[a-zA-Z0-9_-]+$")

def $util\_validate(name):
    return bool(_PATTERN.match(name))
EOF
done

commit_with "services: scaffold four service handlers and shared utils"

# Starting state: trunk seed + 1 big commit + empty @ = stack height 2, wc clean.
assert_starting_state 2 clean

# Sanity: confirm it's actually large.
lines=$(jj diff --git --no-pager -r '@-' | wc -l)
files=$(jj show --summary --no-pager -r '@-' | grep -c '^[AMD] ')
echo "Setup complete: $REPO_ROOT"
echo "Big commit at @-: $files files, $lines diff lines (incl. context/headers)."
