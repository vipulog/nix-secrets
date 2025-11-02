# shellcheck shell=bash
set -e

for file in "$@"; do
  # Check if file contains SOPS metadata.
  if grep -q "sops" "$file" &&
    grep -q "version" "$file" &&
    grep -q "mac" "$file"; then
    :
  else
    echo "ERROR: $file appears to be a SOPS file but is NOT ENCRYPTED!" >&2
    echo "       Please encrypt it with 'sops --encrypt --in-place $file'" >&2
    exit 1
  fi
done

exit 0
