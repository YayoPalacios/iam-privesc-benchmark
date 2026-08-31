# Run metadata

Required by rubric §5.

## Identity

- **Tool:** cloudfox
- **Tool version:** `2.0.5`
- **Tool commit hash:** `ba4ff4701a537750f0aa11b1fb0ffa1f545cc000`
  (release `v2.0.5`, published 2026-05-26; annotated tag object
  `ad787c28cfdc57df48edbaa7924b976a28078e42` dereferenced via the GitHub API,
  since the binary embeds no commit)
- **Install method:** official release binary `cloudfox-macos-arm64.zip`.
  Archive SHA-256 `04c13e576953d46501ad20885c109a740014391baa40c168703a0e7cc470d060`;
  extracted binary SHA-1 `ced12705cb84606d97dc41c83ad187725f0d44a0`, matching the
  `sha1sum.txt` shipped in the release. Installed at `tools/bin/cloudfox`.
  No Go toolchain involved; none is installed on this machine.
- **Python version:** n/a
- **Dependency pinning required:** none. Full install record and the contrast
  with PMapper: `analysis/tool-install.md`.

## Environment under test

- **iam-vulnerable commit hash:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **tfvars used:** `aws_local_profile = "personal"`; every other variable at its
  default. In particular `aws_assume_role_arn = ""`, so all 45 lab roles trust
  `user/iamadmin`. Full record: `raw-output/lab-deployment.md`.
- **lab-oidc applied at time of run:** **no.** `lab-oidc/` contains only its
  README; no Terraform has been written or applied there. There is no OIDC or
  SAML provider in the account (`account-baseline.md`).

## Run conditions

- **Context:** `admin` — `user/iamadmin`, `AdministratorAccess`.
- **Flagset:** `default`
- **Exact command:**

  ```
  ./tools/bin/cloudfox aws all-checks -p personal -y \
      --outdir <this-run-dir>/cloudfox-outdir
  ```

  `all-checks` is cloudfox's own aggregate entry point — *"Run all of the other
  checks (excluding outbound-assumed-roles)"* — and it covers every module
  CLAUDE.md names for this phase (`permissions`, `principals`, `role-trusts`,
  `iam-simulator`) plus the rest.

  **On the three flags, per rubric §4.2.** None of them changes what cloudfox
  looks for or reports; they are invocation plumbing, and the headline grade is
  still the default run:

  | Flag | Why | Detection effect |
  |---|---|---|
  | `-p personal` | selects the sandbox profile; required by CLAUDE.md | none |
  | `-y` | non-interactive, so `all-checks` does not stop on a prompt | none |
  | `--outdir` | writes into this run directory instead of `~/.cloudfox` | none — output location only |

  **Detection-affecting flags deliberately NOT used:** `--skip-admin-check` (so
  the admin check did run), `-c/--cached` (data was fetched fresh, not replayed),
  `-o wide` (left at the `brief` default), `--pmapper-data-basepath`,
  `--include-kms`, and `-m/--max-resources-per-region` on `tags` — cloudfox notes
  in the transcript that it therefore looked at at most 1000 resources per region
  for tags.

- **Timestamp (UTC, start):** `2026-08-31T01:17:02Z` (end `2026-08-31T01:21:02Z`;
  duration deliberately not treated as a measurement, rubric §1)
- **Caller identity** (post-redaction):

  ```json
  {
      "UserId": "AIDAZV7NGMXUIHN6FVLRB",
      "Account": "000000000000",
      "Arn": "arn:aws:iam::000000000000:user/iamadmin"
  }
  ```

### Tool independence

cloudfox 2.0.5 ships two modules that consume PMapper's data when it exists on
disk: `aws pmapper` and `aws cape`. **This run was executed before PMapper had
ever run on this machine**, and the absence was verified immediately beforehand —
`~/.local/share/principalmapper` and
`~/Library/Application Support/com.nccgroup.principalmapper` both did not exist.

cloudfox recorded the same fact itself, in this run's own output:

```
[pmapper][personal] No pmapper data found for this account.
```

and in `cloudfox-logs/cloudfox-error.log`:

```
module=pmapper msg="open .../com.nccgroup.principalmapper/000000000000/graph/nodes.json: no such file or directory"
```

## Outcome

- **Exit status:** `0`

