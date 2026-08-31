# `privesc-AssumeRole-start--user` — FP candidate (inert principal)

- **Class:** `inert` · **Category:** false-positive candidate (rubric §6, every FP candidate)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the user has an access key but **zero** permissions and is
  named in **no** trust policy, so it cannot reach `privesc-AssumeRole-starting-role`
  (which trusts `user/iamadmin`, not this user). A tool reporting this user as a
  chain entry point would be a false positive.

## Commands and outcomes

Account ID redacted to `000000000000`; access-key IDs masked.

### 1. The user holds no identity policy and no group

```
$ aws iam list-attached-user-policies --user-name privesc-AssumeRole-start-user --profile personal
{ "AttachedPolicies": [] }
$ aws iam list-user-policies --user-name privesc-AssumeRole-start-user --profile personal
{ "PolicyNames": [] }
$ aws iam list-groups-for-user --user-name privesc-AssumeRole-start-user --profile personal
{ "Groups": [] }
$ aws iam list-access-keys --user-name privesc-AssumeRole-start-user --profile personal --query 'AccessKeyMetadata[].Status'
[ "Active" ]        # one active key — it is a usable start point, but grants nothing
```

### 2. The user is named in no role trust policy

Searched every `AssumeRolePolicyDocument` in `get-account-authorization-details`:

```
roles whose trust policy names privesc-AssumeRole-start-user: []
```

For contrast, hop 1 of the chain trusts iamadmin, not this user:

```
$ aws iam get-role --role-name privesc-AssumeRole-starting-role --profile personal \
    --query 'Role.AssumeRolePolicyDocument.Statement[].Principal'
[ { "AWS": "arn:aws:iam::000000000000:user/iamadmin" } ]
```

### 3. AWS's own evaluator: everything is implicitDeny

```
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:user/privesc-AssumeRole-start-user \
    --action-names sts:AssumeRole \
    --resource-arns \
      arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role \
      arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role \
      arn:aws:iam::000000000000:role/privesc-AssumeRole-ending-role
=> sts:AssumeRole : implicitDeny

$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:user/privesc-AssumeRole-start-user \
    --action-names iam:CreateAccessKey iam:AttachUserPolicy iam:PutUserPolicy sts:AssumeRole
=> iam:CreateAccessKey  : implicitDeny
   iam:AttachUserPolicy : implicitDeny
   iam:PutUserPolicy    : implicitDeny
   sts:AssumeRole       : implicitDeny
```

## Verdict

**Confirmed inert.** The user has no identity-based permission, belongs to no
group, and is named in no trust policy; AWS's policy simulator returns
`implicitDeny` for `sts:AssumeRole` against all three chain roles and for the
common escalation actions. On its own it cannot escalate.

## Tool behaviour (for the Phase-4 FP tally)

- **PMapper (admin-flagged):** does **not** report this user (exact-string search
  of `04-query-preset-privesc.txt` and `06-analysis-text.txt` returns nothing; the
  two apparent hits are the substring `privesc-AssumeRole-start` inside
  `-starting-role`).
- **cloudfox (admin-default):** appears only in the `principals` inventory (one
  row, expected — it lists every principal); **absent** from `iam-simulator` and
  from `permissions`. Not reported as a path.

**The FP candidate does not materialise:** neither tool presents this user as a
chain entry point. Recorded as a cleared candidate, not an FP.

## Note — inertness is about its own permissions, not immunity as a target

Validation of `privesc13-AddUserToGroup` (see that file) elevated *this* user to
admin by adding it to `privesc-sre-group`. That does not make the user a valid
*start* point: the elevation is privesc13's capability, exercised by privesc13's
principal, not something this user can do for itself. Its own effective
permission set is empty, which is what "inert" means here.
