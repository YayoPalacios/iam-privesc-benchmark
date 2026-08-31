# `privesc-ssmStartSession--user` — **confirmed false positive** (PMapper, region-scoped run)

- **Class:** `privesc`, `target_absent = yes` · **Category:** rubric §6 FP candidate
  → **confirmed FP under §4.8 / §3**
- **Date validated:** 2026-08-31 (Phase-4 addendum) · **Context:** `admin`
- **Evidence source: the account-wide resource sweep already recorded in
  `analysis/account-baseline.md`, plus committed tool output.** No new AWS calls
  were made in this pass. The sweep itself was a live, per-service, per-region set
  of API calls made on 2026-08-31 and is the primary evidence here.
- **Claim under test:** PMapper's privesc preset asserts that this principal reaches
  the administrative role `privesc-high-priv-service-role` **via an EC2 instance**.
  The claim is tested against whether such an instance exists.

## 1. What PMapper asserts

`raw-output/pmapper/admin-flagged-2026-08-31/output/04-query-preset-privesc.txt`,
verbatim:

```
user/privesc-ssmStartSession-user can escalate privileges by accessing the administrative principal role/privesc-high-priv-service-role:
   user/privesc-ssmStartSession-user can call ssm:StartSession to access an EC2 instance with access to role/privesc-high-priv-service-role
```

The same assertion is repeated in PMapper's `analysis` report
(`06-analysis-text.txt`, *IAM Principals Can Escalate Privileges*, severity High),
so it is on PMapper's primary output surface twice, not buried.

PMapper also emits a supporting finding, *IAM Role With Unsafe SSM Permissions*:

> The following IAM Roles are attached to at least one instance profile and have
> permissions with the aforementioned risk:
> * `role/privesc-high-priv-service-role`

That is the inference PMapper is making: an **instance profile** exists for the
administrative role, therefore an instance carrying it is assumed to exist.

## 2. The instance does not exist

`analysis/account-baseline.md`, from a direct per-service sweep of **all 17 enabled
regions** (Lambda, EventBridge, SNS, EC2 instances, SSM-managed instances,
CloudFormation, Glue, SageMaker, EC2 key pairs):

> **Nothing else was found.** Zero EC2 instances, zero SSM-managed instances, zero
> SageMaker notebooks, zero Glue jobs, zero EventBridge rules on any bus, **zero
> CloudFormation stacks and zero S3 buckets**, in any of the 17 enabled regions.

and, in the same file's per-scenario confirmation list:

> - `privesc-ssmSendCommand` / `privesc-ssmStartSession` — no SSM-managed nodes anywhere

Three EC2 key pairs exist (`temp`, `lab-new-key`, `flaws-lab`) and the baseline
records **"no instances"** against every one. `scenarios.md` marks this mechanism
`target_absent = yes` on exactly this evidence.

## 3. Why the instance profile is not enough

`role/privesc-high-priv-service-role` genuinely has an instance profile
(`privesc-high-priv-service-profile`), confirmed in `scenarios.md` under
`privesc3`. An instance profile is a *binding object*: it makes the role
**available** to be attached to an instance. It does not create an instance, and
`ssm:StartSession` needs a live, SSM-registered target to act on. With zero managed nodes the
API call has nothing to address.

Note the contrast with `privesc3-CreateEC2WithExistingInstanceProfile`, which uses
the same instance profile and **is** a working path — because privesc3 holds
`ec2:RunInstances` and creates the instance it then uses. This principal holds no
`ec2:RunInstances`; its grants are `ec2:DescribeInstances` plus the SSM StartSession actions
(`csv/permissions.csv`). It can only act on an instance that is already there.

## Verdict

**Confirmed false positive.** PMapper reports a path whose middle hop — an EC2
instance carrying the administrative role — does not exist in this account, in any
region. Rubric §3: *"FP — Tool reports a path that manual validation shows does not
work."* Rubric §4.8 also reaches it from the other direction: the path is *"reported
as unconditional"* when it is in fact conditional on a resource that is absent.

**Regraded D → FP.** The row sits in the `target_absent` bucket and was already
excluded from every detection count, so the regrade moves no headline detection
number; it moves PMapper's false-positive count from 0 to non-zero.

### What this is not

This is **not** a claim that PMapper is wrong about the permission, the mechanism, or
the risk. The grant is real, the mechanism is a genuine escalation primitive, and in
an account with SSM-managed instances the path would work. It is a false positive
*about this account* — PMapper reasons over declared IAM state and does not check
whether the compute its path traverses exists. That is a design boundary worth
stating plainly rather than a bug.

### Reachability caveat, disclosed

The sweep proves the *target* is absent. It does not prove the path would fail if an
instance were launched — nobody attempted exploitation, and rubric §"Known gaps" #4
already records that `target_absent` was verified by resource-existence checks rather
than by exploitation. The FP determination rests on the absence of the traversed
resource, which is sufficient for §3's "does not work" **as the account stands**, and
is stated on that basis.

## Tool behaviour

- **PMapper (admin-flagged):** **FP.** Asserts the path on its primary surface twice.
- **PMapper (admin-default):** crashed; asserted nothing. An FP denominator of 0
  because a tool produced no output is not a clean sheet — see `matrix.md` §6.
- **cloudfox (admin-default):** **no FP.** Binds `ssm:StartSession` to the principal in
  `permissions.csv` and reports `can ssm:StartSession on *` in `iam-simulator`, both true
  statements about the grant, and makes no claim about reaching admin. Its path
  column reads `Skipping, no pmapper data` (N/A, §4.9).
