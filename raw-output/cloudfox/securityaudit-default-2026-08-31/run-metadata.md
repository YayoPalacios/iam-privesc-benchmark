# Run metadata

Required by rubric §5. This is the `limited` context of rubric §5.1, run as the
AWS-managed `SecurityAudit` policy.

Per §5.1 this run **is not graded per scenario**. It is reported as a qualitative
delta against `../admin-default-2026-08-31/`. Nothing below is a grade.

## Identity

Identical to the admin run — same binary, nothing reinstalled.

- **Tool:** cloudfox
- **Tool version:** `2.0.5`
- **Tool commit hash:** `ba4ff4701a537750f0aa11b1fb0ffa1f545cc000`
- **Install method:** official release binary `cloudfox-macos-arm64.zip`; binary
  SHA-1 `ced12705cb84606d97dc41c83ad187725f0d44a0`. At `tools/bin/cloudfox`.
- **Python version:** n/a
- **Dependency pinning required:** none

## The limited principal

Rubric §5.1 requires `SecurityAudit` "attached to a purpose-made principal". No
such principal existed, so one was created for this run:

| | |
|---|---|
| Principal | `arn:aws:iam::000000000000:user/benchmark-securityaudit` |
| Created | 2026-08-31T01:47:41Z, by `user/iamadmin` |
| Policy | `arn:aws:iam::aws:policy/SecurityAudit`, attached; nothing else |
| Tags | `purpose=iam-tool-benchmark`, `phase=2`, `rubric=5.1` |
| Credentials | one access key, in `~/.aws/credentials` as profile `benchmark-securityaudit`. The pre-existing credentials file was backed up to `~/.aws/credentials.bak-2026-08-31-benchmark` before the profile was appended. |

Verified read-only before the run: `iam:CreateUser` returns
`AccessDenied … no identity-based policy allows the iam:CreateUser action`, while
`iam:ListUsers` succeeds.

**Teardown**, for the README's teardown section — `terraform destroy` will not
remove this, since Terraform never created it:

```
aws iam delete-access-key --profile personal --user-name benchmark-securityaudit --access-key-id <id>
aws iam detach-user-policy --profile personal --user-name benchmark-securityaudit \
    --policy-arn arn:aws:iam::aws:policy/SecurityAudit
aws iam delete-user --profile personal --user-name benchmark-securityaudit
```

### This principal did not exist during the admin runs

It is the 95th principal, and it is **not** a scenario row — it is benchmark
apparatus, like `iamadmin`. It must be excluded from any denominator, the same
way `scenarios.md` excludes the other non-lab principals. Every count below is
given both raw and with this principal removed, so the comparison against the
admin run is like-for-like.

Creating it also means the account is no longer bit-identical to the one
`analysis/account-baseline.md` describes. That file should gain a line for this
user before Phase 4.

## Environment under test

- **iam-vulnerable commit hash:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **tfvars used:** `aws_local_profile = "personal"`, everything else default.
- **lab-oidc applied at time of run:** **no.**
- **PMapper data on disk at start:** **none.** PMapper's storage was cleared
  before this run and the `ls` proving it is in `console.txt`. This matters: the
  admin cloudfox run also had none, so the only difference between the two
  cloudfox runs is the principal. cloudfox confirms it in its own output —
  `[pmapper][benchmark-securityaudit] No pmapper data found for this account.`

## Run conditions

- **Context:** `limited` (`SecurityAudit`), directory-named `securityaudit`.
- **Flagset:** `default`
- **Exact command:**

  ```
  ./tools/bin/cloudfox aws all-checks -p benchmark-securityaudit -y \
      --outdir <this-run-dir>/cloudfox-outdir
  ```

  **Identical to the admin run except the profile name.** Same flags, same
  aggregate entry point, same deliberate omissions (`--skip-admin-check`,
  `-c/--cached`, `-o wide`, `--pmapper-data-basepath` all unused).

- **Timestamp (UTC, start):** `2026-08-31T01:49:52Z` (end `2026-08-31T01:53:40Z`)
- **Caller identity** (post-redaction):

  ```json
  {
      "UserId": "AIDAZV7NGMXUPAGKPKUG3",
      "Account": "000000000000",
      "Arn": "arn:aws:iam::000000000000:user/benchmark-securityaudit"
  }
  ```

## Outcome

- **Exit status:** `0`

### Total paths reported (rubric §4.8)

**Escalation paths reported: 0** — same as the admin run, and for the same
reason. All 95 `principals.json` rows, all 44 `role-trusts-principals.json` rows,
the 1 root-trust row and the 1 workload row read
`CanPrivEscToAdmin?: Skipping, no pmapper data`. cloudfox has no independent path
finder; see the admin run's metadata for the documented delegation to PMapper.

| Surface | admin | SecurityAudit | SA minus the new principal |
|---|---:|---:|---:|
| escalation paths | 0 | 0 | 0 |
| `iam-simulator` rows | 78 | 80 | 77 |
| `iam-simulator` — `Appears to be an administrator` | 3 | 3 | 3 |
| `permissions` rows | 6008 | 7039 | **6008** |
| `principals` | 94 | 95 | 94 |
| `principals` — `IsAdminRole? = YES` | 3 | 3 | 3 |
| `access-keys` | 43 | 44 | 43 |
| `role-trusts-principals` | 44 | 44 | 44 |
| `role-trusts-services` | 17 | 17 | 17 |
| `role-trusts-federated` | 0 | 0 | 0 |
| root-trusts-without-external-id | 1 | 1 | 1 |
| `resource-trusts` | 3 | 3 | 3 |
| `workloads` / `workloads-admin` | 1 / 0 | 1 / 0 | 1 / 0 |

### The delta: cloudfox lost essentially nothing under SecurityAudit

