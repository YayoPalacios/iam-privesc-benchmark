# Run metadata

Copy to `raw-output/<tool>/<context>-<flagset>-<date>/run-metadata.md` and fill in
before the run. Required by rubric §5.

## Identity

- **Tool:** pmapper | cloudfox
- **Tool version:**
- **Tool commit hash:**
- **Install method:**
- **Python version:** (PMapper only)
- **Dependency pinning required:** (PMapper only — record exactly what had to
  change to make it run. Rubric §5; this is a finding in itself.)

## Environment under test

- **iam-vulnerable commit hash:**
- **tfvars used:** (values, not the file — `*.tfvars` is gitignored. See
  `terraform.tfvars.example`.)
- **lab-oidc applied at time of run:** yes | no

## Run conditions

- **Context:** admin | limited
  - `limited` is the AWS-managed `SecurityAudit` policy (rubric §5.1).
- **Flagset:** default | flagged
  - A flagged run happens only where a default-run **M** looks flag-fixable
    (rubric §5.2). If flagged, record the exact flag and the M that prompted it.
- **Exact command(s):**
- **Timestamp (UTC, start):**
- **Caller identity:** output of `aws sts get-caller-identity --profile personal`,
  post-redaction.

Wall-clock duration is deliberately not recorded — rubric §1 and §5.

## Outcome

- **Exit status:**
- **Crashed / skipped principals:** (rubric §4.7 — these grade M but are tallied
  separately from detection misses.)
- **Total paths reported:** (rubric §4.8 — the FP denominator. Required.)
- **Redaction applied:** `./redact.sh` run at:
