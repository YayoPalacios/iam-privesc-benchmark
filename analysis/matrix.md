# Detection matrix

Phase 4, **including the 2026-08-31 addendum** (§0). The deliverable. Assembled from
`analysis/grades.csv`, which is assembled from `analysis/scenarios.md`, `raw-output/`
and `analysis/validation/`. Nothing in this file draws on anything else.

Per-cell evidence, search strings and reasoning live in `grades.csv` — one row per
`(scenario, tool, context, flagset)`, 344 rows. This file is the rollup and the
argument. Where the two disagree, `grades.csv` is authoritative on the cell and this
file is authoritative on the counting.

**Every count here is an absolute count against a stated denominator.** No
percentages, per rubric §2.1.

---

## 0. Addendum, 2026-08-31 — what changed and what it did to the headline

Three items, all resolved from evidence already in the repository. No new AWS calls
were made; the primary sources were PMapper's archived graph, cloudfox's CSV output
and the account-wide sweep in `analysis/account-baseline.md`.

### 0.1 The six-row asymmetry: resolved against the scenario list, not against PMapper

The original matrix flagged six rows where PMapper reported one principal of a
mechanism and not the other, and said the question of whether those rows were real
paths was the top validation priority. **They are not real paths.** One validation
file per principal, all six confirmed: the principal holds exactly one grant, that
grant targets a construct the principal is not, and there is no route to
authenticating as the principal it can empower.

| Row | Can it self-target? | Can it reach what it empowers? |
|---|---|---|
| `privesc7-AttachUserPolicy--role` | no — `AttachUserPolicy` targets users | no key-minting permission; roles hold no access keys |
| `privesc10-PutUserPolicy--role` | no — `PutUserPolicy` targets users | same |
| `privesc8-AttachGroupPolicy--role` | no — roles cannot join IAM groups | cannot authenticate as any group member |
| `privesc11-PutGroupPolicy--role` | no — roles cannot join IAM groups | same |
| `privesc9-AttachRolePolicy--user` | no — `AttachRolePolicy` targets roles | named in no trust policy; no `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy`, no `iam:PassRole` |
| `privesc12-PutRolePolicy--user` | no — `PutRolePolicy` targets roles | same |

The sibling PMapper *did* report is, in every case, the one that can point the
permission at itself — and PMapper's own graph marks exactly those six
`is_admin: true` and these six `is_admin: false`. **The asymmetry was PMapper being
right.** Rubric §6: *"A M that turns out not to be a real path is a scenario-list
error, not a tool miss."* The six rows are reclassified `privesc` → **`non-path`** in
`scenarios.md` and leave the detection denominator.

### 0.2 The four SSM candidates: confirmed false positives

PMapper (region-scoped) asserts that `privesc-ssmSendCommand` and
`privesc-ssmStartSession`, both principals each, reach
`role/privesc-high-priv-service-role` **via an EC2 instance**. The account contains
zero EC2 instances and zero SSM-managed nodes across all 17 enabled regions, from the
direct per-service sweep in `account-baseline.md`. One validation file per row;
regraded **D → FP** under §3 and §4.8.

These rows sat in the target-absent bucket and were never in a detection count, so
the regrade moves no detection number. It moves PMapper's false-positive count off
zero for the first time.

### 0.3 A grade for correct silence

Rubric §9 gained **CS — Correctly Silent**, dated 2026-08-31, naming the twelve
fixture rows that forced it. The `none` placeholders are gone. Three constraints
travel with the grade and are applied here: CS requires the tool to have produced
output, CS never enters a detection count, and CS alone is not evidence of
correctness. The first of those is why the crashed PMapper default run scores **M**,
not CS, on all 18 no-path rows — it cannot be credited for silence it did not choose.

### 0.4 PMapper's detection headline, before and after

The region-scoped run is the only PMapper data that exists, so this is the number the
post will quote. **Nothing about PMapper's output changed** — the same file was
graded twice against a corrected scenario list.

| | before addendum | after addendum |
|---|---|---|
| **Detection bucket, mechanisms** | **D 21 of 31** · M 10 | **D 27 of 31** · M 4 |
| **Detection bucket, rows** | **D 44 of 58** · M 14 | **D 44 of 52** · M 8 |
| Canonical (`privesc`, live target), mechanisms | D 14 of 23 · M 9 | **D 20 of 23** · M 3 |
| Canonical, rows | D 34 of 46 · M 12 | **D 34 of 40** · M 6 |
| Confirmed false positives | 0 (4 open candidates) | **4 rows / 2 mechanisms** |
| Cells flagged inferred (all columns) | 51 of 344 | **41 of 344** |

**The D count did not move; the denominator did.** PMapper detected 44 rows before
and 44 after. Six rows it was scored against turned out not to be paths, and the
denominator fell from 58 to 52. Any reading of this as PMapper improving is wrong,
and the post should say the correction was to the ground truth.

The remaining four missed mechanisms are `privesc13-AddUserToGroup`,
`privesc17-EditExistingLambdaFunctionWithRole`, `fn3-exploitableConditionConstraint`
and `privesc21-PassExistingRoleToNewDataPipeline` — §5.2.

---

## 1. What is being graded, and what is not

Rubric §5.1: **this is an admin-context matrix.** Every graded cell is the
`admin` (`user/iamadmin`, `AdministratorAccess`) run. The `limited`
(`SecurityAudit`) runs are reported as a qualitative delta in §8 and are not graded
per scenario.

Four columns, because two tools produced four distinguishable results:

