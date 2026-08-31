# `privesc-sre--user` — D, validated (group-derived admin)

- **Class:** `privesc` · **Category:** D reported by PMapper (rubric §6, ≥3 confirmed)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the user holds no direct policy; its privilege comes
  entirely from membership in `privesc-sre-group`, which carries an admin-grade
  policy. This is the "privilege via group, not via the principal" case.

## Commands and outcomes

Account ID redacted to `000000000000`. Read-only + AWS policy simulator.

```
# no direct policy on the user
$ aws iam list-attached-user-policies --user-name privesc-sre-user --profile personal --query AttachedPolicies
[]
$ aws iam list-user-policies --user-name privesc-sre-user --profile personal --query PolicyNames
[]

# privilege source is the group
$ aws iam list-groups-for-user --user-name privesc-sre-user --profile personal --query 'Groups[].GroupName'
[ "privesc-sre-group" ]

$ aws iam list-attached-group-policies --group-name privesc-sre-group --profile personal
privesc-sre-admin-policy (arn:aws:iam::000000000000:policy/privesc-sre-admin-policy)

# policy body (default v1):
{ "Effect":"Allow","Action":["iam:*","ec2:*","s3:*"],"Resource":"*" }

# AWS evaluator confirms the USER effectively has these, via the group:
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:user/privesc-sre-user \
    --action-names iam:AttachUserPolicy iam:CreateUser ec2:RunInstances s3:GetObject iam:PutUserPolicy
=> iam:AttachUserPolicy : allowed
   iam:CreateUser       : allowed
   ec2:RunInstances     : allowed
   s3:GetObject         : allowed
   iam:PutUserPolicy    : allowed
```

## Verdict

**Confirmed.** The user has no identity-based policy of its own, yet AWS's
simulator authorises `iam:*`/`ec2:*`/`s3:*`-class actions for it through
`privesc-sre-group` → `privesc-sre-admin-policy`. `iam:PutUserPolicy` /
`iam:AttachUserPolicy` alone let it grant itself `AdministratorAccess`, so the
group membership is effectively administrative. Not exercised destructively —
the primitive (attach-admin-to-self) is the same one validated behaviourally under
privesc4/privesc13; here the point is that the privilege is real despite an empty
direct policy.

## Tool behaviour

- **PMapper (admin-flagged):** **D.** Reports `user/privesc-sre-user is an
  administrative principal` — it resolves group-derived permissions and classifies
  the user as admin.
- **cloudfox (admin-default):** `privesc-sre-user` appears in `iam-simulator` rows
  ("can iam:PassRole on *", "can ec2:DescribeInstanceAttributeInput on *"), i.e. it
  surfaces some of the group-derived permissions bound to the user. (Grading is
  Phase 4.)
