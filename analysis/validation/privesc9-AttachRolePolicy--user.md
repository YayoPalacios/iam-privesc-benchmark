# `privesc9-AttachRolePolicy--user` — not a self-escalation path; scenario-list error

- **Class:** `privesc` → **corrected to `non-path`** · **Category:** rubric §6
  scenario-list correction (an M that turns out not to be a real path)
- **Date validated:** 2026-08-31 (Phase-4 addendum) · **Context:** `admin`
- **Evidence source: committed raw output, not a live AWS session.** Every fact
  below is read from artifacts already in this repository — PMapper's archived
  graph (`raw-output/pmapper/admin-flagged-2026-08-31/pmapper-graph/000000000000/graph/`)
  and cloudfox's `permissions.csv` / `access-keys.csv`
  (`raw-output/cloudfox/admin-default-2026-08-31/…/csv/`). No new AWS calls were
  made.
- **Claim under test:** `scenarios.md` lists this row as a working escalation to
  "any IAM principal -> account admin". PMapper reports the `--role` row of this
  mechanism and not this one. The question is whether the **user** can come to wield
  the privilege it is able to create.

## Evidence

### 1. The user holds exactly one grant

`csv/permissions.csv`, `grep ',privesc9-AttachRolePolicy-user,'` — **1 row**:

```
Allow  iam:AttachRolePolicy  on *   Condition=No
```

No `sts:AssumeRole`. No `iam:UpdateAssumeRolePolicy` (which would let it rewrite a
trust policy to name itself — that is `privesc14`, a different principal). No
`iam:PassRole` and no service-side create action.

### 2. The user cannot be the target of its own permission

`nodes.json`:

```json
{ "arn": "…:user/privesc9-AttachRolePolicy-user",
  "access_keys": 1, "active_password": false,
  "group_memberships": [], "is_admin": false, "trust_policy": null }
```

`iam:AttachRolePolicy` can only target an IAM **role**. This principal is a user, so
it cannot attach the policy to itself, and `is_admin: false` is PMapper's own
conclusion from the same fact.

### 3. No role in the account trusts this principal, and it cannot assume one

Swept every `trust_policy` in PMapper's 94-node graph. The complete set of AWS
principals named in any role trust policy in this account:

```
40 x  arn:aws:iam::000000000000:user/iamadmin
 1 x  arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role
 1 x  arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role
 1 x  arn:aws:iam::000000000000:user/privesc-sre-user
 1 x  arn:aws:iam::000000000000:root
      (+ 16 AWS service principals)
```

This user appears in none of them. Two escape routes were checked and both are
closed:

- **The `:root` trust.** `role/privesc-permissive-role-trust` trusts
  `arn:aws:iam::000000000000:root`, which delegates authorisation to identity
  policies — so assuming it still requires `sts:AssumeRole` in the caller's own
  policy. This user holds one grant and it is not that. (And the role carries zero
  policies regardless — `privesc-permissive-role-trust--role.md`.)
- **Empowering a service-trusted role.** 16 roles are trusted by AWS services, so a
  role could be made administrative and then driven via its service. Reaching that
  requires the service-side action plus `iam:PassRole` — e.g. `lambda:CreateFunction`.
  This user holds neither.

## Verdict

**Not a self-escalation path.** The user can attach `AdministratorAccess` to any
role in the account and cannot assume any role: it is named in no trust policy, holds
no `sts:AssumeRole`, cannot rewrite a trust policy, and cannot drive a
service-trusted role for want of `iam:PassRole` and any service create action.

**This is a `scenarios.md` error, not a PMapper miss.** Rubric §6. Row reclassified
`privesc` → `non-path` and removed from the detection denominator.

### The contrast that explains the asymmetry

`role/privesc9-AttachRolePolicy-role` holds the **same single grant** and PMapper
marks it `is_admin: true`, because a role can attach `AdministratorAccess` to
itself. The mechanism is identical; only self-targetability differs. PMapper's split
is correct behaviour, and it is the mirror image of the `privesc7`/`privesc10` case
where the user is the one that can self-target.

### Caveat the writeup must carry

This principal **can still grant administrative privilege to another principal in the
account** — and unlike the role-side cases it holds an access key, so it is directly
usable as an attacker start point. What it cannot do is turn that grant into
privilege for itself. The exclusion is about *self*-escalation, which is what the
rubric's D definition and PMapper's model measure; it is not a claim that the grant
is harmless. A threat model in which the attacker can also reach the empowered role
by some other route would score this differently.

## Tool behaviour

- **PMapper (admin-flagged):** does not report it. **Correct.**
- **PMapper (admin-default):** crashed; reported nothing about anything.
- **cloudfox (admin-default):** binds `iam:AttachRolePolicy` to the principal in
  `permissions.csv`; makes no escalation claim. Correct on both counts.