| Column | Run | Why it exists |
|---|---|---|
| **PMapper — default** | `raw-output/pmapper/admin-default-2026-08-31/` | The default invocation. It crashed. §4.2 makes the default run the headline and §4.7 makes a crash an M, so this is the headline PMapper column and it is all Ms. |
| **PMapper — region-scoped** | `raw-output/pmapper/admin-flagged-2026-08-31/` | The retry that completed, with `graph create --include-regions <17 opted-in regions>`. The only PMapper data that exists. |
| **cloudfox — own surfaces** | `raw-output/cloudfox/admin-default-2026-08-31/` | Default invocation, `aws all-checks`. Graded on the surfaces cloudfox computes itself: `permissions`, `principals`, `iam-simulator`, `role-trusts`, `lambda`, `workloads`. |
| **cloudfox — path column** | same run | `CanPrivEscToAdmin?`. **N/A on all 86 rows**, per §3. |

### 1.1 The two decisions taken as given

Both were open questions in the run metadata. Both are applied as instructed, and
both change what the matrix means, so they are stated before any number.

**(a) cloudfox's path column is N/A under rubric §4.9.** cloudfox delegates
privilege-escalation *path* enumeration to PMapper and documents that it does so. The
§4.9 bar is a quoted, linked disclaimer, and it is met:

> Cloudfox will not install or run `pmapper` for you, but because `pmapper` stores
> it's graph data in a predictable location, this CloudFox command will look to see
> if that data exists, and if it does, it give you a list of all of the principals
> that pmapper thinks can escalate to admin.
>
> — <https://github.com/BishopFox/cloudfox/wiki/AWS-Commands#pmapper>

In this run PMapper data did not exist on disk, and cloudfox's path column reads
`Skipping, no pmapper data` in **all 140** of its instances (94 `principals` rows +
44 `role-trusts-principals` + 1 root-trust + 1 `workloads`). §3: *"Record it; do not
score it as a miss."*

**N/A is applied to the path column only, not to cloudfox as a tool.** §4.9 warns
that a generous reading *"would void most misses for a tool that never advertised
path enumeration, and would make the matrix vacuous"* — grading cloudfox N/A across
the board is exactly that failure. cloudfox's own surfaces are graded normally and
are where its 3 D's, 47 P's and 2 M's come from.

The consequence for the reader: **cloudfox and PMapper are not independent columns on
path scenarios.** Had PMapper's graph been on disk when cloudfox ran, cloudfox's path
column would have been a rendering of PMapper's answer. The runs were deliberately
ordered so that never happened (cloudfox ran first, on a machine where PMapper had
never run; verified in both run-metadata files).

**(b) PMapper's headline is the crashed default run; the region-scoped run is the
graded data. Both are in the matrix.** `graph create` terminated on an unhandled
`botocore.exceptions.ConnectTimeoutError` reaching `autoscaling.me-south-1` — a
not-opted-in region whose endpoint did not answer. `autoscaling_edges.py` catches
`ClientError`, and a transport timeout is a `BotoCoreError`, so it propagates out and
kills the process on the **first of nine** edge checks (`edge_identification.checker_map`
has nine entries; the region-scoped run logs nine `Generating Edges` lines). The graph is
never serialised; six of the seven downstream commands fail. The seventh, `graph list`,
exits 0 and prints an empty account list.

So the honest summary of PMapper on this account is two sentences that must travel
together: *the default invocation produced nothing*, and *every PMapper number below
exists only because the tool was given a flag to route around its own unhandled
exception*. The flag (`--include-regions`, restricted to the account's 17 opted-in
regions) is detection-neutral by construction — AWS does not permit resource creation
in a region an account has not enabled — but it is non-default, and §4.2 forbids
merging the two into one score. They are two columns.

---

## 2. Grading conventions

Decisions the rubric did not pre-settle. Recorded rather than applied silently.

**2.1 — Three buckets, three denominators.** `scenarios.md` says `target_absent` rows
*"are graded in their own bucket"*; its `tool-test-FP`, `inert` and (since the
addendum) `non-path` rows have no path to detect at all. The 46 mechanisms / 86
principal rows split:

| Bucket | mechanisms | rows | What the grade means |
|---|---:|---:|---|
| **Detection** | 31 | 52 | D/P/M ladder. The headline numbers. |
| **Target-absent** | 8 | 16 | The grant is real; the exploitation target does not exist here. A tool naming it is right about the permission and wrong about exploitability — a §4.8 question. |
| **No-path** | 13 † | 18 | No escalation path exists to detect. CS or FP only (rubric §9, 2026-08-31). |

† Six of those 13 mechanisms (`privesc7`–`privesc12`) also appear in the detection
bucket, because one of their two principals can self-escalate and the other cannot.
Mechanism counts across buckets therefore do not sum to 46; row counts do
(52 + 16 + 18 = 86).

Detection bucket = 23 `privesc` mechanisms with a live target, 4 `tool-test-FN`,
2 `chain-hop`, 2 `target-only`.

**2.2 — PMapper's "is an administrative principal" verdict is graded D.** For 16
principal rows PMapper's privesc preset does not print a path; it prints
`<principal> is an administrative principal`. That names the principal and the
resulting privilege but **not** the enabling permission, so it does not satisfy §3's
D wording literally.

It is graded D anyway, because neither lower grade fits its own definition either:
**P** requires *"a risky permission bound to a specific principal"*, which the line
does not do; **M** requires *"nothing in the output points a reviewer at this path"*,
which is false — the principal is named as administrative in the privesc preset and
again in `analysis`'s MFA findings. §4.6 ("ambiguity defaults down") governs a choice
*between two grades*; here P and M are each excluded by their own text, so there is no
ladder to descend. Precedent for this reading was set, before Phase 4 grading began,
in `analysis/validation/privesc-sre--user.md`.

**All 16 such cells are flagged `inferred`.** The claim that PMapper's admin verdict
is *derived from the scenario's mechanism* is a reading of its output, not of its
source; PMapper's admin-detection code was not read.

**2.3 — cloudfox's `permissions` module earns P, not M.** §4.1: *"A list of dangerous
permission names with no principal binding is M, not P. Partial credit requires the
output to tie the permission to a specific principal."* cloudfox's `permissions.csv`
is exactly a principal-bound list — 6008 rows of `(principal, policy, effect, action,
resource, condition)` — so it clears the §4.1 bar. It names no target and
characterises nothing as escalation, which is §3's P verbatim. Every P cell records
its `grep` string in `grades.csv`, per §4.5.

