#!/usr/bin/env bash
# One-way redaction for committed tool output. Rubric §5.3.
#
# Substitutes the AWS account ID and access key IDs with fixed placeholders.
# Not reversible: no mapping is written anywhere. Placeholders keep the shape of
# what they replace, so ARNs stay well-formed and JSON stays parseable.
#
#   ./redact.sh              # redact raw-output/ in place
#   ./redact.sh <path>...    # redact specific files or directories
#   ./redact.sh --check      # verify nothing sensitive remains; no writes
#
# Idempotent. Safe to re-run. Run before every commit that adds tool output.

set -euo pipefail

cd "$(dirname "$0")"

ACCOUNT_ID_FILE=".account-id"
ACCOUNT_PLACEHOLDER="000000000000"

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
  shift
fi

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("raw-output")
fi

if [[ ! -f "$ACCOUNT_ID_FILE" ]]; then
  echo "error: $ACCOUNT_ID_FILE not found." >&2
  echo "Create it with the 12-digit sandbox account ID and nothing else:" >&2
  echo "  aws sts get-caller-identity --profile personal --query Account --output text > $ACCOUNT_ID_FILE" >&2
  echo "It is gitignored and must never be committed." >&2
  exit 1
fi

ACCOUNT_ID="$(tr -cd '0-9' < "$ACCOUNT_ID_FILE")"
if [[ ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "error: $ACCOUNT_ID_FILE does not contain a 12-digit account ID." >&2
  exit 1
fi

# Collect regular files under the targets.
FILES=()
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find "${TARGETS[@]}" -type f ! -name '.gitkeep' -print0 2>/dev/null)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "no files under: ${TARGETS[*]}"
  exit 0
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  # Placeholders are themselves shaped like the things they replace, so the
  # check has to exclude them explicitly or it flags its own output.
  if ACCOUNT_ID="$ACCOUNT_ID" perl -ne '
        BEGIN { $a = quotemeta $ENV{ACCOUNT_ID}; $bad = 0; }
        if (/$a/) { print STDERR "$ARGV:$.: unredacted account ID\n"; $bad = 1; }
        while (/(?:AKIA|ASIA)([0-9A-Z]{16})/g) {
          next if $1 eq "X" x 16;
          print STDERR "$ARGV:$.: unredacted access key ID\n";
          $bad = 1;
        }
        END { exit($bad ? 1 : 0); }
      ' "${FILES[@]}"; then
    echo "check passed: ${#FILES[@]} file(s), no account ID or access key IDs found"
    exit 0
  else
    echo "REDACTION CHECK FAILED - do not commit" >&2
    exit 1
  fi
fi

ACCOUNT_ID="$ACCOUNT_ID" ACCOUNT_PLACEHOLDER="$ACCOUNT_PLACEHOLDER" \
  perl -pi -e '
    BEGIN { $a = quotemeta $ENV{ACCOUNT_ID}; $p = $ENV{ACCOUNT_PLACEHOLDER}; }
    s/$a/$p/g;
    s/AKIA[0-9A-Z]{16}/AKIAXXXXXXXXXXXXXXXX/g;
    s/ASIA[0-9A-Z]{16}/ASIAXXXXXXXXXXXXXXXX/g;
  ' "${FILES[@]}"

echo "redacted ${#FILES[@]} file(s) under: ${TARGETS[*]}"
exec "$0" --check "${TARGETS[@]}"
