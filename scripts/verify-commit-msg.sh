#!/usr/bin/env bash
set -euo pipefail

commit_msg_file="$1"
first_line="$(head -n1 "$commit_msg_file" | tr -d '\r')"

# Allow git-generated commits (merge, revert, etc.)
if [[ "$first_line" =~ ^(Merge|Revert) ]]; then
  exit 0
fi

pattern='^(feat|fix|docs)(\([a-z0-9._/-]+\))?: [^[:space:]].*$'

if [[ "$first_line" =~ $pattern ]]; then
  exit 0
fi

cat <<'MSG'
🛑 Invalid commit message.

Expected format:
  feat(<scope>): description
  fix(<scope>): description
  docs(<scope>): description

Scope is optional, but the type must be one of: feat, fix, docs.
Example: feat(ui): add wallet connect
MSG

exit 1
