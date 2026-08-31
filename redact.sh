#!/usr/bin/env bash
# One-way redaction for committed tool output. Rubric §5.3.
#
# Substitutes the AWS account ID and access key IDs with fixed placeholders,
# in file CONTENTS and in file and directory NAMES.
# Not reversible: no mapping is written anywhere. Placeholders keep the shape of
# what they replace, so ARNs stay well-formed and JSON stays parseable.
#
# Path names are covered because the tools put the account ID there: cloudfox
# writes to <outdir>/cloudfox-output/aws/<profile>-<account-id>/, and PMapper
# stores its graph under <appdata>/com.nccgroup.principalmapper/<account-id>/.
# Substituting contents but not names would leave the account ID committed.
# It is the same one-way rule, applied to the whole path rather than only the
# bytes inside it. Rubric 5.3.
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

# The one substitution rule, as applied to a single path component. Identical
# to the three expressions the content pass uses, so a name and its contents
# are redacted by the same rule. Idempotent: a placeholder maps to itself.
redacted_basename() {
  printf '%s' "$1" | sed \
    -e "s/${ACCOUNT_ID}/${ACCOUNT_PLACEHOLDER}/g" \
    -e 's/AKIA[0-9A-Z]\{16\}/AKIAXXXXXXXXXXXXXXXX/g' \
    -e 's/ASIA[0-9A-Z]\{16\}/ASIAXXXXXXXXXXXXXXXX/g'
}

# Paths whose own name still changes under that rule, i.e. paths that carry an
# unredacted account ID or access key ID. Candidates are found with plain -name
# globs because BSD and GNU find disagree about -regex. -depth is bottom-up, so
# a parent rename cannot invalidate a child's path.
offending_names() {
  find "${TARGETS[@]}" -depth \
       \( -name "*${ACCOUNT_ID}*" -o -name '*AKIA*' -o -name '*ASIA*' \) 2>/dev/null \
    | while IFS= read -r p; do
        base="$(basename "$p")"
        [[ "$(redacted_basename "$base")" == "$base" ]] || printf '%s\n' "$p"
      done
}

check_names() {
  local bad=0 p
  while IFS= read -r p; do
    echo "$p: unredacted account ID or access key ID in path name" >&2
    bad=1
  done < <(offending_names)
  return $bad
}

redact_names() {
  local renamed=0 p base new
  while IFS= read -r p; do
    base="$(basename "$p")"
    new="$(redacted_basename "$base")"
    [[ "$new" == "$base" ]] && continue
    mv "$p" "$(dirname "$p")/$new"
    renamed=$((renamed + 1))
  done < <(offending_names)
  echo "$renamed"
}

if [[ $CHECK_ONLY -eq 1 ]]; then
  # Placeholders are themselves shaped like the things they replace, so the
  # check has to exclude them explicitly or it flags its own output.
  NAMES_OK=1
  check_names || NAMES_OK=0
  if [[ $NAMES_OK -eq 1 ]] && ACCOUNT_ID="$ACCOUNT_ID" perl -ne '
        BEGIN { $a = quotemeta $ENV{ACCOUNT_ID}; $bad = 0; }
        if (/$a/) { print STDERR "$ARGV:$.: unredacted account ID\n"; $bad = 1; }
        while (/(?:AKIA|ASIA)([0-9A-Z]{16})/g) {
          next if $1 eq "X" x 16;
          print STDERR "$ARGV:$.: unredacted access key ID\n";
          $bad = 1;
        }
        close ARGV if eof;   # reset $. per file, or line numbers accumulate
        END { exit($bad ? 1 : 0); }
      ' "${FILES[@]}"; then
    echo "check passed: ${#FILES[@]} file(s), no account ID or access key IDs in contents or path names"
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

RENAMED="$(redact_names)"

echo "redacted ${#FILES[@]} file(s) and renamed ${RENAMED} path(s) under: ${TARGETS[*]}"
exec "$0" --check "${TARGETS[@]}"
