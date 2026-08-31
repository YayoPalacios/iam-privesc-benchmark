# Removal of iamwho test fixtures — 2026-08-31

Contamination fix, performed after the lab was deployed and `scenarios.md` was
generated, and **before any tool was run**. Recorded here because it changes the
account the benchmark measures, and the writeup needs to be able to say what was
removed and why.

## Why

`iamwho` is the author's own tool. It is deliberately excluded from phase 1 so
that PMapper and cloudfox are measured against a baseline built without it. That
property does not survive leaving `iamwho`'s test fixtures in the account: both
tools would have reported paths through them, inflating the denominator with
findings that are neither lab scenarios nor false positives, and the "baseline
you did not build around it" claim would not have held.

Several fixtures also duplicated lab mechanisms outright — `iam:CreateAccessKey`
(privesc4), `iam:PassRole` + `ec2:RunInstances` (privesc3), and
`lambda:UpdateFunctionCode` (privesc17) — so their presence would have been
double-counted against the same techniques.

## What was deleted

11 IAM roles, all created 2026-01-25, all at path `/`. Every policy below was an
**inline** role policy and was deleted with its role. No customer-managed policy
was deleted, because the fixtures used none.

| Role | Trust principal | Inline policy | Effective grant |
|---|---|---|---|
| `iamwho-test-clean` | `lambda.amazonaws.com` | `minimal-read` | `logs:CreateLogGroup/CreateLogStream/PutLogEvents` on one log group |
| `iamwho-test-confuseddeputy` | `events`, `lambda`, `apigateway` | `moderate-access` | `dynamodb:*`, `sqs:*` on `*` |
| `iamwho-test-crossaccount` | `:root` | _(none — AWS-managed only)_ | `ReadOnlyAccess` |
| `iamwho-test-dataexfil` | `lambda.amazonaws.com` | `data-access` | `s3:GetObject/ListBucket`, `secretsmanager:GetSecretValue`, `ssm:GetParameter(s)`, `kms:Decrypt` on `*` |
| `iamwho-test-escalation` | `ec2.amazonaws.com` | `sneaky-escalation` | `iam:CreateRole/AttachRolePolicy/PutRolePolicy`, `sts:AssumeRole` on `*` |
| `iamwho-test-godmode` | **`AWS: "*"`** | `admin-access` | `Allow *:*` |
| `iamwho-test-lambdabackdoor` | `:root` | `lambda-code-injection` | `lambda:UpdateFunctionCode/UpdateFunctionConfiguration/InvokeFunction` on `*` |
| `iamwho-test-mixedbag` | `ecs-tasks.amazonaws.com` | `inline-danger` | `iam:CreateAccessKey` on `*`, plus `AmazonS3ReadOnlyAccess` |
| `iamwho-test-notaction` | `lambda.amazonaws.com` | `notaction-trap` | `Allow NotAction iam:*, organizations:*` on `*` |
| `iamwho-test-passrole` | `ec2.amazonaws.com` | `dangerous-passrole` | `iam:PassRole` on `*`, `ec2:RunInstances`, `lambda:CreateFunction`, `glue:CreateJob` |
| `iamwho-test-wildcard-org` | **`AWS: "*"`** | `read-only` | `s3:GetObject` on `*` |

Two of these — `iamwho-test-godmode` and `iamwho-test-wildcard-org` — carried a
trust policy naming `AWS: "*"`, i.e. assumable by any principal in any AWS
account. `godmode` combined that with `Allow *:*`. Removing them is worth doing
on its own merits, independent of the benchmark.

## AWS-managed policies detached, not deleted

- `arn:aws:iam::aws:policy/ReadOnlyAccess` — detached from `iamwho-test-crossaccount`
- `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess` — detached from `iamwho-test-mixedbag`

Both verified still present afterwards.

## Commands

For each role: `iam delete-role-policy` for every inline policy,
`iam detach-role-policy` for every managed attachment, then `iam delete-role`.
Caller identity was verified against `.account-id` immediately before the first
deletion.

## Verification

After removal, all four of these return empty:

```
aws iam list-roles    --query 'Roles[?starts_with(RoleName,`iamwho`)]'
aws iam list-users    --query 'Users[?starts_with(UserName,`iamwho`)]'
aws iam list-groups   --query 'Groups[?starts_with(GroupName,`iamwho`)]'
aws iam list-policies --scope Local --query 'Policies[?starts_with(PolicyName,`iamwho`)]'
```

## Second pass, same day: the fixture stack and its bucket

**Deleted.** `iamwho-stress-test-roles` (us-west-2, created 2026-01-25) was the
CloudFormation stack that created all 11 roles above. After they were removed out
of band it held no live resources at all.

Dependency check before deleting: its resource list was exactly those 11 IAM
roles, all already gone; `list-exports` returned empty, so no stack could be
importing from it; and it was the only stack in any of the 17 enabled regions.

**Deleted:** `cf-templates-1ajkstp6a3kyv-us-west-2` and its 9 objects —
CloudFormation's auto-created template staging bucket. Every one of the 9
templates was verified as `iamwho` residue first: all dated 2026-01-13 to
2026-01-25, all described as "IAM test roles for iamwho testing" or "IAMWho
Stress Test Roles", all defining only `iamwho-test-*` roles. Nothing else had
ever been staged there. CloudFormation recreates such a bucket on demand.

The two newest templates carried an OIDC role definition
(`iamwho-test-oidc-nosub`, a GitHub Actions trust with no `sub` condition) that
was **commented out and never deployed**. The account has no OIDC or SAML
provider, confirmed by `list-open-id-connect-providers` and
`list-saml-providers`. Phase 5 therefore starts from a clean slate — worth
knowing, since a pre-existing federation artifact would have muddied the one
finding in this project that is genuinely novel.

**Consequence:** `privesc-CloudFormationUpdateStack` returns to
`target_absent = yes`. It was briefly `no` because this stack was the only one in
the account. Scoring the tools against a target that existed only because the
withheld tool's leftovers put it there would not have been defensible. See the
Corrections table in `scenarios.md`.

## Kept, deliberately

**The `EC2-AutoRemediation` Lambda.** See `account-baseline.md` and the
`privesc17` note in `scenarios.md`. It predates everything here, is unrelated to
`iamwho`, and makes `privesc17` a live overstated-impact test case under rubric
§4.8. Do not delete it during teardown; Terraform never created it and
`terraform destroy` will not touch it.

## Residue check, after both passes

All empty, account-wide:

```
aws iam list-roles       --query 'Roles[?contains(RoleName,`iamwho`)]'
aws iam list-users       --query 'Users[?contains(UserName,`iamwho`)]'
aws iam list-groups      --query 'Groups[?contains(GroupName,`iamwho`)]'
aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName,`iamwho`)]'
aws cloudformation describe-stacks   # zero stacks, all 17 enabled regions
aws s3api list-buckets               # zero buckets
```