**2.4 — §4.7 applied literally to cloudfox's throttled principals.** cloudfox's
`iam-simulator` exhausted its 3 retries on `SimulatePrincipalPolicy … Throttling:
Rate exceeded` for three principals: `privesc6-UpdateLoginProfile--user`,
`privesc-codeBuildCreateProjectPassRole--user` and `privesc10-PutUserPolicy--role`.
§4.7 makes the affected scenarios M. Two of them are in the detection bucket and take
that M; the third (`privesc10--role`) moved to the no-path bucket in the addendum and
now grades CS, so **the throttle still counts as three §4.7 events in the maintenance
tally but costs only two detection grades.** Both facts are in `grades.csv`.

The sharper finding is that **these failures are invisible in cloudfox's output
surface.** They appear only in `cloudfox-logs/cloudfox-error.log`; the three
principals still print with `IsAdminRole? = No`, indistinguishable from a genuine
negative.

**2.5 — CS, and why the crashed column does not earn it.** The rubric gap flagged in
the first pass is closed: §9 now defines **CS — Correctly Silent** for a row with no
path to detect where the tool ran, produced output, and made no escalation claim. CS
never enters a detection count. A tool that produced nothing cannot earn it, so all 18
no-path rows in the PMapper default column are **M** under §4.7 rather than CS. A
crashed tool passes every false-positive test ever devised; that is not a result.

---

## 3. Headline counts

### 3.1 Detection bucket — mechanism level

Rubric §2.1: a mechanism counts as detected only if the tool detects it for **every**
principal that has it. The same lowest-grade-wins rule is used for P and M.

**Denominator: 31 mechanisms.**

| Column | D | P | M | N/A |
|---|---:|---:|---:|---:|
| PMapper — default | 0 | 0 | **31** | 0 |
| PMapper — region-scoped | **27** | 0 | 4 | 0 |
| cloudfox — own surfaces | 3 | **26** | 2 | 0 |
| cloudfox — path column | 0 | 0 | 0 | **31** |

### 3.2 Detection bucket — principal-row level

**Denominator: 52 principal rows.**

| Column | D | P | M | N/A |
|---|---:|---:|---:|---:|
| PMapper — default | 0 | 0 | **52** | 0 |
| PMapper — region-scoped | **44** | 0 | 8 | 0 |
| cloudfox — own surfaces | 3 | **47** | 2 | 0 |
| cloudfox — path column | 0 | 0 | 0 | **52** |

After the addendum the mechanism and row rollups agree for PMapper for the first
time: there is no longer any mechanism where it catches one principal and misses the
other. That split was the whole reason §2.1 mandates both denominators, and resolving
it is what closed the gap.

### 3.3 The canonical sub-denominator

Rubric §2's known bias: IAM Vulnerable derives from the Rhino Security Labs catalog
and both tools were substantially built to detect it, so high scores here are the
expected outcome and not evidence of quality. That catalog is the `privesc` class
with a live target — **23 mechanisms / 40 rows**.

| Column | mechanisms (of 23) | rows (of 40) |
|---|---|---|
| PMapper — default | D 0 · M 23 | D 0 · M 40 |
| PMapper — region-scoped | **D 20** · M 3 | **D 34** · M 6 |
| cloudfox — own surfaces | D 0 · P 21 · M 2 | D 0 · P 38 · M 2 |
| cloudfox — path column | N/A 23 | N/A 40 |

### 3.4 The sub-buckets that are not the canonical catalog

Small denominators; stated as counts, not compared.

| Sub-bucket | mech | rows | PMapper region-scoped | cloudfox own surfaces |
|---|---:|---:|---|---|
| `tool-test-FN` — designed true positives naive analysis misses | 4 | 8 | D 3 mech / 6 rows · M 1 mech / 2 rows | P 4 mech / 8 rows |
| `chain-hop` — the 3-role AssumeRole chain | 2 | 2 | D 2 / 2 | D 1 · P 1 |
| `target-only` — the two administrative termini | 2 | 2 | D 2 / 2 | D 2 / 2 |

---

## 4. The matrix

`D` detected · `P` partial · `M` missed · `FP` false positive · `CS` correctly silent
(§9, 2026-08-31) · `N/A` disclaimed (§4.9) · **`*` = the cell is inferred, not read
straight from output or a validation file.** Full reasoning per cell in `grades.csv`;
the complete inferred list is §9.

Columns: **PM-d** PMapper default · **PM-r** PMapper region-scoped · **CF** cloudfox
own surfaces · **CF-p** cloudfox path column. `V` marks a scenario with a file in
`analysis/validation/`.

### 4.A Detection bucket — 31 mechanisms / 52 rows

