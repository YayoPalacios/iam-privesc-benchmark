# Account baseline — non-lab resources

Everything in the sandbox account that `iam-vulnerable` did not create, as of
**2026-08-31**, after the `iamwho` fixture removal recorded in
`fixture-removal-2026-08-31.md` — including the second pass, which removed the
CloudFormation stack that created those fixtures and its template bucket.

The point of this file is that `target_absent` in `scenarios.md` is only as good
as the assumption that nothing outside the lab exists. That assumption was wrong
— a CloudFormation stack in `us-west-2` and a Lambda function in `us-east-1` both
predate the lab and both are reachable escalation targets. This is the corrected
picture.

Account IDs render as `000000000000`, matching `redact.sh`.

## Method and its limits

- **17 enabled regions swept directly** via per-service API calls: Lambda,
  EventBridge rules (per event bus), SNS, EC2 instances, SSM-managed instances,
  CloudFormation stacks, Glue jobs, SageMaker notebooks, EC2 key pairs.
- **S3** listed globally with per-bucket region resolution.
- **IAM** from `get-account-authorization-details` (global).
- Resource Explorer has `LOCAL` indexes in `us-east-1` and `us-west-2` only, and
  **its IAM index was stale** — it reported 28 roles and 19 users when the account
  held 52 roles and 42 users. It was used to find candidate regions, not as a
  source of truth. Every fact below comes from a direct service API call.
- **Not covered:** services outside the list above, and any resource in a region
  where the relevant API was not queried. This is a targeted inventory of things
  that can serve as privilege-escalation targets, not a complete asset inventory.

## Compute and data

| Resource | Region | Detail | Escalation target? |
|---|---|---|---|
| Lambda `EC2-AutoRemediation` | us-east-1 | python3.10, last modified 2025-12-08, runs as `role/service-role/EC2-AutoRemediation-role-h3s42wj1` | **Yes — and deliberately kept.** See below. |
| SNS topic `EC2-Alarms2` | us-east-1 | paired with the auto-remediation Lambda | No — no IAM privilege attached |
| EC2 key pair `temp` | us-east-1 | no instances | No |
| EC2 key pairs `lab-new-key`, `flaws-lab` | us-west-2 | no instances | No |

**Nothing else was found.** Zero EC2 instances, zero SSM-managed instances, zero
SageMaker notebooks, zero Glue jobs, zero EventBridge rules on any bus, **zero
CloudFormation stacks and zero S3 buckets**, in any of the 17 enabled regions.
Glue dev endpoints cannot be enumerated at all: `GetDevEndpoints` returns
`AccessDeniedException: operation is currently disabled` in both indexed regions,
because AWS has retired the feature.

There is also no OIDC or SAML identity provider in the account
(`list-open-id-connect-providers` and `list-saml-providers` both return empty).
That matters for Phase 5: the OIDC scenario will be authored against a clean
slate, and no pre-existing federation artifact can be mistaken for it.

### Removed in the second cleanup pass, 2026-08-31

| Resource | Why |
|---|---|
| CloudFormation stack `iamwho-stress-test-roles` (us-west-2) | The stack that created the 11 deleted `iamwho-test-*` roles. Fully drifted, holding no live resources, no exports, and no other stack in any region could import from it. Last `iamwho` artifact in the account. |
| S3 bucket `cf-templates-1ajkstp6a3kyv-us-west-2` and its 9 objects | CloudFormation's auto-created template staging bucket. **All 9 templates verified as `iamwho` residue** before deletion — every one described as "IAM test roles for iamwho testing" or "IAMWho Stress Test Roles", dated 2026-01-13 to 2026-01-25, defining only `iamwho-test-*` roles. Nothing else had ever been staged there. CloudFormation recreates such a bucket on demand if one is ever needed again. |

Dependency check before deletion: the stack's resource list contained exactly the
11 IAM roles, all already deleted; `list-exports` was empty; and it was the only
stack in any region, so nothing could import from it. The newest two templates
also contained an OIDC role definition that was **commented out and never
deployed**, consistent with the empty provider list above.

## Non-lab IAM principals

