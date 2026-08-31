# `privesc-AssumeRole-starting--role` — D (multi-hop chain), exercised live

- **Class:** `chain-hop` · **Category:** D reported by PMapper (rubric §6, ≥3 confirmed)
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the three-hop chain
  `starting-role → intermediate-role → ending-role` is traversable and terminates
  at an administrative (`*:*`) role. PMapper reports the sub-chain from
  `starting-role` to `ending-role`.

## Commands and outcomes

Account ID redacted to `000000000000`. Fully non-destructive: only `sts:AssumeRole`
and a read at the terminus.

### Trust chain

```
starting-role      trusts  user/iamadmin
intermediate-role  trusts  role/privesc-AssumeRole-starting-role
ending-role        trusts  role/privesc-AssumeRole-intermediate-role
```

### Traversal (each hop uses the previous hop's credentials)

```
# hop 1: iamadmin -> starting-role
$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/privesc-AssumeRole-starting-role \
    --role-session-name chainval --profile personal
$ aws sts get-caller-identity --query Arn   # with hop-1 creds
arn:aws:sts::000000000000:assumed-role/privesc-AssumeRole-starting-role/chainval

# hop 2: starting -> intermediate  (hop-1 creds)
$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/privesc-AssumeRole-intermediate-role \
    --role-session-name chainval
arn:aws:sts::000000000000:assumed-role/privesc-AssumeRole-intermediate-role/chainval

# hop 3: intermediate -> ending    (hop-2 creds)
$ aws sts assume-role --role-arn arn:aws:iam::000000000000:role/privesc-AssumeRole-ending-role \
    --role-session-name chainval
arn:aws:sts::000000000000:assumed-role/privesc-AssumeRole-ending-role/chainval
```

### Terminus is administrative

```
# with ending-role credentials:
$ aws iam list-users --max-items 2 --query 'Users[].UserName'
[ "benchmark-securityaudit", "fn1-privesc3-partial-user" ]   # succeeds => IAM read; role holds Allow *:*
```

## Verdict

**Confirmed end-to-end.** Starting from `user/iamadmin`, each hop's credentials
successfully assumed the next role, and the terminus `ending-role` (which holds
`Allow *:*`) authorised `iam:ListUsers`. The full chain works.

## Tool behaviour

- **PMapper (admin-flagged):** **D.** Reports the chain explicitly, including the
  intermediate hop:
  > `role/privesc-AssumeRole-starting-role can escalate privileges by accessing
  > the administrative principal role/privesc-AssumeRole-ending-role:` then lists
  > `... can access via sts:AssumeRole role/privesc-AssumeRole-intermediate-role`
  > and `... intermediate-role can access via sts:AssumeRole ... ending-role`.
- **cloudfox (admin-default):** the individual `sts:AssumeRole` edges appear in
  `iam-simulator`, and `ending-role` is flagged "Appears to be an administrator";
  cloudfox does not stitch the multi-hop chain into a single path. (Grading is
  Phase 4.)