| scenario_id | PM-d | PM-r | CF | CF-p | V |
|---|:--:|:--:|:--:|:--:|:--:|
| `privesc1-CreateNewPolicyVersion--role` | M | D* | P | N/A | |
| `privesc1-CreateNewPolicyVersion--user` | M | D* | P | N/A | |
| `privesc3-CreateEC2WithExistingInstanceProfile--role` | M | D | P | N/A | |
| `privesc3-CreateEC2WithExistingInstanceProfile--user` | M | D | P | N/A | |
| `privesc4-CreateAccessKey--role` | M | D | P | N/A | ✓ |
| `privesc4-CreateAccessKey--user` | M | D | P | N/A | |
| `privesc5-CreateLoginProfile--role` | M | D | P | N/A | |
| `privesc5-CreateLoginProfile--user` | M | D | P | N/A | |
| `privesc6-UpdateLoginProfile--role` | M | D | P | N/A | |
| `privesc6-UpdateLoginProfile--user` | M | D | **M** | N/A | |
| `privesc7-AttachUserPolicy--user` | M | D* | P | N/A | |
| `privesc8-AttachGroupPolicy--user` | M | D* | P | N/A | |
| `privesc9-AttachRolePolicy--role` | M | D* | P | N/A | |
| `privesc10-PutUserPolicy--user` | M | D* | P | N/A | |
| `privesc11-PutGroupPolicy--user` | M | D* | P | N/A | |
| `privesc12-PutRolePolicy--role` | M | D* | P | N/A | |
| `privesc13-AddUserToGroup--role` | M | **M** | P | N/A | ✓ |
| `privesc13-AddUserToGroup--user` | M | **M** | P | N/A | |
| `privesc14-UpdatingAssumeRolePolicy--role` | M | D* | P | N/A | |
| `privesc14-UpdatingAssumeRolePolicy--user` | M | D* | P | N/A | |
| `privesc15-PassExistingRoleToNewLambdaThenInvoke--role` | M | D | P | N/A | |
| `privesc15-PassExistingRoleToNewLambdaThenInvoke--user` | M | D | P | N/A | |
| `privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo--role` | M | D | P | N/A | |
| `privesc16-PassRoleToNewLambdaThenTriggerWithNewDynamo--user` | M | D | P | N/A | |
| `privesc17-EditExistingLambdaFunctionWithRole--role` | M | **M** | P | N/A | ✓ |
| `privesc17-EditExistingLambdaFunctionWithRole--user` | M | **M** | P | N/A | ✓ |
| `privesc20-PassExistingRoleToCloudFormation--role` | M | D | P | N/A | |
| `privesc20-PassExistingRoleToCloudFormation--user` | M | D | P | N/A | |
| `privesc21-PassExistingRoleToNewDataPipeline--role` | M | **M*** | P | N/A | |
| `privesc21-PassExistingRoleToNewDataPipeline--user` | M | **M*** | P | N/A | |
| `privesc-codeBuildCreateProjectPassRole--role` | M | D | P | N/A | |
| `privesc-codeBuildCreateProjectPassRole--user` | M | D | **M** | N/A | |
| `privesc-sageMakerCreateNotebookPassRole--role` | M | D | P | N/A | |
| `privesc-sageMakerCreateNotebookPassRole--user` | M | D | P | N/A | |
| `privesc-sageMakerCreateProcessingJobPassRole--role` | M | D | P | N/A | |
| `privesc-sageMakerCreateProcessingJobPassRole--user` | M | D | P | N/A | |
| `privesc-sageMakerCreateTrainingJobPassRole--role` | M | D | P | N/A | |
| `privesc-sageMakerCreateTrainingJobPassRole--user` | M | D | P | N/A | |
| `fn1-privesc3-partial--role` | M | D | P | N/A | |
| `fn1-privesc3-partial--user` | M | D | P | N/A | |
| `fn2-exploitableResourceConstraint--role` | M | D* | P | N/A | |
| `fn2-exploitableResourceConstraint--user` | M | D* | P | N/A | |
| `fn3-exploitableConditionConstraint--role` | M | **M** | P | N/A | ✓ |
| `fn3-exploitableConditionConstraint--user` | M | **M** | P | N/A | ✓ |
| `fn4-exploitableNotAction--role` | M | D* | P | N/A | |
| `fn4-exploitableNotAction--user` | M | D* | P | N/A | |
| `privesc-AssumeRole-starting--role` | M | D | P | N/A | ✓ |
| `privesc-AssumeRole-intermediate--role` | M | D | D* | N/A | |
| `privesc-AssumeRole-ending--role` | M | D* | D | N/A | |
| `privesc-high-priv-service--role` | M | D* | D | N/A | |
| `privesc-sre--role` | M | D* | P | N/A | |
| `privesc-sre--user` | M | D* | P | N/A | ✓ |

### 4.B Target-absent bucket — 8 mechanisms / 16 rows

The grant is real; the target does not exist in this deployment. Verified across all
17 enabled regions (`analysis/account-baseline.md`). **Excluded from every count in
§3.**

| scenario_id | PM-d | PM-r | CF | CF-p | V | why the target is absent |
|---|:--:|:--:|:--:|:--:|:--:|---|
| `privesc2-SetExistingDefaultPolicyVersion--role` | M | M | P | N/A | ✓ | all 45 account-owned policies have exactly one version; principal has no `iam:CreatePolicyVersion` to make one |
| `privesc2-SetExistingDefaultPolicyVersion--user` | M | M | P | N/A | ✓ | same |
| `privesc18-PassExistingRoleToNewGlueDevEndpoint--role` | M | M | P | N/A | | AWS retired Glue dev endpoints account-wide |
| `privesc18-PassExistingRoleToNewGlueDevEndpoint--user` | M | M | P | N/A | | same |
| `privesc19-UpdateExistingGlueDevEndpoint--role` | M | M | P | N/A | | no dev endpoints; API disabled |
| `privesc19-UpdateExistingGlueDevEndpoint--user` | M | M | P | N/A | | same |
| `privesc-CloudFormationUpdateStack--role` | M | M | P | N/A | | zero stacks in any region |
| `privesc-CloudFormationUpdateStack--user` | M | M | P | N/A | | same |
| `privesc-ec2InstanceConnect--role` | M | M | P | N/A | | zero EC2 instances |
| `privesc-ec2InstanceConnect--user` | M | M | P | N/A | | same |
| `privesc-sageMakerCreatePresignedNotebookURL--role` | M | M | P | N/A | | zero notebook instances |
| `privesc-sageMakerCreatePresignedNotebookURL--user` | M | M | P | N/A | | same |
| `privesc-ssmSendCommand--role` | M | **FP** | P | N/A | ✓ | zero SSM-managed nodes |
| `privesc-ssmSendCommand--user` | M | **FP** | P | N/A | ✓ | zero SSM-managed nodes |
| `privesc-ssmStartSession--role` | M | **FP** | P | N/A | ✓ | zero SSM-managed nodes |
| `privesc-ssmStartSession--user` | M | **FP** | P | N/A | ✓ | zero SSM-managed nodes |