- **Modules that produced output (15):** `access-keys`, `iam-simulator`,
  `inventory`, `lambda`, `permissions`, `principals`, `resource-trusts`,
  `role-trusts-federated`, `role-trusts-principals`,
  `role-trusts-principals-root-trusts-without-external-id`,
  `role-trusts-services`, `sns`, `tags`, `workloads`, `workloads-admin`.

  **Modules that ran and found nothing (20):** `api-gw`, `buckets`,
  `cloudformation`, `codebuild`, `databases`, `ecr`, `ecs-tasks`, `eks`,
  `elastic-network-interfaces`, `endpoints`, `env-vars`, `filesystems`,
  `instance-userdata`, `instances`, `network-ports`, `ram`, `role-trusts`
  (the federated sub-check), `route53`, `secrets`, `sqs`. These are consistent
  with `account-baseline.md`: the account genuinely holds none of those
  resources.

- **Crashed / skipped principals (rubric §4.7 — tally separately from detection
  misses):** **3 principals**, all in the `iam-simulator` module, all caused by
  `IAM: SimulatePrincipalPolicy ... api error Throttling: Rate exceeded` after
  cloudfox exhausted its 3 retry attempts. Verbatim from
  `cloudfox-logs/cloudfox-error.log`:

  | Principal | Failure | Effect |
  |---|---|---|
  | `role/privesc10-PutUserPolicy-role` | `Failed admin check` | admin determination not made; the row still prints `IsAdminRole? = No` |
  | `user/privesc-codeBuildCreateProjectPassRole-user` | `Failed admin check` | same |
  | `user/privesc6-UpdateLoginProfile-user` | `Failed to query actions` | no `iam-simulator` rows produced for this principal at all |

  **These failures are not visible in the tool's output surface.** They appear
  only in `cloudfox-error.log`, and the affected principals still appear in the
  tables with a `No` in the admin column, which is indistinguishable from a
  negative result. A grader working from `json/` and `table/` alone would not
  know these three were never evaluated. Recorded here so the Phase 4 grading
  can treat them under §4.7 instead of scoring them as detections or misses.

  Non-principal errors in the same log, none of which skipped a principal:
  `Organizations: DescribeOrganization` (account is not in an org — expected),
  `AppRunner: ListServices` DNS failures in 6 regions where the service has no
  endpoint, `Lambda: GetFunctionUrlConfig` 404, and 16 ×
  `Glue: ListDevEndpoints ... InternalFailure` — the last being AWS's retirement
  of Glue dev endpoints, which `scenarios.md` already records as the reason
  `privesc18` and `privesc19` are `target_absent = yes`.

- **Total paths reported (rubric §4.8 — the FP denominator):**

  **Escalation paths reported: 0.**

  This is a property of the run, not a scoring judgement, and it needs stating
  plainly because it determines what a false-positive denominator can even mean
  for this tool. cloudfox's path column is `CanPrivEscToAdmin?`, and in this run
  **every instance of it reads `Skipping, no pmapper data`**:

  | Output | Rows | `CanPrivEscToAdmin?` |
  |---|---:|---|
  | `principals.json` | 94 | `Skipping, no pmapper data` × 94 |
  | `role-trusts-principals.json` | 44 | `Skipping, no pmapper data` × 44 |
  | `role-trusts-principals-root-trusts-without-external-id.json` | 1 | `Skipping, no pmapper data` × 1 |
  | `workloads.json` | 1 | `Skipping, no pmapper data` × 1 |
  | `workloads-admin.json` | 0 | — |

  cloudfox delegates privilege-escalation *path* enumeration to PMapper and has
  no independent path finder. Its `iam-simulator` loot file is explicit about
  this, emitting 16 `pmapper` commands to run instead, prefaced in the console
  by: *"We suggest running the pmapper commands in the loot file to get the same
  information but taking privesc paths into account."*

  So the denominator has to be stated per surface rather than as one number.
  What cloudfox did report in this run:

  | Surface | Count | What one row is |
  |---|---:|---|
  | `iam-simulator.json` | **78** | a (principal, assertion) pair — 3 `Appears to be an administrator` + 75 `can <action> on *`, over 40 distinct principals and 16 distinct queries |
  | `principals.json` — `IsAdminRole? = YES` | **3** | a principal asserted to be an administrator |
  | `role-trusts-principals.json` — `IsAdmin? = YES` | **1** | an admin role reachable by a trusted principal |
  | `role-trusts-services.json` — `IsAdmin? = YES` | **10** | an admin role trusted by an AWS service |
  | `permissions.json` | **6008** | a (principal, action, resource, effect) grant — 6001 Allow / 7 Deny, 20 carrying a condition, over 90 principals |
  | `principals.json` | **94** | an IAM principal — 42 users, 52 roles |
  | `access-keys.json` | **43** | an active access key |
  | `role-trusts-principals.json` | **44** | a role → trusted-principal edge |
  | `role-trusts-services.json` | **17** | a role → trusted-service edge |
  | `role-trusts-federated.json` | **0** | — (no federated trusts; no IdP in the account) |
  | `role-trusts-...-root-trusts-without-external-id.json` | **1** | `role/privesc-permissive-role-trust` |
  | `resource-trusts.json` | **3** | a resource policy |
  | `workloads.json` | **1** | a compute workload with a role |

  The three principals cloudfox names as administrators are
  `role/privesc-AssumeRole-ending-role`, `user/iamadmin`, and
  `role/privesc-high-priv-service-role`. Note this count is on the low side by an
  unknown amount: two of the three throttled failures above were admin checks
  that never completed.

  **No FP determination is made here.** Rubric §6 requires manual validation
  before anything is called a false positive, and that is Phase 3.

