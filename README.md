# IAM tool benchmark

A per-scenario detection matrix comparing PMapper and cloudfox against Bishop
Fox's iam-vulnerable lab. Track B, phase 1. `iamwho` is deliberately not part of
this phase — it gets measured later, against a baseline built without it.

**Nothing is deployed yet.** The rubric is frozen (commit `f2e62ee`); the lab
has not been cloned or applied.

## Teardown

`terraform destroy` in **both** `lab/` and `lab-oidc/`. Do not leave a lab full
of live privilege-escalation paths running.

## Layout

```
analysis/
  rubric.md           frozen before Phase 2; append-only thereafter
  scenarios.md        generated from Terraform state + the AWS API (Phase 1)
  grades.csv          source of truth for every grade
  validation/         manual proof, one file per scenario
  matrix.md           the deliverable, written by hand from grades.csv
raw-output/           unedited tool output, one dir per run
lab/                  iam-vulnerable, unmodified
lab-oidc/             Phase 5 OIDC scenario, separate state
redact.sh             one-way account ID / access key ID substitution
```

## Conventions

**Run directories.** `raw-output/<tool>/<context>-<flagset>-<date>/`, each with a
`run-metadata.md` copied from `raw-output/run-metadata.template.md`. Contexts are
`admin` and `limited`; flagsets are `default` and `flagged`. See
`raw-output/README.md`.

**Grades.** `analysis/grades.csv` is the source of truth — one row per
`(scenario, tool, context, flagset)`:

| column | values |
|---|---|
| `scenario_id` | stable ID, matches the validation filename |
| `principal` | the principal half of the scenario row |
| `mechanism` | the mechanism half; headline numbers roll up to this |
| `tool` | `pmapper` \| `cloudfox` |
| `context` | `admin` \| `limited` |
| `flagset` | `default` \| `flagged` |
| `grade` | `D` \| `P` \| `M` \| `FP` \| `N/A` |
| `evidence_path` | path under `raw-output/`, plus the exact query or search used |
| `validation_status` | `validated` \| `inferred` |
| `note` | required for `FP`, `N/A`, and anything graded under rubric §4.5 or §4.6 |

`validation_status` is a published column, not a caveat in prose. Most rows will
be `inferred`; the matrix has to say which.

`matrix.md` is written **by hand** from this file. There is no generator.

**Validation.** `analysis/validation/<scenario_id>.md`, one per scenario, exact
commands and outcomes. See `analysis/validation/README.md`.

**Redaction.** Run `./redact.sh` over `raw-output/` before any commit that adds
tool output, and `./redact.sh --check` to verify. It reads the account ID from
`.account-id` (gitignored — create it with
`aws sts get-caller-identity --profile personal --query Account --output text`).
Placeholders keep the shape of what they replace, so ARNs stay well-formed and
JSON stays parseable. The script is committed alongside its output: "unedited"
means "unedited modulo one auditable rule."

**Terraform variables.** `*.tfvars` is gitignored, so `terraform.tfvars.example`
plus the values recorded in each `run-metadata.md` are the only record of what
was deployed. The iam-vulnerable commit hash is pinned in run metadata.

## Account hygiene

Dedicated personal AWS sandbox account, profile `personal`. Every AWS call uses
`--profile personal` or an explicit `AWS_PROFILE`. Other profiles on this machine
are work accounts. Confirm `aws sts get-caller-identity` before anything.

Repo stays private until the writeup is ready.
