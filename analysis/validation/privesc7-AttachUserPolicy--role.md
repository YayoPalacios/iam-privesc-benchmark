# `privesc7-AttachUserPolicy--role` — not a self-escalation path; scenario-list error

- **Class:** `privesc` → **corrected to `non-path`** · **Category:** rubric §6
  scenario-list correction (an M that turns out not to be a real path)
- **Date validated:** 2026-08-31 (Phase-4 addendum) · **Context:** `admin`
- **Evidence source: committed raw output, not a live AWS session.** Every fact
  below is read from artifacts already in this repository — PMapper's archived
  graph (`raw-output/pmapper/admin-flagged-2026-08-31/pmapper-graph/000000000000/graph/`)
  and cloudfox's `permissions.csv` / `access-keys.csv`
  (`raw-output/cloudfox/admin-default-2026-08-31/…/csv/`). No new AWS calls were
  made. Where a fact could only come from a live call it is marked as not checked.
- **Claim under test:** `scenarios.md` lists this row as a working escalation to
  "any IAM principal -> account admin". PMapper reports the `--user` row of this
  mechanism and not this one. The question is whether the **role** can come to wield
  the privilege it is able to create.

## Evidence

### 1. The role holds exactly one grant

`csv/permissions.csv`, `grep ',privesc7-AttachUserPolicy-role,'` — **1 row**:

```
Allow  iam:AttachUserPolicy  on *   Condition=No
```

No `sts:AssumeRole`. No `iam:CreateAccessKey`, `iam:CreateLoginProfile` or
`iam:UpdateLoginProfile`. Nothing that mints or takes over a credential.

### 2. The role is not a user and cannot hold a user credential

From `nodes.json`:

```json
{ "arn": "…:role/privesc7-AttachUserPolicy-role",
  "access_keys": 0, "active_password": false,
  "group_memberships": [], "is_admin": false,
  "trust_policy": { "Principal": { "AWS": "…:user/iamadmin" } } }
```

`iam:AttachUserPolicy` can only target an IAM **user**. This principal is a role, so
it cannot attach the policy to itself. cloudfox's `access-keys.csv` has a single
principal column, `User Name`, and all 43 rows are users — long-lived access keys
are a user-only construct in IAM, and `nodes.json` records `access_keys: 0` here.

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
user in the account, and it has no way whatsoever to authenticate as that user: it
cannot mint the user a key, cannot set the user a console password, and cannot assume
anything. The privilege it creates is unreachable by it.

**This is a `scenarios.md` error, not a PMapper miss.** Rubric §6: *"A M that turns
out not to be a real path is a scenario-list error, not a tool miss. Fix the list and
note the correction."* Row reclassified `privesc` → `non-path` and removed from the
detection denominator.

### The contrast that explains the asymmetry

`user/privesc7-AttachUserPolicy-user` holds the **same single grant** and PMapper
marks it `is_admin: true`, because a user can attach `AdministratorAccess` to
itself. The mechanism is identical; only the self-targetability differs. PMapper's
split is correct behaviour, not a gap.

### Caveat the writeup must carry

This principal **can still grant administrative privilege to another principal in the
account.** That is a serious account-level capability and a real audit finding. It is
just not *privilege escalation of this principal*, which is what this benchmark, the
rubric's D definition ("the reachable target or resulting privilege") and PMapper's
model all measure. A threat model in which the attacker also controls, or can later
obtain, a user credential would score this differently. That threat model is out of
scope here and the exclusion is on that basis, not on a claim that the grant is
harmless.

## Tool behaviour

- **PMapper (admin-flagged):** does not report it. **Correct.**
- **PMapper (admin-default):** crashed; reported nothing about anything.
- **cloudfox (admin-default):** binds `iam:AttachUserPolicy` to the principal in
  `permissions.csv`; makes no escalation claim. Correct on both counts.
