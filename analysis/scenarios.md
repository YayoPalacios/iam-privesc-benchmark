# Scenario list

Ground truth for the benchmark. **Generated from the AWS IAM API**, with Terraform
state used only for inventory (which resources the lab created) and intent labels
(the lab's own resource names). Every permission, trust relationship, group
membership and access-key fact below was read from the live account after apply,
not from the lab's README and not from the Terraform source.

One row per `(principal, mechanism)`, per rubric §2.1. Mechanism-level rollups are
the headline denominator; the per-principal rows are retained here because a tool
that catches the user but not the role (or vice versa) is a finding.

**Account IDs are rendered as `000000000000`**, matching the placeholder
`redact.sh` writes into `raw-output/`, so ARNs here join against redacted tool
output.

---

## Provenance

| | |
|---|---|
| Lab | `BishopFox/iam-vulnerable` @ `0f298666f9b7cfa01488b86912afdb211773188a` (2025-09-11) |
| Applied | 2026-08-31, `us-east-1`, 265 resources, 0 changed, 0 destroyed |
| tfvars | `aws_local_profile = "personal"` — everything else default |
| Modules | `free-resources/privesc-paths`, `free-resources/tool-testing`. All `non-free-resources` modules disabled as shipped. |
| Primary source | `iam get-account-authorization-details`, `iam list-access-keys`, `iam list-instance-profiles`, plus per-service existence checks |
| Inventory source | `terraform show -json terraform.tfstate` |
| Full deployment record | `raw-output/lab-deployment.md` |

## Deployment properties that shape every result

**1. `aws_assume_role_arn` was left at its default, so all 45 lab roles trust `user/iamadmin`.**

The variable falls back to `data.aws_caller_identity.current.arn`. Every role the
lab creates therefore names the deploying admin user in its trust policy. In the
`admin` context the role graph is fully connected from a single principal, and any
tool with IAM read access sees a star topology centred on `iamadmin`. This is a
property of the deployment, not of the tools, and it inflates reachability for
every admin-context run. Note it in the writeup; the `limited` (`SecurityAudit`)
run is the only one where this is not in play.

**2. The account was not empty before the lab was applied, and it is still not.**

Full inventory in `account-baseline.md`. Two changes since this file was first
generated:

- **The 11 `iamwho-test-*` roles have been deleted** — see
  `fixture-removal-2026-08-31.md`. They carried policies named `admin-access`,
  `sneaky-escalation`, `dangerous-passrole`, `lambda-code-injection` and similar,
  several duplicating lab mechanisms outright, and two were assumable by
  `AWS: "*"`. Leaving `iamwho`'s own fixtures in the account would have
  undercut the "baseline you did not build around it" property that holding
  `iamwho` back was meant to preserve.
- **A wider sweep found resources the first pass missed**, because the first pass
  only looked in `us-east-1`. All 17 enabled regions have now been checked.

What remains, and matters:

- **Lambda `EC2-AutoRemediation` (us-east-1), kept deliberately.** It is the only
  reachable target for `privesc17`, and the role it runs as grants EC2 read and
  tagging — not admin. That makes it a live rubric §4.8 overstated-impact test.
  Do not delete it.
- **The `iamwho-stress-test-roles` CloudFormation stack has been deleted**, along
  with its template bucket. It was the source of the 11 fixture roles and the
  last `iamwho` artifact in the account. Because it was also the only stack in
  the account, `privesc-CloudFormationUpdateStack` returns to
  `target_absent = yes` — the honest reading, since the only thing that made it
  exploitable was residue from the tool being held back from this phase.
- `role/service-role/EC2-AutoRemediation-role-h3s42wj1`, `role/EC2CloudWatchAgentRole`,
  5 service-linked roles, `user/iamadmin`, one SNS topic, three unused EC2 key
  pairs. No CloudFormation stacks and no S3 buckets remain, account-wide.

A tool reporting a path through any of these is producing an off-list finding —
neither a lab scenario nor a false positive. Exclude them from the denominator
explicitly rather than silently.

GuardDuty is enabled. Rubric §7 puts runtime detection out of scope, but the lab
will generate findings.

## Columns

- **`target_absent`** — `yes` when the mechanism's exploitation target does not
  exist in this deployment, verified against the live account. The principal
  holds the permission and there is nothing to point it at. These rows are graded
  in their own bucket: a tool naming the permission is right about the grant and
  wrong about exploitability here, which is a rubric §4.8 overstated-impact
  question, not a straight detection question. `n/a` where the row is a designed
  false positive, a chain terminus, or an inert principal.
- **`access key`** — whether the principal has one, i.e. whether it is directly
  usable as an attacker start point without first assuming something.
- **`viable start`** — how an attacker would come to hold this principal.
- **`class`** — `privesc` (canonical escalation path), `tool-test-FN` (designed
  true positive that naive analysis misses), `tool-test-FP` (correct behaviour is
  to report *nothing*), `chain-hop`, `target-only` (endpoint, not a start point),
  `inert`, `non-path`.
- **`non-path`** — added 2026-08-31. The principal holds the enabling permission
  and can use it to make **another** principal administrative, but has no route to
  authenticating as that principal, so it cannot escalate **itself**. The grant is
  real and the thing it can empower exists — which is why `target_absent` stays
  `no` — but the row is not a self-escalation path, and correct tool behaviour is
  to report no path. Graded **CS** or **FP**, never on the D/P/M ladder
  (rubric §9, 2026-08-31). Six rows, all from the six-row asymmetry resolved in
  the Phase-4 addendum; one validation file each.

## Counts

| | mechanisms | principal rows |
|---|---:|---:|
| privesc | 31 | 56 |
| non-path | 6 † | 6 |
| tool-test-FN | 4 | 8 |
| tool-test-FP | 6 | 11 |
| chain-hop | 2 | 2 |
| target-only | 2 | 2 |
| inert | 1 | 1 |
| **total** | **46** | **86** |

† **The mechanism column does not sum, and that is deliberate.** The six `non-path`
rows belong to `privesc7`–`privesc12`, six mechanisms that *also* keep a `privesc`
row: for each of them one principal can self-escalate and the other cannot. Those
six mechanisms are counted once, under `privesc`, so the mechanism total is
unchanged at 46. Corrected 2026-08-31; see the Corrections table.

`target_absent = yes` on 8 mechanisms (16 rows). Verified across all 17 enabled
regions, not just `us-east-1` — see `account-baseline.md`.

All 41 lab users hold exactly one access key. No lab role holds one; roles are
reached by `sts:AssumeRole` from `user/iamadmin`.

---

## Scenarios

| scenario_id | principal ARN | mechanism | enabling permission | intended target | access key | viable start | target_absent | class |
|---|---|---|---|---|---|---|:--:|---|
| `privesc1-CreateNewPolicyVersion--role` | `arn:aws:iam::000000000000:role/privesc1-CreateNewPolicyVersion-role` | privesc1-CreateNewPolicyVersion | Allow: `iam:CreatePolicyVersion` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc1-CreateNewPolicyVersion--user` | `arn:aws:iam::000000000000:user/privesc1-CreateNewPolicyVersion-user` | privesc1-CreateNewPolicyVersion | Allow: `iam:CreatePolicyVersion` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc2-SetExistingDefaultPolicyVersion--role` | `arn:aws:iam::000000000000:role/privesc2-SetExistingDefaultPolicyVersion-role` | privesc2-SetExistingDefaultPolicyVersion | Allow: `iam:SetDefaultPolicyVersion` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc2-SetExistingDefaultPolicyVersion--user` | `arn:aws:iam::000000000000:user/privesc2-SetExistingDefaultPolicyVersion-user` | privesc2-SetExistingDefaultPolicyVersion | Allow: `iam:SetDefaultPolicyVersion` | any IAM principal -> account admin | yes | yes - access key | **yes** | privesc |
| `privesc3-CreateEC2WithExistingInstanceProfile--role` | `arn:aws:iam::000000000000:role/privesc3-CreateEC2WithExistingInstanceProfile-role` | privesc3-CreateEC2WithExistingInstanceProfile | Allow: `iam:PassRole`, `ec2:DescribeInstances`, `ec2:RunInstances`, `ec2:CreateKeyPair` +1 more | privesc-high-priv-service-role (`*:*`) via ec2 + privesc-high-priv-service-profile | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc3-CreateEC2WithExistingInstanceProfile--user` | `arn:aws:iam::000000000000:user/privesc3-CreateEC2WithExistingInstanceProfile-user` | privesc3-CreateEC2WithExistingInstanceProfile | Allow: `iam:PassRole`, `ec2:DescribeInstances`, `ec2:RunInstances`, `ec2:CreateKeyPair` +1 more | privesc-high-priv-service-role (`*:*`) via ec2 + privesc-high-priv-service-profile | yes | yes - access key | **no** | privesc |
| `privesc4-CreateAccessKey--role` | `arn:aws:iam::000000000000:role/privesc4-CreateAccessKey-role` | privesc4-CreateAccessKey | Allow: `iam:CreateAccessKey` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc4-CreateAccessKey--user` | `arn:aws:iam::000000000000:user/privesc4-CreateAccessKey-user` | privesc4-CreateAccessKey | Allow: `iam:CreateAccessKey` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc5-CreateLoginProfile--role` | `arn:aws:iam::000000000000:role/privesc5-CreateLoginProfile-role` | privesc5-CreateLoginProfile | Allow: `iam:CreateLoginProfile` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc5-CreateLoginProfile--user` | `arn:aws:iam::000000000000:user/privesc5-CreateLoginProfile-user` | privesc5-CreateLoginProfile | Allow: `iam:CreateLoginProfile` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc6-UpdateLoginProfile--role` | `arn:aws:iam::000000000000:role/privesc6-UpdateLoginProfile-role` | privesc6-UpdateLoginProfile | Allow: `iam:UpdateLoginProfile` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc6-UpdateLoginProfile--user` | `arn:aws:iam::000000000000:user/privesc6-UpdateLoginProfile-user` | privesc6-UpdateLoginProfile | Allow: `iam:UpdateLoginProfile` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc7-AttachUserPolicy--role` | `arn:aws:iam::000000000000:role/privesc7-AttachUserPolicy-role` | privesc7-AttachUserPolicy | Allow: `iam:AttachUserPolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | non-path |
| `privesc7-AttachUserPolicy--user` | `arn:aws:iam::000000000000:user/privesc7-AttachUserPolicy-user` | privesc7-AttachUserPolicy | Allow: `iam:AttachUserPolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc8-AttachGroupPolicy--role` | `arn:aws:iam::000000000000:role/privesc8-AttachGroupPolicy-role` | privesc8-AttachGroupPolicy | Allow: `iam:AttachGroupPolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | non-path |
| `privesc8-AttachGroupPolicy--user` | `arn:aws:iam::000000000000:user/privesc8-AttachGroupPolicy-user` | privesc8-AttachGroupPolicy | Allow: `iam:AttachGroupPolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc9-AttachRolePolicy--role` | `arn:aws:iam::000000000000:role/privesc9-AttachRolePolicy-role` | privesc9-AttachRolePolicy | Allow: `iam:AttachRolePolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc9-AttachRolePolicy--user` | `arn:aws:iam::000000000000:user/privesc9-AttachRolePolicy-user` | privesc9-AttachRolePolicy | Allow: `iam:AttachRolePolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | non-path |
| `privesc10-PutUserPolicy--role` | `arn:aws:iam::000000000000:role/privesc10-PutUserPolicy-role` | privesc10-PutUserPolicy | Allow: `iam:PutUserPolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | non-path |
| `privesc10-PutUserPolicy--user` | `arn:aws:iam::000000000000:user/privesc10-PutUserPolicy-user` | privesc10-PutUserPolicy | Allow: `iam:PutUserPolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc11-PutGroupPolicy--role` | `arn:aws:iam::000000000000:role/privesc11-PutGroupPolicy-role` | privesc11-PutGroupPolicy | Allow: `iam:PutGroupPolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | non-path |
| `privesc11-PutGroupPolicy--user` | `arn:aws:iam::000000000000:user/privesc11-PutGroupPolicy-user` | privesc11-PutGroupPolicy | Allow: `iam:PutGroupPolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | privesc |
| `privesc12-PutRolePolicy--role` | `arn:aws:iam::000000000000:role/privesc12-PutRolePolicy-role` | privesc12-PutRolePolicy | Allow: `iam:PutRolePolicy` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc12-PutRolePolicy--user` | `arn:aws:iam::000000000000:user/privesc12-PutRolePolicy-user` | privesc12-PutRolePolicy | Allow: `iam:PutRolePolicy` | any IAM principal -> account admin | yes | yes - access key | **no** | non-path |
| `privesc13-AddUserToGroup--role` | `arn:aws:iam::000000000000:role/privesc13-AddUserToGroup-role` | privesc13-AddUserToGroup | Allow: `iam:AddUserToGroup` | privesc-sre-group (`iam:*`,`ec2:*`,`s3:*`) | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc13-AddUserToGroup--user` | `arn:aws:iam::000000000000:user/privesc13-AddUserToGroup-user` | privesc13-AddUserToGroup | Allow: `iam:AddUserToGroup` | privesc-sre-group (`iam:*`,`ec2:*`,`s3:*`) | yes | yes - access key | **no** | privesc |
| `privesc14-UpdatingAssumeRolePolicy--role` | `arn:aws:iam::000000000000:role/privesc14-UpdatingAssumeRolePolicy-role` | privesc14-UpdatingAssumeRolePolicy | Allow: `iam:UpdateAssumeRolePolicy`, `sts:AssumeRole` | any role, e.g. privesc-sre-role (`iam:*`,`ec2:*`,`s3:*`) | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc14-UpdatingAssumeRolePolicy--user` | `arn:aws:iam::000000000000:user/privesc14-UpdatingAssumeRolePolicy-user` | privesc14-UpdatingAssumeRolePolicy | Allow: `iam:UpdateAssumeRolePolicy`, `sts:AssumeRole` | any role, e.g. privesc-sre-role (`iam:*`,`ec2:*`,`s3:*`) | yes | yes - access key | **no** | privesc |
| `privesc15-PassExistingRoleToNewLambdaThenInvoke--role` | `arn:aws:iam::000000000000:role/privesc15-PassExistingRoleToNewLambdaThenInvoke-role` | privesc15-PassExistingRoleToNewLambdaThenInvoke | Allow: `iam:PassRole`, `lambda:CreateFunction`, `lambda:InvokeFunction` | privesc-high-priv-service-role (`*:*`) via lambda | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc15-PassExistingRoleToNewLambdaThenInvoke--user` | `arn:aws:iam::000000000000:user/privesc15-PassExistingRoleToNewLambdaThenInvoke-user` | privesc15-PassExistingRoleToNewLambdaThenInvoke | Allow: `iam:PassRole`, `lambda:CreateFunction`, `lambda:InvokeFunction` | privesc-high-priv-service-role (`*:*`) via lambda | yes | yes - access key | **no** | privesc |
| `privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo--role` | `arn:aws:iam::000000000000:role/privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo-role` | privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo | Allow: `lambda:CreateFunction`, `iam:PassRole`, `lambda:CreateEventSourceMapping` | privesc-high-priv-service-role (`*:*`) via lambda | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo--user` | `arn:aws:iam::000000000000:user/privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo-user` | privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo | Allow: `lambda:CreateFunction`, `iam:PassRole`, `lambda:CreateEventSourceMapping` | privesc-high-priv-service-role (`*:*`) via lambda | yes | yes - access key | **no** | privesc |
| `privesc17-EditExistingLambdaFunctionWithRole--role` | `arn:aws:iam::000000000000:role/privesc17-EditExistingLambdaFunctionWithRole-role` | privesc17-EditExistingLambdaFunctionWithRole | Allow: `lambda:UpdateFunctionCode`, `lambda:UpdateFunctionConfiguration` | role/service-role/EC2-AutoRemediation-role-h3s42wj1 (EC2 read + tagging + basic execution) | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc17-EditExistingLambdaFunctionWithRole--user` | `arn:aws:iam::000000000000:user/privesc17-EditExistingLambdaFunctionWithRole-user` | privesc17-EditExistingLambdaFunctionWithRole | Allow: `lambda:UpdateFunctionCode`, `lambda:UpdateFunctionConfiguration` | role/service-role/EC2-AutoRemediation-role-h3s42wj1 (EC2 read + tagging + basic execution) | yes | yes - access key | **no** | privesc |
| `privesc18-PassExistingRoleToNewGlueDevEndpoint--role` | `arn:aws:iam::000000000000:role/privesc18-PassExistingRoleToNewGlueDevEndpoint-role` | privesc18-PassExistingRoleToNewGlueDevEndpoint | Allow: `glue:CreateDevEndpoint`, `glue:GetDevEndpoint`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via glue | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc18-PassExistingRoleToNewGlueDevEndpoint--user` | `arn:aws:iam::000000000000:user/privesc18-PassExistingRoleToNewGlueDevEndpoint-user` | privesc18-PassExistingRoleToNewGlueDevEndpoint | Allow: `glue:CreateDevEndpoint`, `glue:GetDevEndpoint`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via glue | yes | yes - access key | **yes** | privesc |
| `privesc19-UpdateExistingGlueDevEndpoint--role` | `arn:aws:iam::000000000000:role/privesc19-UpdateExistingGlueDevEndpoint-role` | privesc19-UpdateExistingGlueDevEndpoint | Allow: `glue:UpdateDevEndpoint`, `glue:GetDevEndpoint` | privesc-high-priv-service-role (`*:*`) via glue | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc19-UpdateExistingGlueDevEndpoint--user` | `arn:aws:iam::000000000000:user/privesc19-UpdateExistingGlueDevEndpoint-user` | privesc19-UpdateExistingGlueDevEndpoint | Allow: `glue:UpdateDevEndpoint`, `glue:GetDevEndpoint` | privesc-high-priv-service-role (`*:*`) via glue | yes | yes - access key | **yes** | privesc |
| `privesc20-PassExistingRoleToCloudFormation--role` | `arn:aws:iam::000000000000:role/privesc20-PassExistingRoleToCloudFormation-role` | privesc20-PassExistingRoleToCloudFormation | Allow: `iam:PassRole`, `cloudformation:CreateStack`, `cloudformation:DescribeStacks` | privesc-high-priv-service-role (`*:*`) via cloudformation | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc20-PassExistingRoleToCloudFormation--user` | `arn:aws:iam::000000000000:user/privesc20-PassExistingRoleToCloudFormation-user` | privesc20-PassExistingRoleToCloudFormation | Allow: `iam:PassRole`, `cloudformation:CreateStack`, `cloudformation:DescribeStacks` | privesc-high-priv-service-role (`*:*`) via cloudformation | yes | yes - access key | **no** | privesc |
| `privesc21-PassExistingRoleToNewDataPipeline--role` | `arn:aws:iam::000000000000:role/privesc21-PassExistingRoleToNewDataPipeline-role` | privesc21-PassExistingRoleToNewDataPipeline | Allow: `iam:PassRole`; Allow: `datapipeline:CreatePipeline`, `datapipeline:PutPipelineDefinition`, `datapipeline:ActivatePipeline` | privesc-high-priv-service-role (`*:*`) via datapipeline | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc21-PassExistingRoleToNewDataPipeline--user` | `arn:aws:iam::000000000000:user/privesc21-PassExistingRoleToNewDataPipeline-user` | privesc21-PassExistingRoleToNewDataPipeline | Allow: `iam:PassRole`; Allow: `datapipeline:CreatePipeline`, `datapipeline:PutPipelineDefinition`, `datapipeline:ActivatePipeline` | privesc-high-priv-service-role (`*:*`) via datapipeline | yes | yes - access key | **no** | privesc |
| `privesc-CloudFormationUpdateStack--role` | `arn:aws:iam::000000000000:role/privesc-CloudFormationUpdateStack-role` | privesc-CloudFormationUpdateStack | Allow: `cloudformation:UpdateStack`, `cloudformation:DescribeStacks` | privesc-high-priv-service-role (`*:*`) via cloudformation | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc-CloudFormationUpdateStack--user` | `arn:aws:iam::000000000000:user/privesc-CloudFormationUpdateStack-user` | privesc-CloudFormationUpdateStack | Allow: `cloudformation:UpdateStack`, `cloudformation:DescribeStacks` | privesc-high-priv-service-role (`*:*`) via cloudformation | yes | yes - access key | **yes** | privesc |
| `privesc-codeBuildCreateProjectPassRole--role` | `arn:aws:iam::000000000000:role/privesc-codeBuildCreateProjectPassRole-role` | privesc-codeBuildCreateProjectPassRole | Allow: `codebuild:CreateProject`, `codebuild:StartBuild`, `codebuild:StartBuildBatch`, `iam:PassRole` +1 more | privesc-high-priv-service-role (`*:*`) via codebuild | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc-codeBuildCreateProjectPassRole--user` | `arn:aws:iam::000000000000:user/privesc-codeBuildCreateProjectPassRole-user` | privesc-codeBuildCreateProjectPassRole | Allow: `codebuild:CreateProject`, `codebuild:StartBuild`, `codebuild:StartBuildBatch`, `iam:PassRole` +1 more | privesc-high-priv-service-role (`*:*`) via codebuild | yes | yes - access key | **no** | privesc |
| `privesc-ec2InstanceConnect--role` | `arn:aws:iam::000000000000:role/privesc-ec2InstanceConnect-role` | privesc-ec2InstanceConnect | Allow: `ec2:DescribeInstances`, `ec2-instance-connect:SendSSHPublicKey`, `ec2-instance-connect:SendSerialConsoleSSHPublicKey` | shell on an EC2 instance carrying a role | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc-ec2InstanceConnect--user` | `arn:aws:iam::000000000000:user/privesc-ec2InstanceConnect-user` | privesc-ec2InstanceConnect | Allow: `ec2:DescribeInstances`, `ec2-instance-connect:SendSSHPublicKey`, `ec2-instance-connect:SendSerialConsoleSSHPublicKey` | shell on an EC2 instance carrying a role | yes | yes - access key | **yes** | privesc |
| `privesc-sageMakerCreateNotebookPassRole--role` | `arn:aws:iam::000000000000:role/privesc-sageMakerCreateNotebookPassRole-role` | privesc-sageMakerCreateNotebookPassRole | Allow: `sagemaker:CreateNotebookInstance`, `sagemaker:CreatePresignedNotebookInstanceUrl`, `sagemaker:ListNotebookInstances`, `sagemaker:DescribeNotebookInstance` +4 more | privesc-high-priv-service-role (`*:*`) via sagemaker | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc-sageMakerCreateNotebookPassRole--user` | `arn:aws:iam::000000000000:user/privesc-sageMakerCreateNotebookPassRole-user` | privesc-sageMakerCreateNotebookPassRole | Allow: `sagemaker:CreateNotebookInstance`, `sagemaker:CreatePresignedNotebookInstanceUrl`, `sagemaker:ListNotebookInstances`, `sagemaker:DescribeNotebookInstance` +4 more | privesc-high-priv-service-role (`*:*`) via sagemaker | yes | yes - access key | **no** | privesc |
| `privesc-sageMakerCreatePresignedNotebookURL--role` | `arn:aws:iam::000000000000:role/privesc-sageMakerCreatePresignedNotebookURL-role` | privesc-sageMakerCreatePresignedNotebookURL | Allow: `sagemaker:CreatePresignedNotebookInstanceUrl`, `sagemaker:ListNotebookInstances` | an existing SageMaker notebook and its role | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc-sageMakerCreatePresignedNotebookURL--user` | `arn:aws:iam::000000000000:user/privesc-sageMakerCreatePresignedNotebookURL-user` | privesc-sageMakerCreatePresignedNotebookURL | Allow: `sagemaker:CreatePresignedNotebookInstanceUrl`, `sagemaker:ListNotebookInstances` | an existing SageMaker notebook and its role | yes | yes - access key | **yes** | privesc |
| `privesc-sageMakerCreateProcessingJobPassRole--role` | `arn:aws:iam::000000000000:role/privesc-sageMakerCreateProcessingJobPassRole-role` | privesc-sageMakerCreateProcessingJobPassRole | Allow: `sagemaker:CreateProcessingJob`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via sagemaker | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc-sageMakerCreateProcessingJobPassRole--user` | `arn:aws:iam::000000000000:user/privesc-sageMakerCreateProcessingJobPassRole-user` | privesc-sageMakerCreateProcessingJobPassRole | Allow: `sagemaker:CreateProcessingJob`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via sagemaker | yes | yes - access key | **no** | privesc |
| `privesc-sageMakerCreateTrainingJobPassRole--role` | `arn:aws:iam::000000000000:role/privesc-sageMakerCreateTrainingJobPassRole-role` | privesc-sageMakerCreateTrainingJobPassRole | Allow: `sagemaker:CreateTrainingJob`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via sagemaker | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc-sageMakerCreateTrainingJobPassRole--user` | `arn:aws:iam::000000000000:user/privesc-sageMakerCreateTrainingJobPassRole-user` | privesc-sageMakerCreateTrainingJobPassRole | Allow: `sagemaker:CreateTrainingJob`, `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via sagemaker | yes | yes - access key | **no** | privesc |
| `privesc-ssmSendCommand--role` | `arn:aws:iam::000000000000:role/privesc-ssmSendCommand-role` | privesc-ssmSendCommand | Allow: `ec2:DescribeInstances`, `ssm:listCommands`, `ssm:listCommandInvocations`, `ssm:sendCommand` | command execution on an SSM-managed instance | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc-ssmSendCommand--user` | `arn:aws:iam::000000000000:user/privesc-ssmSendCommand-user` | privesc-ssmSendCommand | Allow: `ec2:DescribeInstances`, `ssm:listCommands`, `ssm:listCommandInvocations`, `ssm:sendCommand` | command execution on an SSM-managed instance | yes | yes - access key | **yes** | privesc |
| `privesc-ssmStartSession--role` | `arn:aws:iam::000000000000:role/privesc-ssmStartSession-role` | privesc-ssmStartSession | Allow: `ec2:DescribeInstances`, `ssm:StartSession`, `ssm:DescribeSessions`, `ssm:GetConnectionStatus` +3 more | shell on an SSM-managed instance | no | no - assume from `user/iamadmin` | **yes** | privesc |
| `privesc-ssmStartSession--user` | `arn:aws:iam::000000000000:user/privesc-ssmStartSession-user` | privesc-ssmStartSession | Allow: `ec2:DescribeInstances`, `ssm:StartSession`, `ssm:DescribeSessions`, `ssm:GetConnectionStatus` +3 more | shell on an SSM-managed instance | yes | yes - access key | **yes** | privesc |
| `fn1-privesc3-partial--role` | `arn:aws:iam::000000000000:role/fn1-privesc3-partial-role` | fn1-privesc3-partial | Allow: `ec2:DescribeInstances`, `ec2:RunInstances`; Allow: `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via ec2 | no | no - assume from `user/iamadmin` | **no** | tool-test-FN |
| `fn1-privesc3-partial--user` | `arn:aws:iam::000000000000:user/fn1-privesc3-partial-user` | fn1-privesc3-partial | Allow: `ec2:DescribeInstances`, `ec2:RunInstances`; Allow: `iam:PassRole` | privesc-high-priv-service-role (`*:*`) via ec2 | yes | yes - access key | **no** | tool-test-FN |
| `fn2-exploitableResourceConstraint--role` | `arn:aws:iam::000000000000:role/fn2-exploitableResourceConstraint-role` | fn2-exploitableResourceConstraint | Allow: `iam:CreatePolicyVersion` on `arn:aws:iam::*:policy/fn2-*` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | tool-test-FN |
| `fn2-exploitableResourceConstraint--user` | `arn:aws:iam::000000000000:user/fn2-exploitableResourceConstraint-user` | fn2-exploitableResourceConstraint | Allow: `iam:CreatePolicyVersion` on `arn:aws:iam::*:policy/fn2-*` | any IAM principal -> account admin | yes | yes - access key | **no** | tool-test-FN |
| `fn3-exploitableConditionConstraint--role` | `arn:aws:iam::000000000000:role/fn3-exploitableConditionConstraint-role` | fn3-exploitableConditionConstraint | Allow: `iam:CreatePolicyVersion` **+condition** | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | tool-test-FN |
| `fn3-exploitableConditionConstraint--user` | `arn:aws:iam::000000000000:user/fn3-exploitableConditionConstraint-user` | fn3-exploitableConditionConstraint | Allow: `iam:CreatePolicyVersion` **+condition** | any IAM principal -> account admin | yes | yes - access key | **no** | tool-test-FN |
| `fn4-exploitableNotAction--role` | `arn:aws:iam::000000000000:role/fn4-exploitableNotAction-role` | fn4-exploitableNotAction | Allow NotAction: `iam:Update*`, `iam:Create*`, `iam:Attach*` | any IAM principal -> account admin | no | no - assume from `user/iamadmin` | **no** | tool-test-FN |
| `fn4-exploitableNotAction--user` | `arn:aws:iam::000000000000:user/fn4-exploitableNotAction-user` | fn4-exploitableNotAction | Allow NotAction: `iam:Update*`, `iam:Create*`, `iam:Attach*` | any IAM principal -> account admin | yes | yes - access key | **no** | tool-test-FN |
| `fp1-allow-and-deny--role` | `arn:aws:iam::000000000000:role/fp1-allow-and-deny-role` | fp1-allow-and-deny | Allow: `iam:*`; Deny: `iam:*` | none - correct behaviour is to report nothing | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `fp1-allow-and-deny--user` | `arn:aws:iam::000000000000:user/fp1-allow-and-deny-user` | fp1-allow-and-deny | Allow: `iam:*`; Deny: `iam:*` | none - correct behaviour is to report nothing | yes | yes - access key | **n/a** | tool-test-FP |
| `fp2-allow-and-deny-multiple-policies--role` | `arn:aws:iam::000000000000:role/fp2-allow-and-deny-multiple-policies-role` | fp2-allow-and-deny-multiple-policies | Allow: `*`; Deny: `*` | none - correct behaviour is to report nothing | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `fp2-allow-and-deny-multiple-policies--user` | `arn:aws:iam::000000000000:user/fp2-allow-and-deny-multiple-policies-user` | fp2-allow-and-deny-multiple-policies | Allow: `*`; Deny: `*` | none - correct behaviour is to report nothing | yes | yes - access key | **n/a** | tool-test-FP |
| `fp3-deny-iam--role` | `arn:aws:iam::000000000000:role/fp3-deny-iam-role` | fp3-deny-iam | Deny: `iam:*` | none - correct behaviour is to report nothing | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `fp3-deny-iam--user` | `arn:aws:iam::000000000000:user/fp3-deny-iam-user` | fp3-deny-iam | Deny: `iam:*` | none - correct behaviour is to report nothing | yes | yes - access key | **n/a** | tool-test-FP |
| `fp4-nonExploitableResourceConstraint--role` | `arn:aws:iam::000000000000:role/fp4-nonExploitableResourceConstraint-role` | fp4-nonExploitableResourceConstraint | Allow: `iam:CreatePolicyVersion` on `arn:aws:iam::aws:policy/fp4-*` | none - correct behaviour is to report nothing | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `fp4-nonExploitableResourceConstraint--user` | `arn:aws:iam::000000000000:user/fp4-nonExploitableResourceConstraint-user` | fp4-nonExploitableResourceConstraint | Allow: `iam:CreatePolicyVersion` on `arn:aws:iam::aws:policy/fp4-*` | none - correct behaviour is to report nothing | yes | yes - access key | **n/a** | tool-test-FP |
| `fp5-nonExploitableConditionConstraint--role` | `arn:aws:iam::000000000000:role/fp5-nonExploitableConditionConstraint-role` | fp5-nonExploitableConditionConstraint | Allow: `iam:CreatePolicyVersion` **+condition** | none - correct behaviour is to report nothing | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `fp5-nonExploitableConditionConstraint--user` | `arn:aws:iam::000000000000:user/fp5-nonExploitableConditionConstraint-user` | fp5-nonExploitableConditionConstraint | Allow: `iam:CreatePolicyVersion` **+condition** | none - correct behaviour is to report nothing | yes | yes - access key | **n/a** | tool-test-FP |
| `privesc-permissive-role-trust--role` | `arn:aws:iam::000000000000:role/privesc-permissive-role-trust` | privesc-permissive-role-trust | _none_ | the role itself, which holds no policies | no | no - assume from `user/iamadmin` | **n/a** | tool-test-FP |
| `privesc-AssumeRole-start--user` | `arn:aws:iam::000000000000:user/privesc-AssumeRole-start-user` | privesc-AssumeRole-start | _none_ | none | yes | yes - access key | **n/a** | inert |
| `privesc-AssumeRole-starting--role` | `arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role` | privesc-AssumeRole-starting | _none_ | privesc-AssumeRole-ending-role (`*:*`), 2 hops on | no | no - assume from `user/iamadmin` | **no** | chain-hop |
| `privesc-AssumeRole-intermediate--role` | `arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role` | privesc-AssumeRole-intermediate | _none_ | privesc-AssumeRole-ending-role (`*:*`), 1 hop on | no | no - assume from `user/iamadmin` | **no** | chain-hop |
| `privesc-AssumeRole-ending--role` | `arn:aws:iam::000000000000:role/privesc-AssumeRole-ending-role` | privesc-AssumeRole-ending | Allow: `*` | terminus | no | no - assume from `user/iamadmin` | **n/a** | target-only |
| `privesc-high-priv-service--role` | `arn:aws:iam::000000000000:role/privesc-high-priv-service-role` | privesc-high-priv-service | Allow: `*`; Allow: `ssm:DescribeAssociation`, `ssm:GetDeployablePatchSnapshotForInstance`, `ssm:GetDocument`, `ssm:DescribeDocument` +11 more; Allow: `ssmmessages:CreateControlChannel`, `ssmmessages:CreateDataChannel`, `ssmmessages:OpenControlChannel`, `ssmmessages:OpenDataChannel`; Allow: `ec2messages:AcknowledgeMessage`, `ec2messages:DeleteMessage`, `ec2messages:FailMessage`, `ec2messages:GetEndpoint` +2 more | terminus | no | no - assume from `user/iamadmin` | **n/a** | target-only |
| `privesc-sre--role` | `arn:aws:iam::000000000000:role/privesc-sre-role` | privesc-sre | Allow: `iam:*`, `ec2:*`, `s3:*` | privesc-sre-role (`iam:*`,`ec2:*`,`s3:*`) | no | no - assume from `user/iamadmin` | **no** | privesc |
| `privesc-sre--user` | `arn:aws:iam::000000000000:user/privesc-sre-user` | privesc-sre | Allow: `iam:*`, `ec2:*`, `s3:*` | privesc-sre-role (`iam:*`,`ec2:*`,`s3:*`) | yes | yes - access key | **no** | privesc |

---

## Mechanism notes

One entry per mechanism. Applies to both principal rows unless stated.

- **`privesc1-CreateNewPolicyVersion`** (privesc, target_absent **no**) — rewrite any customer-managed policy in place  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc2-SetExistingDefaultPolicyVersion`** (privesc, target_absent **yes**) — the grant (`iam:SetDefaultPolicyVersion` on `*`) is real, but escalation needs a customer-managed policy that already carries a more-permissive non-default version, and **none exists**: all 45 account-owned policies have exactly one version (only AWS-managed policies are multi-version, and those cannot be targeted). The principal has no `iam:CreatePolicyVersion` to manufacture one. Corrected from **no** on 2026-08-31 after Phase-3 validation — see `analysis/validation/privesc2-SetExistingDefaultPolicyVersion--role.md` and the Corrections table  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc3-CreateEC2WithExistingInstanceProfile`** (privesc, target_absent **no**) — instance profile confirmed present and bound to the high-priv role; exploitation launches a billable EC2  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc4-CreateAccessKey`** (privesc, target_absent **no**) — mint keys for any user, incl. iamadmin  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc5-CreateLoginProfile`** (privesc, target_absent **no**) — set a console password on a user with no profile  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc6-UpdateLoginProfile`** (privesc, target_absent **no**) — reset an existing console password  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc7-AttachUserPolicy`** (privesc + non-path, target_absent **no**) — attach AdministratorAccess to self. **`--role` row corrected to `non-path` 2026-08-31.** `iam:AttachUserPolicy` can only target a user, so the role cannot attach to itself; it holds one grant and no way to mint or take over a user credential, and no role trusts it. It can make another principal admin but cannot escalate itself. The `--user` row is unchanged and is a working path. See `analysis/validation/privesc7-AttachUserPolicy--role.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc8-AttachGroupPolicy`** (privesc + non-path, target_absent **no**) — attach admin to privesc8-AttachGroupPolicy-group, which the user is in. **`--role` row corrected to `non-path` 2026-08-31.** IAM groups contain users only, so the role cannot join the group it can empower. The `--user` row is a member of `privesc8-AttachGroupPolicy-group` (which carries zero policies today) and is a working path. See `analysis/validation/privesc8-AttachGroupPolicy--role.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc9-AttachRolePolicy`** (privesc + non-path, target_absent **no**) — attach admin to any assumable role. **`--user` row corrected to `non-path` 2026-08-31.** The user can attach admin to any role and cannot assume one: it is named in no trust policy, holds no `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy` and no `iam:PassRole`. The `--role` row self-attaches and is a working path. See `analysis/validation/privesc9-AttachRolePolicy--user.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc10-PutUserPolicy`** (privesc + non-path, target_absent **no**) — inline admin policy on self. **`--role` row corrected to `non-path` 2026-08-31.** Same shape as `privesc7`: `iam:PutUserPolicy` targets users only. See `analysis/validation/privesc10-PutUserPolicy--role.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc11-PutGroupPolicy`** (privesc + non-path, target_absent **no**) — inline admin policy on privesc11-PutGroupPolicy-group, which the user is in. **`--role` row corrected to `non-path` 2026-08-31.** Same shape as `privesc8`: a role cannot be a group member. See `analysis/validation/privesc11-PutGroupPolicy--role.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc12-PutRolePolicy`** (privesc + non-path, target_absent **no**) — inline admin policy on any assumable role. **`--user` row corrected to `non-path` 2026-08-31.** Same shape as `privesc9`: the user can write an inline admin policy onto any role and can assume none. See `analysis/validation/privesc12-PutRolePolicy--user.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc13-AddUserToGroup`** (privesc, target_absent **no**) — group membership confirmed to carry privesc-sre-admin-policy  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc14-UpdatingAssumeRolePolicy`** (privesc, target_absent **no**) — rewrite a trust policy to name yourself, then assume  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc15-PassExistingRoleToNewLambdaThenInvoke`** (privesc, target_absent **no**) — trust policy of the target role confirmed to include lambda.amazonaws.com  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo`** (privesc, target_absent **no**) — same target; triggered via a new event source mapping  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc17-EditExistingLambdaFunctionWithRole`** (privesc, target_absent **no**) — **not the lab's target.** The lab's own lambda module is disabled, but an unrelated pre-existing function `EC2-AutoRemediation` is present in this account and is the only reachable target. Escalation yields EC2 read/tagging, NOT admin - a tool reporting this as a path to admin is an overstated-impact FP under rubric 4.8  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc18-PassExistingRoleToNewGlueDevEndpoint`** (privesc, target_absent **yes**) — `glue:CreateDevEndpoint` cannot succeed: AWS has disabled Glue dev endpoints account-wide. `GetDevEndpoints` returns `AccessDeniedException: operation is currently disabled`. The permission is real; the AWS-side capability is gone  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc19-UpdateExistingGlueDevEndpoint`** (privesc, target_absent **yes**) — no dev endpoints exist and the API is disabled account-wide (verified)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc20-PassExistingRoleToCloudFormation`** (privesc, target_absent **no**) — creates a new stack; no pre-existing stack needed  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc21-PassExistingRoleToNewDataPipeline`** (privesc, target_absent **no**) — creates a new pipeline. Data Pipeline is closed to new customers; whether this account can still create one is **inferred, not confirmed** - validate before grading  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-CloudFormationUpdateStack`** (privesc, target_absent **yes**) — `cloudformation:UpdateStack` needs an existing stack. Zero stacks exist in any of the 17 enabled regions. The one stack that briefly made this exploitable was `iamwho-stress-test-roles`, deleted 2026-08-31 to keep the baseline uncontaminated. See the Corrections table and `account-baseline.md`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-codeBuildCreateProjectPassRole`** (privesc, target_absent **no**) — creates a new project; trust policy includes codebuild.amazonaws.com  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-ec2InstanceConnect`** (privesc, target_absent **yes**) — `describe-instances` returns 0 reservations (verified)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-sageMakerCreateNotebookPassRole`** (privesc, target_absent **no**) — creates a new notebook instance (billable at exploit time)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-sageMakerCreatePresignedNotebookURL`** (privesc, target_absent **yes**) — `list-notebook-instances` returns 0 (verified)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-sageMakerCreateProcessingJobPassRole`** (privesc, target_absent **no**) — creates a new processing job  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-sageMakerCreateTrainingJobPassRole`** (privesc, target_absent **no**) — creates a new training job  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-ssmSendCommand`** (privesc, target_absent **yes**) — `ssm describe-instance-information` returns 0 managed nodes (verified)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-ssmStartSession`** (privesc, target_absent **yes**) — `ssm describe-instance-information` returns 0 managed nodes (verified)  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fn1-privesc3-partial`** (tool-test-FN, target_absent **no**) — privesc3 split across two policies (`ec2:RunInstances` + `iam:PassRole`). A tool that only evaluates one policy at a time misses it  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fn2-exploitableResourceConstraint`** (tool-test-FN, target_absent **no**) — `iam:CreatePolicyVersion` scoped to `arn:aws:iam::*:policy/fn2-*` - the constraint looks limiting but matches the principal's own policy  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fn3-exploitableConditionConstraint`** (tool-test-FN, target_absent **no**) — condition is `DateGreaterThan aws:TokenIssueTime 2020-01-01` - always true. A tool that treats any condition as blocking misses it  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fn4-exploitableNotAction`** (tool-test-FN, target_absent **no**) — `NotAction` on `iam:Update*`,`iam:Create*`,`iam:Attach*` still allows `iam:PutUserPolicy`  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fp1-allow-and-deny`** (tool-test-FP, target_absent **n/a**) — `Allow iam:*` and `Deny iam:*` in the same policy  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fp2-allow-and-deny-multiple-policies`** (tool-test-FP, target_absent **n/a**) — `Allow *:*` and `Deny *:*` in two separate attached policies  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fp3-deny-iam`** (tool-test-FP, target_absent **n/a**) — `Deny iam:*` only; no allow at all  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fp4-nonExploitableResourceConstraint`** (tool-test-FP, target_absent **n/a**) — `iam:CreatePolicyVersion` scoped to `arn:aws:iam::aws:policy/fp4-*`, the AWS-owned namespace - unwritable  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`fp5-nonExploitableConditionConstraint`** (tool-test-FP, target_absent **n/a**) — condition is `DateLessThan aws:TokenIssueTime 2020-01-01` - never true  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-permissive-role-trust`** (tool-test-FP, target_absent **n/a**) — trust policy names `:root`, so any principal in the account can assume it - but the role has **zero** attached policies, so assuming it grants nothing. Reporting this as an escalation path is an overstated-impact FP under rubric 4.8  
  _Role trust:_ `arn:aws:iam::000000000000:root`
- **`privesc-AssumeRole-start`** (inert, target_absent **n/a**) — has an access key but **zero** permissions and is named in no trust policy. It cannot reach `privesc-AssumeRole-starting-role`, which trusts `user/iamadmin` instead. A tool reporting this user as a chain entry point is an FP
- **`privesc-AssumeRole-starting`** (chain-hop, target_absent **no**) — hop 1. Trusted principal is `user/iamadmin` because `aws_assume_role_arn` was left at its default  
  _Role trust:_ `arn:aws:iam::000000000000:user/iamadmin`
- **`privesc-AssumeRole-intermediate`** (chain-hop, target_absent **no**) — hop 2  
  _Role trust:_ `arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role`
- **`privesc-AssumeRole-ending`** (target-only, target_absent **n/a**) — holds `privesc-AssumeRole-high-priv-policy` (`Allow *:*`)  
  _Role trust:_ `arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role`
- **`privesc-high-priv-service`** (target-only, target_absent **n/a**) — holds `Allow *:*`; trusted by 10 AWS services. The target of every PassRole mechanism above  
  _Role trust:_ `service:lambda.amazonaws.com,eks.amazonaws.com,sagemaker.amazonaws.com,datapipeline.amazonaws.com,ec2.amazonaws.com,glue.amazonaws.com,cloudformation.amazonaws.com,ecs-tasks.amazonaws.com,elasticbeanstalk.amazonaws.com,codebuild.amazonaws.com`
- **`privesc-sre`** (privesc, target_absent **no**) — `privesc-sre-user` holds no direct policy; its privilege comes from `privesc-sre-group`. The role trusts the user directly  
  _Role trust:_ `arn:aws:iam::000000000000:user/privesc-sre-user`

---

## Known gaps in this list

Recorded per the CLAUDE.md constraint to flag inference rather than assert it.

1. **This list is derived from declared and resolved IAM state, not from a policy
   evaluation sweep.** It enumerates the paths the lab author placed. Emergent
   paths — combinations across principals that nobody intended — are not
   systematically covered. Rubric §7 names an `iam:SimulatePrincipalPolicy`
   oracle as the fix and puts it out of scope for this phase. Anything found
   during Phase 3 validation that is not on this list goes in the §6.1 bucket.
2. **`privesc21-PassExistingRoleToNewDataPipeline` is marked `target_absent = no`
   by inference.** AWS Data Pipeline is closed to new customers; whether this
   account can still create a pipeline was not tested. Validate before grading.
3. **The 13 non-lab principals above are not scenario rows** and are not in the
   denominator. If a tool reports a path through them it is an off-list finding,
   not a hit and not an FP.
4. **`target_absent` was verified by resource-existence checks, not by attempting
   exploitation.** A `no` means a target exists, not that the path has been
   proven to work end to end. That is Phase 3's job.

## Corrections

| Date | Row | Change | Cause |
|---|---|---|---|
| 2026-08-31 | `privesc-CloudFormationUpdateStack` (both rows) | `target_absent` **yes → no** | First pass checked `us-east-1` only. A 17-region sweep found a CloudFormation stack in `us-west-2`. |
| 2026-08-31 | `privesc-CloudFormationUpdateStack` (both rows) | `target_absent` **no → yes** (reverted) | The only reachable stack was `iamwho` residue — the fixture stack that created the deleted `iamwho-test-*` roles. It was removed to keep the baseline uncontaminated, so no stack exists in any region and the target is genuinely absent. Grading a scenario as exploitable only because the withheld tool's own leftovers made it so would not have been defensible. |
| 2026-08-31 | `privesc2-SetExistingDefaultPolicyVersion` (both rows) | `target_absent` **no → yes** | Phase-3 validation: escalation requires a customer-managed policy with a more-permissive existing version to activate; zero account-owned policies have >1 version and the principal lacks `iam:CreatePolicyVersion`, so the target does not exist. Verified via `get-account-authorization-details`. |
| 2026-08-31 | header §2 | rewritten twice | 11 `iamwho-test-*` roles deleted, then the fixture stack and its template bucket. See `fixture-removal-2026-08-31.md`. |
| 2026-08-31 (Phase-4 addendum) | `privesc7-AttachUserPolicy--role`, `privesc8-AttachGroupPolicy--role`, `privesc10-PutUserPolicy--role`, `privesc11-PutGroupPolicy--role` | class **`privesc` → `non-path`** | Each role holds exactly one grant, targeting a construct it is not (a user, or a group it cannot join), and has no credential-minting permission and no inbound trust. It can make another principal administrative but cannot escalate itself. PMapper reported the `--user` sibling of each and not these; the asymmetry was PMapper being right. Rubric §6: an M that is not a real path is a scenario-list error, not a tool miss. Four validation files. |
| 2026-08-31 (Phase-4 addendum) | `privesc9-AttachRolePolicy--user`, `privesc12-PutRolePolicy--user` | class **`privesc` → `non-path`** | Mirror image of the four above. Each user can make any role administrative and can assume none: named in no trust policy, no `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy`, no `iam:PassRole`. PMapper reported the `--role` sibling of each. Two validation files. |
| 2026-08-31 (Phase-4 addendum) | `privesc-ssmSendCommand` (both rows), `privesc-ssmStartSession` (both rows) | no change to the row; **PMapper regraded D → FP** | Not a scenario-list correction — the rows were already `target_absent = yes` and correct. Recorded here because the four validation files written in the same pass confirm PMapper asserts a path through an EC2 instance that does not exist in any of the 17 enabled regions, making these the benchmark's first confirmed false positives. See `matrix.md` §6. |
