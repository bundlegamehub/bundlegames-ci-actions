#!/usr/bin/env bash
#
# scripts/check-action-pins.sh — enforce full-SHA pinning on every `uses:`
# reference in .github/workflows/. Used as a pre-commit local hook in repos
# that adopt the bundlegames-devx baseline.
#
# Copied into each repo by scripts/install-shared-config.sh. When updating
# the logic, update it here (bundlegames-devx), then re-run the install
# across consumer repos.

set -euo pipefail

bad=0

while IFS= read -r file; do
  while IFS= read -r line; do
    ref="${line##*@}"
    if [[ "$line" == *"uses:"* ]] && [[ ! "$ref" =~ ^[0-9a-f]{40}($|[[:space:]]|#) ]]; then
      echo "Unpinned action in $file: $line"
      bad=1
    fi
  done < <(grep -nE 'uses:[[:space:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(@[^[:space:]]+)' "$file" || true)
done < <(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)

exit "$bad"
