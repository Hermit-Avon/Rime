#!/usr/bin/env bash
set -euo pipefail

# Format Rime YAML files in current directory (non-recursive).
# - trim trailing whitespace
# - in dictionary body (after `...`), normalize first separator:
#   "text code" / "text  code" -> "text<TAB>code"

check_only=0
if [[ "${1:-}" == "--check" ]]; then
  check_only=1
fi

changed=0

format_one() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  awk '
    BEGIN { in_dict = 0 }
    {
      sub(/[ \t]+$/, "", $0)

      if ($0 == "...") {
        in_dict = 1
        print
        next
      }

      if (in_dict) {
        if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
          print
          next
        }
        if ($0 ~ /\t/) {
          # Normalize "text    \tcode" -> "text\tcode"
          tab_pos = index($0, "\t")
          if (tab_pos > 1) {
            left = substr($0, 1, tab_pos - 1)
            right = substr($0, tab_pos + 1)
            sub(/[[:space:]]+$/, "", left)
            $0 = left "\t" right
          }
        } else if ($0 ~ /^[^[:space:]#]+[[:space:]]+[^[:space:]]/) {
          match($0, /^[^[:space:]]+/)
          key = substr($0, RSTART, RLENGTH)
          rest = substr($0, RLENGTH + 1)
          sub(/^[[:space:]]+/, "", rest)
          $0 = key "\t" rest
        }
      }

      print
    }
  ' "$file" > "$tmp"

  if ! cmp -s "$file" "$tmp"; then
    if [[ $check_only -eq 1 ]]; then
      echo "needs format: $file"
      changed=1
      rm -f "$tmp"
      return
    fi
    mv "$tmp" "$file"
    echo "formatted: $file"
    changed=1
  else
    rm -f "$tmp"
  fi
}

while IFS= read -r -d '' file; do
  format_one "$file"
done < <(find . -maxdepth 1 -type f -name "*.yaml" -print0 | sort -z)

if [[ $check_only -eq 1 && $changed -eq 1 ]]; then
  exit 1
fi
