# `privesc12-PutRolePolicy--user` — not a self-escalation path; scenario-list error

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
  "any IAM principal -> account admin". PMapper reports the `--role` row and not this
  one. Can the **user** wield the privilege it can create?

## Evidence

### 1. The user holds exactly one grant

`csv/permissions.csv`, `grep ',privesc12-PutRolePolicy-user,'` — **1 row**:

```
Allow  iam:PutRolePolicy  on *   Condition=No
```

No `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy`, no `iam:PassRole`, no
service-side create action.

### 2. The user cannot be the target of its own permission

`nodes.json`: `access_keys: 1`, `group_memberships: []`, `is_admin: false`,
`trust_policy: null`. `iam:PutRolePolicy` writes an inline policy onto an IAM
**role**; a user cannot be its own target.

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

**Not a self-escalation path.** Same shape as `privesc9-AttachRolePolicy--user`:
the user can write `Allow *:*` inline onto any role and has no route to assuming
one. Reclassified `privesc` → `non-path` under rubric §6; removed from the detection
denominator.

### The contrast that explains the asymmetry

`role/privesc12-PutRolePolicy-role` holds the same single grant and PMapper marks it
`is_admin: true` — a role can write an inline admin policy onto itself.

### Caveat the writeup must carry

As with `privesc9`: the grant is real, the principal holds an access key and is a
usable start point, and it can make another principal administrative. It cannot make
*itself* administrative, and that is what is being measured here.

## Tool behaviour

- **PMapper (admin-flagged):** does not report it. **Correct.**
- **PMapper (admin-default):** crashed; reported nothing about anything.
- **cloudfox (admin-default):** binds `iam:PutRolePolicy` to the principal in
  `permissions.csv`; makes no escalation claim. Correct on both counts.