### 4.C No-path bucket — 18 rows

No escalation path exists to detect. CS or FP only. The first six rows are the
addendum's reclassifications (§0.1); the rest are the lab's designed FP fixtures and
its inert principal.

| scenario_id | PM-d | PM-r | CF | CF-p | V |
|---|:--:|:--:|:--:|:--:|:--:|
| `privesc7-AttachUserPolicy--role` | M† | CS | CS | N/A | ✓ |
| `privesc8-AttachGroupPolicy--role` | M† | CS | CS | N/A | ✓ |
| `privesc9-AttachRolePolicy--user` | M† | CS | CS | N/A | ✓ |
| `privesc10-PutUserPolicy--role` | M† | CS | CS | N/A | ✓ |
| `privesc11-PutGroupPolicy--role` | M† | CS | CS | N/A | ✓ |
| `privesc12-PutRolePolicy--user` | M† | CS | CS | N/A | ✓ |
| `fp1-allow-and-deny--role` | M† | CS* | CS* | N/A | |
| `fp1-allow-and-deny--user` | M† | CS* | CS* | N/A | |
| `fp2-allow-and-deny-multiple-policies--role` | M† | CS* | CS* | N/A | |
| `fp2-allow-and-deny-multiple-policies--user` | M† | CS* | CS* | N/A | |
| `fp3-deny-iam--role` | M† | CS* | CS* | N/A | |
| `fp3-deny-iam--user` | M† | CS* | CS* | N/A | |
| `fp4-nonExploitableResourceConstraint--role` | M† | CS* | CS* | N/A | |
| `fp4-nonExploitableResourceConstraint--user` | M† | CS* | CS* | N/A | |
| `fp5-nonExploitableConditionConstraint--role` | M† | CS* | CS* | N/A | |
| `fp5-nonExploitableConditionConstraint--user` | M† | CS* | CS* | N/A | |
| `privesc-permissive-role-trust--role` | M† | CS | CS | N/A | ✓ |
| `privesc-AssumeRole-start--user` | M† | CS | CS | N/A | ✓ |

† **Crash-M, not CS.** The PMapper default run produced no output at all, and §9
(2026-08-31) requires a tool to have run and produced output to earn Correctly
Silent. These are counted in the §4.7 crash tally, never as CS.

---

## 5. What the matrix shows

### 5.1 The six-row asymmetry was PMapper being right — and it took the scenario list with it

Resolved in the addendum; the evidence is §0.1 and the six validation files. The
finding is worth stating in its own right, because it is the clearest thing the
benchmark produced about how PMapper models escalation:

**PMapper reports a principal only where the principal can point the permission at
itself.** A user with `iam:AttachUserPolicy` can attach `AdministratorAccess` to
itself; a role with the same grant cannot, because the API targets users. A role with
`iam:AttachRolePolicy` can self-attach; a user with the same grant cannot. PMapper's
graph records exactly that distinction in its `is_admin` flag, and its output follows.

The scenario list did not make the distinction. It was generated from *declared IAM
state* — principal, permission, resource — which is the right source for an inventory
and is silent on whether the principal can reach what the permission empowers. Six of
its 86 rows asserted a path that does not close.

**This is the sharpest methodological lesson in the project, and it cuts against the
ground-truth process, not against either tool.** A Terraform-and-API-derived scenario
list is a list of grants, not a list of paths, and grading a path-finder against a
grant list will manufacture misses. Rubric §7 already names the fix and puts it out of
scope — an `iam:SimulatePrincipalPolicy` sweep as an independent oracle. This is the
concrete cost of not having run one.

The six principals are not harmless: each can make *another* principal
administrative, and the two users among them hold access keys and are usable start
points. What they cannot do is escalate themselves, which is what the rubric's D
definition and PMapper's model measure. Every validation file carries that caveat and
the post should too.

### 5.2 The four mechanisms PMapper genuinely misses

After the correction, four remain — and three are confirmed working paths:

- **`privesc13-AddUserToGroup`** (both rows) — validated by live exercise: the role
  added a zero-permission user to `privesc-sre-group` and that user immediately
  gained `iam:CreateUser` / `iam:AttachUserPolicy`. Membership restored. PMapper
  models group edges for permission resolution but does not surface `AddUserToGroup`
  as an escalation into an admin-carrying group. **Note this is the mirror of §5.1:
  here the group *is* reachable — the user adds itself — and PMapper still misses it.**
- **`fn3-exploitableConditionConstraint`** (both rows) — the pointed one. The
  condition is `DateGreaterThan aws:TokenIssueTime 2020-01-01`, i.e. always true, and
  AWS's own simulator allows `iam:CreatePolicyVersion` once the context key is
  supplied. **PMapper reports `fn2` (resource constraint) and `fn4` (NotAction) as
  administrative and drops only the condition-wrapped variant** — exactly the failure
  mode fn3 was built to expose.
- **`privesc17-EditExistingLambdaFunctionWithRole`** (both rows) — PMapper draws
  edges only to principals it deems administrative, and this target
  (`EC2-AutoRemediation-role-h3s42wj1`: EC2 read + `ec2:CreateTags` + logs) is not
  one. The miss is a consequence of the design, and the design is also what stopped
  it overstating the impact (§6.1).
- **`privesc21-PassExistingRoleToNewDataPipeline`** (both rows) — no Data Pipeline
  edge check. `scenarios.md` marks the target present **by inference** (Data Pipeline
  is closed to new customers; creation was never attempted), so the grade rests on
  unconfirmed ground truth and stays flagged.

cloudfox misses none of these outright; it binds every enabling permission to every
principal. It also connects none of them to a target.

### 5.3 The shape of the two tools is different, and the grades encode that