### cloudfox documents that it does not enumerate paths itself

Recorded here because it bears on whether cloudfox's path column can be graded
at all, and because the rubric requires the disclaimer to be quoted and linked
rather than paraphrased.

**Rubric reference.** The N/A grade and its evidentiary bar are §3 (the grade
table) and **§4.9** — *"N/A requires a quoted disclaimer. N/A applies only where
the tool's own documentation explicitly states it does not cover the category.
Quote the sentence and link the source in the cell note."* (§4.3 is "Right
answer, wrong mechanism" and is a different rule; noting this only so the
citation in the matrix ends up pointing at the right paragraph.)

#### 1. The tool's documentation — the §4.9 source

<https://github.com/BishopFox/cloudfox/wiki/AWS-Commands#pmapper>, the page
cloudfox itself prints a link to during the run:

> Cloudfox will not install or run `pmapper` for you, but because `pmapper`
> stores it's graph data in a predictable location, this CloudFox command will
> look to see if that data exists, and if it does, it give you a list of all of
> the principals that pmapper thinks can escalate to admin.

> Also, if the `pmapper` data is found, a bunch of the other cloudfox commands
> will use the data. If the data is not found, they will use CloudFox's
> `iam-simulator` command to try to figure out who is an admin, which is really
> just a wrapper around AWS's IAM simulate principal policy API call.

The same page describes PMapper as *"the most accurate open source AWS policy
simulator project that takes into account privilege escalation."*

This is a documentation statement, not merely tool output: cloudfox states that
without PMapper data its fallback answers "who is an admin", not "what paths
exist".

#### 2. The loot file — the delegation in cloudfox's own output

Path, in this run directory:

```
cloudfox-outdir/cloudfox-output/aws/personal-000000000000/loot/iam-simulator-pmapper-commands.txt
```

16 lines, verbatim — one `graph create` and 15 `query` commands, all of them
`pmapper`, none of them cloudfox:

```
pmapper --profile personal graph create
pmapper --profile personal query "who can do sts:AssumeRole with *" | tee iam-simulator/loot/pmapper-output-sts:AssumeRole.txt
pmapper --profile personal query "who can do iam:PassRole with *" | tee iam-simulator/loot/pmapper-output-iam:PassRole.txt
pmapper --profile personal query "who can do secretsmanager:GetSecretValue with *" | tee iam-simulator/loot/pmapper-output-secretsmanager:GetSecretValue.txt
pmapper --profile personal query "who can do ssm:GetParameter with *" | tee iam-simulator/loot/pmapper-output-ssm:GetParameter.txt
pmapper --profile personal query "who can do s3:ListBucket with *" | tee iam-simulator/loot/pmapper-output-s3:ListBucket.txt
pmapper --profile personal query "who can do s3:GetObject with *" | tee iam-simulator/loot/pmapper-output-s3:GetObject.txt
pmapper --profile personal query "who can do ssm:SendCommand with *" | tee iam-simulator/loot/pmapper-output-ssm:SendCommand.txt
pmapper --profile personal query "who can do ssm:StartSession with *" | tee iam-simulator/loot/pmapper-output-ssm:StartSession.txt
pmapper --profile personal query "who can do ecr:BatchGetImage with *" | tee iam-simulator/loot/pmapper-output-ecr:BatchGetImage.txt
pmapper --profile personal query "who can do ecr:GetAuthorizationToken with *" | tee iam-simulator/loot/pmapper-output-ecr:GetAuthorizationToken.txt
pmapper --profile personal query "who can do eks:UpdateClusterConfig with *" | tee iam-simulator/loot/pmapper-output-eks:UpdateClusterConfig.txt
pmapper --profile personal query "who can do lambda:ListFunctions with *" | tee iam-simulator/loot/pmapper-output-lambda:ListFunctions.txt
pmapper --profile personal query "who can do ec2:DescribeInstanceAttributeInput with *" | tee iam-simulator/loot/pmapper-output-ec2:DescribeInstanceAttributeInput.txt
pmapper --profile personal query "who can do sns:Subscribe with *" | tee iam-simulator/loot/pmapper-output-sns:Subscribe.txt
pmapper --profile personal query "who can do sqs:SendMessage with *" | tee iam-simulator/loot/pmapper-output-sqs:SendMessage.txt
```

