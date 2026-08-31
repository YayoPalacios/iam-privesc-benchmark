# `privesc10-PutUserPolicy--role` — not a self-escalation path; scenario-list error

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
  "any IAM principal -> account admin". PMapper reports the `--user` row and not this
  one. Can the **role** wield the privilege it can create?

## Evidence

### 1. The role holds exactly one grant

`csv/permissions.csv`, `grep ',privesc10-PutUserPolicy-role,'` — **1 row**:

```
Allow  iam:PutUserPolicy  on *   Condition=No
```

No `sts:AssumeRole`, no `iam:CreateAccessKey`, no `iam:CreateLoginProfile`, no
`iam:UpdateLoginProfile`.

### 2. The role is not a user and cannot hold a user credential

`nodes.json`: `access_keys: 0`, `active_password: false`, `group_memberships: []`,
`is_admin: false`, trust policy names `user/iamadmin` only.

`iam:PutUserPolicy` writes an inline policy onto an IAM **user**. A role cannot be
its own target. cloudfox's `access-keys.csv` keys every one of its 43 rows by
`User Name`; roles hold no long-lived credentials.

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

**Not a self-escalation path.** Same shape as `privesc7-AttachUserPolicy--role`:
the role can write `Allow *:*` inline onto any user and has no route to
authenticating as one. Reclassified `privesc` → `non-path` under rubric §6; removed
from the detection denominator.

### The contrast that explains the asymmetry

`user/privesc10-PutUserPolicy-user` holds the same single grant and PMapper marks it
`is_admin: true` — a user can write an inline admin policy onto itself. Only
self-targetability differs.

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
- **cloudfox (admin-default):** this principal is one of the three whose
  `iam-simulator` admin check was abandoned after 3 throttling retries
  (`cloudfox-logs/cloudfox-error.log`, `Failed admin check`). The skip is real and
  stays in the §4.7 maintenance tally, but with the row out of the detection bucket
  it no longer costs a detection grade. `permissions.csv` bound the grant correctly.