Checked by direct comparison of the two runs' JSON, not by eye:

- **All 94 principals present in both runs are field-for-field identical.** Every
  key of every row of `principals.json` matches — including `IsAdminRole?`. Zero
  differences.
- **`permissions.json` is byte-identical** once the new principal's own rows are
  removed: 6008 rows in both, comparing equal as parsed JSON. The +1031 raw delta
  is entirely `SecurityAudit`'s own grants on the new user.
- **`role-trusts-principals`, `role-trusts-services`, `role-trusts-federated`,
  the root-trust file, `resource-trusts`, `workloads`, `workloads-admin`, `sns`,
  `lambda` and `tags` are all identical between the two runs.**
- `inventory.json` differs in exactly three cells: IAM Users 42→43, IAM Access
  Keys 43→44, Total 140→142.
- The same three principals are named administrators in both runs:
  `role/privesc-high-priv-service-role`, `role/privesc-AssumeRole-ending-role`,
  `user/iamadmin`.

`iam-simulator` differs by 4 rows: 3 gained, all for the new principal; and
**1 lost** — `user/fn1-privesc3-partial-user | can iam:PassRole on *`. That loss
is throttling, not privilege; see below.

**This bears on pre-registered prediction §8.2** — *"The `limited`
(`SecurityAudit`) run shows a materially reduced output surface for both tools,
qualitatively."* For cloudfox the observed reduction is nil. Recorded as an
observation; whether the prediction is falsified is a Phase 4 judgement, and the
PMapper half of the prediction is still outstanding.

### What failed differently under reduced privilege

The interesting part is not the output, which barely moved, but the failure
modes, which changed shape. Error-log totals: **62 lines under admin, 104 under
SecurityAudit.**

| Call | admin | SecurityAudit | Reading |
|---|---|---|---|
| `Glue: ListDevEndpoints` | 17 × `InternalFailure` | 17 × **`AccessDeniedException`** | **The important one.** See below. |
| `Glue: ListJobs` | — (succeeded) | 17 × `AccessDeniedException` | `SecurityAudit` omits `glue:ListJobs` |
| `Glue: GetResourcePolicies` | — (succeeded) | 17 × `AccessDeniedException` | `SecurityAudit` omits `glue:GetResourcePolicies` |
| `codeartifact: ListDomains` | — (succeeded; 0 occurrences in the admin log) | 12 × `AccessDeniedException` | `SecurityAudit` omits `codeartifact:ListDomains` |
| `IAM: SimulatePrincipalPolicy` | 3 × `Throttling` | 1 × `Throttling` | nondeterministic, not privilege |
| `AppRunner: ListServices` | 24 × DNS `no such host` | 24 × DNS `no such host` | unchanged; regions with no AppRunner endpoint |
| `Organizations: DescribeOrganization` | 2 | 2 | unchanged; account is not in an org |
| `Lambda: GetFunctionUrlConfig` | 1 × 404 | 1 × 404 | unchanged |

**The Glue dev-endpoint case is the one worth a paragraph.** Under admin,
`ListDevEndpoints` fails 17 times with `InternalFailure` — AWS's response to a
retired feature, which is the evidence `scenarios.md` cites for
`privesc18`/`privesc19` being `target_absent = yes`. Under `SecurityAudit` the
same call fails 17 times with `AccessDeniedException` instead, because the policy
does not grant `glue:ListDevEndpoints`.

The tool's *output* is the same either way — no Glue findings — but the reason is
different, and only the admin run's reason is informative. An auditor holding
`SecurityAudit` cannot distinguish "this capability no longer exists" from "I am
not allowed to look", and both render as an absent section in the report. That
is a real limitation of running these tools at auditor privilege, and it is
invisible unless you read the error log.

- **Crashed / skipped principals (rubric §4.7):** **1**, versus 3 under admin,
  and a *different* principal:

  ```
  module=iam-simulator msg="Failed to query actions for
      arn:aws:iam::000000000000:user/fn1-privesc3-partial-user"
  ```

  preceded by one `SimulatePrincipalPolicy … Throttling: Rate exceeded`. The
  admin run lost `privesc10-PutUserPolicy-role`,
  `privesc-codeBuildCreateProjectPassRole-user` and
  `privesc6-UpdateLoginProfile-user`; this run lost none of those and lost one
  the admin run kept.

  **The overlap is empty, which means the skips are throttling noise, not a
  property of either context.** Same caveat as the admin run: the failure is
  visible only in `cloudfox-error.log`, and the affected principal still appears
  in the tables looking like an ordinary negative result. `SecurityAudit` does
  grant `iam:SimulatePrincipalPolicy` — the module worked for 40 principals.

- **Redaction applied:** `./redact.sh raw-output/cloudfox`, run
  **2026-08-31T01:56 UTC**, over both cloudfox run directories together. Result:
  *"redacted 113 file(s) and renamed 1 path(s)"*, then *"check passed: 113
  file(s), no account ID or access key IDs in contents or path names"*. The
  renamed path is this run's output directory,
  `cloudfox-output/aws/benchmark-securityaudit-<account-id>`. The new principal's
  access key ID is replaced by the `AKIAXXXXXXXXXXXXXXXX` placeholder in
  `access-keys.json`, by the same rule.

- **Same deviation as the admin run:** cloudfox's API response cache
  (`cached-data/`) was moved to `tools/cloudfox-cache/` rather than committed.
  See `cached-data-NOT-COMMITTED.md` in this directory.

## Files in this run directory

Same layout as the admin run: `console.txt`, `cloudfox-outdir/cloudfox-output/`,
`cloudfox-logs/` (both logs truncated to 0 bytes immediately before this run, so
their contents belong to it alone), and `cached-data-NOT-COMMITTED.md`.
