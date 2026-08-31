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

## Left in place, deliberately

**The `iamwho-stress-test-roles` CloudFormation stack (us-west-2,
`CREATE_COMPLETE`, created 2026-01-25)** is the source of all 11 roles above. Its
resources were deleted out of band, so it is now fully drifted. It was **not**
deleted, for two reasons: deleting a stack was not part of the authorised change,
and the stack is currently the only CloudFormation stack in the account, which
makes it the only reachable target for the `privesc-CloudFormationUpdateStack`
scenario. See `account-baseline.md`.

**This needs a decision before Phase 2.** Deleting the stack removes the last
fixture residue but flips `privesc-CloudFormationUpdateStack` back to
`target_absent = yes`. Keeping it leaves an `iamwho`-authored artifact in the
account that a tool could name in its output. Either is defensible; the choice
has to be made and disclosed, not left to whichever happens to be true on the
day the tools run.

**The `EC2-AutoRemediation` Lambda is kept on purpose.** See `account-baseline.md`
and the `privesc17` note in `scenarios.md`.