| Principal | Type | Policies | Escalation target? |
|---|---|---|---|
| `user/iamadmin` | user | `AdministratorAccess` | **Yes — the highest-value target in the account.** Also the principal named in all 45 lab role trust policies, and the deployer. |
| `role/service-role/EC2-AutoRemediation-role-h3s42wj1` | role | `AWSLambdaBasicExecutionRole-6ee3187d…`, `AmazonEC2ReadOnlyAccess`, `EC2TaggingPermissions` | **Yes, but low value** — EC2 read and tagging, plus log writes. Not admin. |
| `role/EC2CloudWatchAgentRole` | role | `CloudWatchAgentServerPolicy` | Marginal — metric and log publication only. Bound to an instance profile with no instances. |
| `AWSServiceRoleForAmazonGuardDuty` | SLR | service-managed | No — not assumable by an account principal |
| `AWSServiceRoleForAmazonGuardDutyMalwareProtection` | SLR | service-managed | No |
| `AWSServiceRoleForResourceExplorer` | SLR | service-managed | No |
| `AWSServiceRoleForSupport` | SLR | service-managed | No |
| `AWSServiceRoleForTrustedAdvisor` | SLR | service-managed | No |

One non-lab customer-managed policy exists,
`AWSLambdaBasicExecutionRole-6ee3187d-851d-4ed1-be6d-968092e15b25`, auto-created
by the Lambda console for the function above.

GuardDuty is enabled. Rubric §7 puts runtime detection out of scope, but the lab
and any Phase 3 exploitation will generate findings.

## The `EC2-AutoRemediation` Lambda is kept on purpose

It is not contamination to be cleaned up. It is the most useful non-lab resource
in the account, because it makes `privesc17-EditExistingLambdaFunctionWithRole`
into a live **overstated-impact** test case.

The lab's own Lambda module is disabled, so without this function `privesc17`
would be a principal holding `lambda:UpdateFunctionCode` with nothing to point it
at. With it, the path is genuinely exploitable — and it lands on a role granting
EC2 read, EC2 tagging and CloudWatch log writes. **Not administrative access.**

That makes it a direct test of rubric §4.8: a tool that reports `privesc17` as a
path to account admin is not detecting a real escalation, it is overstating the
privilege gained, and under the rubric that scores **FP**, not **D**. A tool that
reports it and correctly characterises the ceiling scores **D**.

Cases like this are hard to construct deliberately and easy to destroy by
tidying. It stays. Do not delete it during teardown — `terraform destroy` will
not touch it, since Terraform never created it.

## Consequences for `scenarios.md`

One `target_absent` determination moved and then moved back, and the round trip
is worth recording because it is the kind of thing that quietly decides a grade:

- **`privesc-CloudFormationUpdateStack`: `yes` → `no` → `yes`.** The original
  check ran `describe-stacks` in `us-east-1` only and found zero, which was a
  one-region answer to an any-region question. The 17-region sweep found a stack
  in `us-west-2`, and since `cloudformation:UpdateStack` is granted on
  `Resource: "*"` with no region condition, the target was genuinely reachable —
  so the column changed to `no`.

  That stack was `iamwho-stress-test-roles`: the fixture stack belonging to the
  tool deliberately withheld from this phase. Deleting it to keep the baseline
  uncontaminated removed the only stack in the account, so the scenario returns
  to `target_absent = yes`.

  The final value matches the first one, but for a different and now-verified
  reason. Grading this scenario as exploitable would have meant scoring the
  tools against a target that existed only because `iamwho`'s leftovers put it
  there.

All other `target_absent = yes` determinations survive the wider sweep, verified
across all 17 enabled regions rather than one:

- `privesc18` / `privesc19` (Glue dev endpoints) — feature retired by AWS
- `privesc-CloudFormationUpdateStack` — no stacks anywhere, after the cleanup above
- `privesc-ec2InstanceConnect` — no instances anywhere
- `privesc-ssmSendCommand` / `privesc-ssmStartSession` — no SSM-managed nodes anywhere
- `privesc-sageMakerCreatePresignedNotebookURL` — no notebooks anywhere