PMapper produced **zero P grades**. It has no partial output: a principal is on the
privesc list with a named target, or it is not. cloudfox produced **three D grades out
of 52** and 47 P's, because its surfaces are inventories — accurate, principal-bound,
exhaustive, and stopping one step short of a claim.

The three cloudfox D's show where that step gets taken anyway:

- `privesc-AssumeRole-ending--role` and `privesc-high-priv-service--role` —
  `iam-simulator` states `Appears to be an administrator` and `principals.csv` sets
  `IsAdminRole? = YES`. Principal plus resulting privilege, in the tool's own words.
- `privesc-AssumeRole-intermediate--role` — one row of `role-trusts-principals.csv`
  reads `ending-role | Trusted Principal = intermediate-role | IsAdmin? = YES`,
  putting principal, trust edge and administrative target on a single line. D on the
  elements, flagged `inferred` because the grade comes from joining two columns
  rather than from any escalation statement cloudfox makes.

One row later the same table gives `intermediate-role | Trusted Principal =
starting-role | IsAdmin? = No`, and cloudfox never joins them. **All three hops of the
AssumeRole chain are present in cloudfox's output as separate rows; the chain is
not.** §4.4 — hop 1 without the chain is P — so `privesc-AssumeRole-starting--role` is
P for cloudfox and D for PMapper, which prints both hops under one heading. That pair
of cells is the clearest statement in the matrix of what a path finder buys.

**Correction to a validation file.**
`analysis/validation/privesc-AssumeRole-starting--role.md` records that the chain's
individual `sts:AssumeRole` edges appear in cloudfox's `iam-simulator`. They do not:
`iam-simulator.csv` has zero rows for `starting-role` and `intermediate-role`, and the
edges are in `role-trusts-principals.csv`. The file's conclusion — cloudfox does not
stitch the chain — is unaffected. Noted here rather than edited into the validation
file, which is a record of what was run.

### 5.4 cloudfox renders conditions as a boolean, which erases the fn3/fp5 distinction

`permissions.csv` has a `Condition` column whose value is `Yes` or `No`. It does not
render the condition body. The exploitable fixture and its non-exploitable twin
therefore print identically:

```
fn3-exploitableConditionConstraint-user    Allow iam:CreatePolicyVersion on *   Condition=Yes
fp5-nonExploitableConditionConstraint-user Allow iam:CreatePolicyVersion on *   Condition=Yes
```

One is `DateGreaterThan aws:TokenIssueTime 2020-01-01` (always true, escalates); the
other is `DateLessThan` the same date (never true, inert). No reviewer can separate
them from this output. By contrast cloudfox *does* render the `Resource` column
verbatim, so the fn2/fp4 pair — `arn:aws:iam::*:policy/fn2-*` versus
`arn:aws:iam::aws:policy/fp4-*` — **is** separable from the same file. The tool
carries enough structure for one of the two constraint tests and not the other.

---

## 6. False positives

### 6.1 Denominators and outcomes

| Column | escalation paths reported | other assertions | FPs confirmed |
|---|---:|---|---:|
| PMapper — default | **0** | none — the run produced nothing | 0 (nothing to be wrong about) |
| PMapper — region-scoped | **32** | 17 principals asserted administrative; 8 `analysis` findings | **4** |
| cloudfox — own surfaces | **0** | 78 `iam-simulator` assertions; 3 `IsAdminRole? = YES`; 6008 permission grants; 44 role-trust edges; 1 root-trust | **0** |
| cloudfox — path column | 0 (N/A) | — | — |

Per §4.8, reported as **4 FPs found in a sample of 22 validated principal rows across
19 validation files** — never as a rate, because the population was not checked.

### 6.2 The four confirmed FPs — PMapper reasons past the compute layer

`privesc-ssmSendCommand` and `privesc-ssmStartSession`, both principals each. PMapper
asserts, on its primary surface and again in its `analysis` report at severity High:

```
user/privesc-ssmSendCommand-user can call ssm:SendCommand to access an EC2
   instance with access to role/privesc-high-priv-service-role
```

There is no such instance. Zero EC2 instances and zero SSM-managed nodes across all 17
enabled regions, from the direct per-service sweep in `account-baseline.md`. PMapper's
supporting finding gives away the inference — *"The following IAM Roles are attached
to at least one instance profile"* — it reasons from the **existence of an instance
profile** on the administrative role to the existence of an instance carrying it. The
instance profile is real; the instance is not.

The contrast with `privesc3-CreateEC2WithExistingInstanceProfile` is exact and is why
this is an FP rather than a modelling preference: privesc3 uses the *same* instance
profile and **is** a working path, because privesc3 holds `ec2:RunInstances` and
creates the instance it then uses. The SSM principals hold no `ec2:RunInstances` —
their grants are `ec2:DescribeInstances` plus the SSM actions — so they can only act
on an instance that is already there.

**What this is not.** Not a claim that PMapper is wrong about the permission, the
mechanism or the risk. The grant is real, the mechanism is a genuine escalation
primitive, and in an account with SSM-managed instances the path would work. It is a
false positive *about this account*: PMapper reasons over declared IAM state and does
not check whether the compute its path traverses exists. Worth stating as a design
boundary rather than a bug — and worth pairing with §5.1, where the same
declared-state-only reasoning produced the opposite error in the *ground truth*.

**Reachability caveat, disclosed.** The sweep proves the target is absent. It does not
prove the path would fail if an instance were launched; nobody attempted exploitation,
and `scenarios.md` "Known gaps" #4 already records that `target_absent` was verified
by resource-existence checks rather than by exploitation. The FP determination rests
on the absence of the traversed resource, which is sufficient for §3's "does not work"
**as the account stands**, and is stated on that basis.

### 6.3 Three candidates validated and cleared

- **`privesc17` overstated impact** — the sharpest pre-existing candidate, because
  the only reachable Lambda target grants EC2 read and tagging, not admin. **It did
  not materialise.** PMapper does not report privesc17 at all, and cloudfox lists
  `EC2-AutoRemediation` with `IsAdminRole? = No`. Both correct, by different routes.
