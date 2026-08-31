# `privesc17-EditExistingLambdaFunctionWithRole` — FP candidate (overstated impact)

- **Class:** `privesc` · **Category:** false-positive candidate (rubric §6, §4.8)
- **Applies to both principal rows:** `--role` and `--user` (same target, same ceiling)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the principal can overwrite the code of the only reachable
  Lambda (`EC2-AutoRemediation`), which runs as
  `role/service-role/EC2-AutoRemediation-role-h3s42wj1`. That role grants **EC2
  read + instance tagging + Lambda basic-execution (logs)** — **not** admin. Any
  tool reporting privesc17 as a path to administrative access would be an
  overstated-impact FP under §4.8.

## Commands and outcomes

Account ID redacted to `000000000000`. No Lambda code was modified — the enabling
permission and the target role's ceiling were confirmed by read + simulate. (The
lab's own privesc17 Lambda module is disabled; `EC2-AutoRemediation` is the only
existing function and the only reachable target — see scenarios.md.)

### 1. The principal holds the enabling permissions

```
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:user/privesc17-EditExistingLambdaFunctionWithRole-user \
    --action-names lambda:UpdateFunctionCode lambda:UpdateFunctionConfiguration lambda:GetFunction
=> lambda:UpdateFunctionCode          : allowed
   lambda:UpdateFunctionConfiguration : allowed
   lambda:GetFunction                 : implicitDeny   # exactly the two mechanism actions, no more
```

### 2. The target function and the role it runs as

```
$ aws lambda get-function --function-name EC2-AutoRemediation --region us-east-1 --profile personal \
    --query 'Configuration.{Name:FunctionName,Role:Role}'
{ "Name":"EC2-AutoRemediation",
  "Role":"arn:aws:iam::000000000000:role/service-role/EC2-AutoRemediation-role-h3s42wj1" }

$ aws iam list-attached-role-policies --role-name EC2-AutoRemediation-role-h3s42wj1 --profile personal
AmazonEC2ReadOnlyAccess (aws-managed)
AWSLambdaBasicExecutionRole-... (logs: CreateLogGroup/Stream, PutLogEvents — us-east-1 only)
$ aws iam list-role-policies --role-name EC2-AutoRemediation-role-h3s42wj1 --profile personal
EC2TaggingPermissions (inline)
  => { "Effect":"Allow","Action":"ec2:CreateTags","Resource":"arn:aws:ec2:*:*:instance/*" }
```

### 3. AWS evaluator: the impact ceiling of that role

```
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:role/service-role/EC2-AutoRemediation-role-h3s42wj1 \
    --action-names iam:AttachRolePolicy iam:CreateAccessKey iam:PutRolePolicy s3:GetObject \
                   ec2:DescribeInstances ec2:RunInstances ec2:TerminateInstances
=> iam:AttachRolePolicy   : implicitDeny
   iam:CreateAccessKey    : implicitDeny
   iam:PutRolePolicy      : implicitDeny
   s3:GetObject           : implicitDeny
   ec2:DescribeInstances  : allowed
   ec2:RunInstances       : implicitDeny
   ec2:TerminateInstances : implicitDeny

# ec2:CreateTags is allowed only against an instance-scoped resource:
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:role/service-role/EC2-AutoRemediation-role-h3s42wj1 \
    --action-names ec2:CreateTags \
    --resource-arns arn:aws:ec2:us-east-1:000000000000:instance/i-0123456789abcdef0
=> ec2:CreateTags : allowed
```

## Verdict

**Confirmed: the path works but the privilege is narrow.** The principal can
replace the function's code (it holds exactly `UpdateFunctionCode` +
`UpdateFunctionConfiguration`), and the code would execute as
`EC2-AutoRemediation-role-h3s42wj1`. That role's *entire* effective authority is
EC2 **read**, `ec2:CreateTags` on instances, and CloudWatch Logs writes. No IAM,
no S3, no `RunInstances`/`TerminateInstances`, no `*:*`. The escalation yields EC2
read + tagging — **not** administrative access.

## Tool behaviour (for the Phase-4 FP tally)

- **PMapper (admin-flagged):** does **not** report privesc17 at all (absent from
  `query`/`analysis`). PMapper only draws edges to principals it deems
  administrative, and this target is not one.
- **cloudfox (admin-default):** lists `EC2-AutoRemediation` in its `lambda` table
  with **`IsAdminRole? = No`**; the privesc17 principal's `UpdateFunctionCode`
  permission appears only in the raw `permissions` dump. Neither surface draws a
  privesc17 → admin path.

**The overstated-impact FP does not materialise.** No tool claims privesc17
reaches admin, and cloudfox explicitly marks the target role non-admin. Recorded
as a cleared candidate — and as a live confirmation that scenarios.md's §4.8
annotation (privesc17 ⇒ EC2 read/tagging, not admin) is correct.