#### 3. The console, in `console.txt`

> `[iam-simulator][personal] We suggest running the pmapper commands in the loot
> file to get the same information but taking privesc paths into account.`

> `[pmapper][personal] No pmapper data found for this account.`
> `			1. Generate pmapper data by running `pmapper --profile personal graph create``
> `			2. After that completes, cloudfox will attempt to enrich this command and others with pmapper privesc data`

> `[pmapper][personal] For more info and troubleshooting steps: https://github.com/BishopFox/cloudfox/wiki/AWS-Commands#pmapper`

And in `cloudfox aws --help`, the module descriptions:

> `pmapper   Looks for pmapper data for the account and builds a PrivEsc graph in golang if it exists.`

> `cape      Cross-Account Privilege Escalation Route finder. ... Needs pmapper data to be present`

#### What this means for the matrix

**cloudfox and PMapper are not independent columns on path-based scenarios.**
cloudfox's `CanPrivEscToAdmin?` column is a rendering of PMapper's graph, by
cloudfox's own design and documentation. Grading them side by side as peers on
those scenarios would misstate both:

- It would credit cloudfox for detections that are PMapper's, in any run where
  PMapper data happens to be on disk.
- It would penalise cloudfox for misses that are PMapper's.
- It would double-count agreement between the two columns as corroboration, when
  the two columns are the same computation read twice.

On the surfaces cloudfox does own — `permissions`, `principals`, `role-trusts`,
`iam-simulator`, `workloads`, `access-keys`, `resource-trusts` — the columns are
genuinely independent, and PMapper has no equivalent of several of them.

**This is recorded, not applied.** No grade, column structure or denominator has
been changed on the strength of it; `analysis/grades.csv` and the matrix are
untouched. The open question for Phase 4 is whether cloudfox's path column is
**N/A** under §4.9 (the disclaimer above is quoted and linked, which is what
§4.9 asks for) or whether the path scenarios simply do not admit a cloudfox
column at all. That is a structural decision about the matrix, and it is not
made here.

- **Redaction applied:** `./redact.sh raw-output/cloudfox`, run
  **2026-08-31T01:26 UTC**. Result: *"redacted 57 file(s) and renamed 1 path(s)"*,
  then *"check passed: 57 file(s), no account ID or access key IDs in contents or
  path names"*. The one renamed path is this run's output directory:
  `cloudfox-output/aws/personal-<account-id>` became
  `cloudfox-output/aws/personal-000000000000`. `redact.sh` covers path names as
  well as file contents from 2026-08-31 (rubric §9 amendment of that date); see
  `raw-output/README.md`.

- **One deviation from "committed unedited":** cloudfox's own AWS API response
  cache, which `--outdir` also writes, was moved out of this directory before
  commit. It is an input to cloudfox rather than a finding by it, it is 36 MB of
  mostly binary `.gob`, and it carries the account ID in all 1838 filenames.
  Moved, not deleted. See `cached-data-NOT-COMMITTED.md` in this directory.

## Files in this run directory

- `console.txt` — full stdout/stderr transcript, including the caller identity
  check made before the run.
- `cloudfox-outdir/cloudfox-output/aws/<profile>-<account>/` — the tool's output,
  in `json/`, `csv/`, `table/` and `loot/`.
- `cloudfox-logs/cloudfox-error.log`, `cloudfox-logs/cloudfox-info.log` —
  cloudfox writes these to `~/.cloudfox` regardless of `--outdir`, so they are
  copied in. Both were 0 bytes immediately before this run, so their entire
  contents belong to it. The error log is the only place the 3 skipped
  principals are recorded.
- `cached-data-NOT-COMMITTED.md` — where the API cache went and why.