- **`privesc-permissive-role-trust`** — trust policy names `:root`, role holds zero
  policies. cloudfox surfaces it in the root-trust *hygiene* table with
  `IsAdmin? = No`: both halves true, no escalation claimed.
- **`privesc-AssumeRole-start-user`** — inert, one access key, named in no trust
  policy. Neither tool presents it as a chain entry point.

None of the five `fp1`–`fp5` fixtures was reported by either tool, so none became a
candidate and none was owed a validation file under §6. All score CS.

---

## 7. Crash tally — rubric §4.7

§4.7 requires crash-Ms tallied separately from detection-Ms, because *"a tool that
cannot run is a maintenance finding; a tool that runs and misses is a detection
finding."*

| Column | crash-M rows | detection-M rows | §4.7 events | scope |
|---|---:|---:|---:|---|
| PMapper — default | **86** | **0** | 1 | whole run: `graph create` died on the first of nine edge checks; no principal was ever evaluated |
| PMapper — region-scoped | 0 | **20** | 0 | zero skipped principals; `graph create` stderr is 0 bytes. 20 = 8 detection-bucket Ms + 12 target-absent Ms; the detection headline in §3 uses the 8 |
| cloudfox — own surfaces | **2** | 0 | **3** | `iam-simulator` only; three principals throttled, but one of the three is now a no-path row scoring CS, so the third event costs no grade (§2.4) |
| cloudfox — path column | 0 | 0 | 0 | N/A throughout |

The two crashes are not the same kind of event and should not be pooled:

- **PMapper's is structural.** One unreachable regional endpoint, one `except` clause
  narrowed to `ClientError`, and the whole graph is lost. The line is unchanged on
  upstream `master`, last touched 2022-02-03. Whether *this particular timeout*
  recurs is unknown — a single observation, recorded as one — but the defect is not
  environmental, and it sits on the only code path that builds the graph.
- **cloudfox's is transient and nondeterministic.** API throttling. The admin run
  lost three principals; the `SecurityAudit` run lost one, and the overlap between the
  two sets is **empty** — itself the evidence that this is noise rather than a
  property of either context. What is *not* transient is that the failure is
  unreportable from the output surface: only the error log knows.

A third, milder maintenance finding costs no grades: PMapper 1.1.5 does not run on any
Python this machine shipped with. `from collections import Mapping` was removed in
Python 3.10; `setup.py` still declares `python_requires='>=3.5, <4'`, so `pip`
installs cheerfully on 3.11 and the tool dies at import. The real ceiling is 3.9,
which Homebrew has deprecated with a disable date of 2026-10-15. Full record in
`analysis/tool-install.md`.

---

## 8. The limited-privilege delta — rubric §5.1

Not graded per scenario, by rubric. Reported qualitatively. The limited principal is
`user/benchmark-securityaudit`, purpose-made, holding only
`arn:aws:iam::aws:policy/SecurityAudit`.

**Neither tool showed a materially reduced output surface.** Both results are stronger
than "similar":

- **PMapper** — `04-query-preset-privesc.txt` is **byte-identical** between the
  `admin` and `SecurityAudit` contexts. Same 32 paths, same 17 administrative
  principals, same ordering, same 10520 bytes. `06-analysis-text.txt` differs in
  exactly one line: the timestamp. The graph grew by the one new principal and four
  inbound edges, none of which creates a path.
- **cloudfox** — all 94 principals present in both runs are field-for-field
  identical, `IsAdminRole?` included. `permissions.json` compares equal once the new
  principal's own 1031 grant rows are removed. Role-trusts, resource-trusts,
  workloads, lambda, sns and tags are all identical. `iam-simulator` differs by four
  rows: three gained for the new principal, one lost to throttling.

`SecurityAudit` simply grants enough IAM read access that neither tool notices. Rubric
§5.1 anticipated exactly this framing and it should be kept: *"the result is not
'tools degrade by X under low privilege', it is 'tools degrade this way under this
policy.'"*

**The interesting delta is in the error logs, not the output.** cloudfox's
`Glue: ListDevEndpoints` fails 17 times under admin with `InternalFailure` — AWS's
answer for a retired feature, and the evidence `scenarios.md` cites for
`privesc18`/`privesc19` being target-absent. Under `SecurityAudit` the same call fails
17 times with `AccessDeniedException` instead. **The report looks the same either way,
and only the admin run's version of it is informative.** An auditor holding
`SecurityAudit` cannot distinguish *"this capability no longer exists"* from *"I was
not allowed to look"*, and both render as an absent section. That is a real limitation
of running these tools at auditor privilege and it is invisible unless you read the
error log — which is also where cloudfox hides its skipped principals (§7).

---

## 9. Every cell flagged as inferred

**41 of 344 cells**, down from 51 before the addendum: the six asymmetry rows and the
four SSM rows now have validation files. Per the CLAUDE.md constraint that inference
is stated out loud rather than asserted. Per-cell text in `grades.csv`.

| # cells | Column | Reason |
|---:|---|---|
| 16 | PMapper region-scoped | **Admin-verdict form** (§2.2). Graded D from `<principal> is an administrative principal`, which names the principal and the resulting privilege but not the enabling permission. Rows: `privesc1` ×2, `privesc7--user`, `privesc8--user`, `privesc9--role`, `privesc10--user`, `privesc11--user`, `privesc12--role`, `fn2` ×2, `fn4` ×2, `privesc-sre` ×2, `privesc-AssumeRole-ending--role`, `privesc-high-priv-service--role`. |
| 2 | PMapper region-scoped | **`privesc14` target divergence.** PMapper reaches `role/fn2-exploitableResourceConstraint-role`, not `scenarios.md`'s intended `privesc-sre-role`. §4.3 scores a divergent-but-working target as D; the divergence was not separately validated. |
| 2 | PMapper region-scoped | **`privesc21`** — grade rests on a `target_absent` value `scenarios.md` itself marks as inferred. |
| 10 | PMapper region-scoped | **`fp1`–`fp5`.** The absence of an escalation claim is read directly; the claim that silence is *correct* rests on `scenarios.md`, since these five fixtures have no validation file. |
| 10 | cloudfox own surfaces | Same five fixtures, same reason. |
| 1 | cloudfox own surfaces | **`privesc-AssumeRole-intermediate--role` = D** from joining two columns of one `role-trusts-principals.csv` row (§5.3). |

