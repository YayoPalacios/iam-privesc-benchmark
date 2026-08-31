# Lab deployment record

The pinned environment every graded run is measured against. Each per-run
`run-metadata.md` cites this file rather than restating it.

## Pin

- **Repo:** https://github.com/BishopFox/iam-vulnerable
- **Commit:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **Commit date:** 2025-09-11
- **Cloned:** 2026-08-30
- **Region:** us-east-1 (hardcoded in the lab's `main.tf` provider block, not a variable)

`lab/` is a plain clone and carries its own `.git`, so the outer repo does not
track its contents. This pin is the only record of what was deployed. Do not
delete it.

## tfvars applied

Contents of `lab/terraform.tfvars` (gitignored by the lab's own `.gitignore`):

```hcl
aws_local_profile = "personal"
```

All other variables left at their defaults:

- `aws_local_creds_file` = `~/.aws/credentials`
- `aws_assume_role_arn` = `""` → falls back to the caller ARN, i.e. the sandbox
  `user/iamadmin`. Every lab role's trust policy names that principal.
- `shared_high_priv_servicerole` = `""` (only consumed by the disabled
  CloudFormation module)

## Modules enabled

As shipped at the pinned commit — **no edits to the lab's Terraform**:

| Module | State | Source |
|---|---|---|
| `free-resources/privesc-paths` | enabled | uncommented in `main.tf` |
| `free-resources/tool-testing` | enabled | uncommented in `main.tf` |
| `non-free-resources/lambda` | disabled | commented out in `main.tf` |
| `non-free-resources/ec2` | disabled | commented out in `main.tf` |
| `non-free-resources/glue` | disabled | commented out in `main.tf` |
| `non-free-resources/sagemaker` | disabled | commented out in `main.tf` |
| `non-free-resources/cloudformation` | disabled | commented out in `main.tf` |
| `non-free-resources/elasticbeanstalk` | disabled | not referenced in `main.tf` at all |

Module selection in this lab is done by commenting blocks in `main.tf`, not by
variables. Enabling a non-free module would require editing the lab's Terraform,
which CLAUDE.md forbids. The default (free-only) deployment is therefore both the
compliant choice and the honest one.

**Consequence for grading:** see `analysis/scenarios.md`. Some free-resource
privesc paths grant permissions whose exploitation target only exists in a
disabled module.

## Apply

- **Applied:** 2026-08-31T00:42:24Z
- **Caller identity at apply:** `arn:aws:iam::000000000000:user/iamadmin` (sandbox,
  verified against `.account-id` immediately before apply)
- **Result:** `Apply complete! Resources: 265 added, 0 changed, 0 destroyed.`
- **terraform apply exit status:** 0
- **Terraform:** v1.14.8, provider `hashicorp/aws ~> 6.0`

## Account was not empty at apply time

13 principals predate this deployment and are **not** lab scenarios: 11
`iamwho-test-*` roles, plus `EC2-AutoRemediation-role-h3s42wj1` and
`EC2CloudWatchAgentRole` with a live `EC2-AutoRemediation` Lambda function.
GuardDuty is enabled. See the header of `analysis/scenarios.md` — this needs a
decision before Phase 2 runs.

## Teardown

Load-bearing: `lab/terraform.tfstate` holds 41 live secret access keys in
plaintext. See the README.
