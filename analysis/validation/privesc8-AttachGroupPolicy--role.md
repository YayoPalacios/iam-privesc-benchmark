# `privesc8-AttachGroupPolicy--role` — not a self-escalation path; scenario-list error

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
  `privesc-sre-group` (`iam:*`,`ec2:*`,`s3:*`). PMapper reports the `--user` row and
  not this one. Can the **role** wield the privilege it can create?

## Evidence

### 1. The role holds exactly one grant

`csv/permissions.csv`, `grep ',privesc8-AttachGroupPolicy-role,'` — **1 row**:

```
Allow  iam:AttachGroupPolicy  on *   Condition=No
```

### 2. A role cannot be a member of an IAM group

`nodes.json`: `"group_memberships": []`, `access_keys: 0`, `is_admin: false`.

IAM groups contain **users only** — there is no API to add a role to a group, and
PMapper's graph reflects it: of the 94 nodes, every non-empty `group_memberships`
belongs to a user. The account's three groups are:

```json
{ "arn": "…:group/privesc-sre-group",                 "attached_policies": ["privesc-sre-admin-policy"] }
{ "arn": "…:group/privesc8-AttachGroupPolicy-group",  "attached_policies": [] }
{ "arn": "…:group/privesc11-PutGroupPolicy-group",    "attached_policies": [] }
```

The role belongs to none of them, and could not be made to.

### 3. No role in the account trusts this principal

Swept every `trust_policy` in PMapper's 94-node graph. The complete set of AWS
principals named in any role trust policy in this account is:

```
40 x  arn:aws:iam::000000000000:user/iamadmin
 1 x  arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role
 1 x  arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role
 1 x  arn:aws:iam::000000000000:user/privesc-sre-user
 1 x  arn:aws:iam::000000000000:root
      (+ 16 AWS service principals)
```

This principal appears in none of them. The `:root` entry is
`role/privesc-permissive-role-trust`, which delegates authorisation to identity
policies — assuming it still requires `sts:AssumeRole` in the caller's own policy,
which this principal does not have — and that role holds zero policies anyway
(`privesc-permissive-role-trust--role.md`).

## Verdict

**Not a self-escalation path.** The role can attach `AdministratorAccess` to any
group in the account — including `privesc-sre-group` — and cannot join a group, so
the privilege lands only on that group's existing user members. It has no way to
authenticate as any of them. Reclassified `privesc` → `non-path` under rubric §6.

### The contrast that explains the asymmetry

`user/privesc8-AttachGroupPolicy-user` holds the same single grant and is a member of
`privesc8-AttachGroupPolicy-group` — a group that carries **zero** policies today.
Attaching `AdministratorAccess` to that group makes the user admin immediately, which
is why PMapper marks it `is_admin: true`. The group's emptiness is the point: the
escalation is entirely the user's own.

### Caveat the writeup must carry

This principal **can still grant administrative privilege to another principal in the
account.** That is a serious account-level capability and a real audit finding. It is
just not *privilege escalation of this principal*, which is what this benchmark, the
rubric's D definition ("the reachable target or resulting privilege") and PMapper's
model all measure. A threat model in which the attacker also controls, or can later
obtain, a credential for the empowered principal would score this differently. That
threat model is out of scope here, and the exclusion rests on that basis — not on a
claim that the grant is harmless.

## Tool behaviour

- **PMapper (admin-flagged):** does not report it. **Correct.**
- **PMapper (admin-default):** crashed; reported nothing about anything.
- **cloudfox (admin-default):** binds `iam:AttachGroupPolicy` to the principal in
  `permissions.csv`; makes no escalation claim. Correct on both counts.