Nothing in the `cloudfox — path column` is inferred: `Skipping, no pmapper data`
appears verbatim in committed output, and the §4.9 disclaimer is quoted and sourced.

---

## 10. Pre-registered predictions — status

Rubric §8 asks for these to be compared and the misses reported honestly. Status only;
the argument belongs in the post.

| # | Prediction | Status |
|---|---|---|
| 1 | Both tools D on ≥ four fifths of canonical mechanisms | **False, but much closer for PMapper after the correction.** Threshold is 19 of 23 canonical mechanisms. PMapper region-scoped: **20 of 23 — it clears the bar.** PMapper default: 0. cloudfox: 0 D, because §4.9 makes its path column N/A and its own surfaces stop at P. The prediction fails on "**both** tools", not on PMapper. It did not anticipate a tool graded on a partial-credit surface, and it did not anticipate a crash. |
| 2 | Limited context materially reduces both tools' output surface | **False**, and not marginally: PMapper's privesc output is byte-identical across contexts and cloudfox's principal and permission data compares equal. §8. |
| 3 | PMapper produces more P than D on multi-hop chains at default settings | **Not testable as stated, and false in spirit.** At default settings PMapper produced no output at all. In the region-scoped run it produced **zero P grades of any kind** — its output has no partial form — and graded D on both chain hops, printing the intermediate hop of the two-hop path explicitly. |
| 4 | At least one FP appears across the two tools, within the validated sample | **True.** Four, all PMapper, all in the validated sample: `privesc-ssmSendCommand` and `privesc-ssmStartSession`, both principals each (§6.2). cloudfox produced none. |
| 5 | Neither tool detects the OIDC / web-identity scenario | **Out of scope.** Phase 5. `lab-oidc/` contains only its README and there is no OIDC or SAML provider in the account, confirmed in all four run-metadata files. |

Prediction 1 is the one to be careful with in the post. It was written against a
scenario list that turned out to overcount paths by six rows, and PMapper crosses the
threshold only *because* the ground truth was corrected. Report both numbers and the
reason the denominator moved.

---

## 11. Open items

Carried forward. Items 1–3 of the previous list are closed by the addendum.

1. ~~Rubric §9 amendment for the FP-fixture grade.~~ **Done** — §9, 2026-08-31,
   defines **CS**.
2. ~~Validate the six asymmetry rows.~~ **Done** — six validation files; rows
   reclassified `non-path` (§0.1).
3. ~~Validate the four SSM FP candidates.~~ **Done** — four validation files; regraded
   D → FP (§0.2, §6.2).
4. **The §6 sampling requirement is met on one reading and not the other.** §6 asks
   for ≥3 scenarios *"graded M by all tools"*. The three files written for that slot —
   `privesc2`, `privesc13`, `fn3` — record cloudfox as M because cloudfox reports no
   *path*; under §4.1 its principal-bound permission dump earns **P** on all three.
   Under the final grades **no row is M for every column**: the two cloudfox Ms are
   §4.7 throttles on rows PMapper detects. Either read §6's requirement as "M by all
   tools on the escalation question" — which is how the files were written, and is
   defensible — or add validations. State the choice in the post.
5. **`privesc21-PassExistingRoleToNewDataPipeline` ground truth.** `target_absent` is
   `no` by inference; Data Pipeline is closed to new customers and creation was never
   attempted. Four cells depend on it, and it is now one of only four PMapper misses,
   so it carries more weight than it did.
6. **`analysis/account-baseline.md` needs a line for `user/benchmark-securityaudit`.**
   Flagged in the cloudfox `securityaudit` run metadata; the account gained a 95th
   principal after the baseline was written.
7. **No `iam:SimulatePrincipalPolicy` sweep was run**, per rubric §7 — and §5.1 is now
   the concrete cost of that. Without it the scenario list is an inventory of
   *declared* grants, not an enumeration of *reachable* paths, which is precisely the
   error the six-row correction fixed by hand. §6.1's late-additions bucket is empty,
   which is a fact about the method, not about the account.

---

## 12. Provenance

| | |
|---|---|
| Rubric | `analysis/rubric.md`, frozen before Phase 2; §9 amended twice — 2026-08-31 (redaction scope) and 2026-08-31 (the **CS** grade) |
| Ground truth | `analysis/scenarios.md` — 46 mechanisms / 86 principal rows, generated from the IAM API; six rows reclassified `non-path` in the addendum |
| Lab | `BishopFox/iam-vulnerable` @ `0f298666f9b7cfa01488b86912afdb211773188a`, applied 2026-08-31 `us-east-1` |
| cloudfox | `2.0.5`, release binary, no dependency work |
| PMapper | `1.1.5` (tag `d5136ff`; `master` HEAD dated 2022-02-03), Python 3.9.25 |
| Runs graded | `cloudfox/admin-default-2026-08-31`, `pmapper/admin-default-2026-08-31`, `pmapper/admin-flagged-2026-08-31` |
| Runs read, not graded | `cloudfox/securityaudit-default-2026-08-31`, `pmapper/securityaudit-default-2026-08-31` |
| Validation | 19 files covering 22 principal rows, `analysis/validation/` |
| Cells | 344 in `analysis/grades.csv`; 41 flagged inferred |
| Raw output | unedited modulo `redact.sh`, one published one-way substitution, committed alongside its output |

Written by hand from `grades.csv`. No generator.
