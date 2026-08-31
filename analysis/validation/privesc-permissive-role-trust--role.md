# `privesc-permissive-role-trust--role` — FP candidate (permissive trust, empty grant)

- **Class:** `tool-test-FP` · **Category:** false-positive candidate (rubric §6, §4.8)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the role's trust policy names `:root`, so any principal in
  the account can assume it — but the role holds **zero** attached and **zero**
  inline policies, so assuming it grants nothing. Reporting it as an escalation
  path (a route to added privilege) would be an overstated-impact FP under §4.8.

## Commands and outcomes

Account ID redacted to `000000000000`.

### 1. Trust is `:root`; policy set is empty

```
$ aws iam get-role --role-name privesc-permissive-role-trust --profile personal \
    --query 'Role.AssumeRolePolicyDocument'
{ "Version":"2012-10-17","Statement":[{"Effect":"Allow",
  "Principal":{"AWS":"arn:aws:iam::000000000000:root"},"Action":"sts:AssumeRole"}] }

$ aws iam list-attached-role-policies --role-name privesc-permissive-role-trust --profile personal
{ "AttachedPolicies": [] }
$ aws iam list-role-policies --role-name privesc-permissive-role-trust --profile personal
{ "PolicyNames": [] }
```

### 2. Assume it (allowed, via `:root`) and confirm it can do nothing

```
$ aws sts assume-role \
    --role-arn arn:aws:iam::000000000000:role/privesc-permissive-role-trust \
    --role-session-name fp-validate --profile personal
=> assumed OK

# with the assumed-role credentials:
$ aws sts get-caller-identity --query Arn
arn:aws:sts::000000000000:assumed-role/privesc-permissive-role-trust/fp-validate

$ aws iam list-users --max-items 1
An error occurred (AccessDenied) ... not authorized to perform: iam:ListUsers ...
  because no identity-based policy allows the iam:ListUsers action

$ aws s3api list-buckets
An error occurred (AccessDenied) ... not authorized to perform: s3:ListAllMyBuckets
  because no identity-based policy allows the s3:ListAllMyBuckets action
```

## Verdict

**Confirmed: permissive trust, empty grant.** The role is assumable by anyone in
the account, but once assumed it authorises nothing — every privileged call is
`AccessDenied` with "no identity-based policy allows" the action. Assuming it is a
lateral no-op, not an escalation.

## Tool behaviour (for the Phase-4 FP tally)

- **PMapper (admin-flagged):** does **not** report this role (absent from
  `query`/`analysis`). It is correctly treated as a non-admin, non-escalating node.
- **cloudfox (admin-default):** surfaces it in
  `role-trusts-principals-root-trusts-without-external-id` — a **trust-hygiene**
  table — with the column **`IsAdmin? = No`**. It is **absent** from
  `iam-simulator`.

**The FP candidate does not materialise.** cloudfox's statement is accurate on
both counts: the role *does* trust `:root` (a real, reportable loose-trust
observation) and cloudfox does *not* claim it yields admin — it explicitly marks
`IsAdmin? No`. That is a hygiene finding about the trust policy, not an
overstated escalation path, so it is not an FP under §4.8. Recorded as a cleared
candidate.
