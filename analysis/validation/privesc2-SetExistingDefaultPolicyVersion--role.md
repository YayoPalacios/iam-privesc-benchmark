# `privesc2-SetExistingDefaultPolicyVersion--role` — M by all tools; **target absent**

- **Class:** `privesc` · **Category:** M by all tools (rubric §6, ≥3 confirmed) +
  scenario-list correction (rubric §6 / §4.8)
- **Applies to both principal rows** (`--role`, `--user`); enabling permission and
  target are identical.
- **Date validated:** 2026-08-31 · **Context:** `admin` (`user/iamadmin`)
- **Claim under test:** the principal can roll a customer-managed policy back to a
  more-permissive **existing** version via `iam:SetDefaultPolicyVersion`.

## Commands and outcomes

Account ID redacted to `000000000000`.

### 1. The grant is real but narrow — only SetDefaultPolicyVersion

```
# privesc2 managed policy body (default v1):
{ "Effect":"Allow","Action":"iam:SetDefaultPolicyVersion","Resource":"*" }
```

The principal holds `iam:SetDefaultPolicyVersion` on `*` and nothing else that
touches policy versions. In particular it has **no** `iam:CreatePolicyVersion`, so
it cannot manufacture a permissive version — it can only activate one that already
exists.

### 2. No customer-managed policy has an alternate version to activate

Scanned every account-owned policy in `get-account-authorization-details`:

```
account-owned (arn:aws:iam::000000000000:policy/...) policies with >1 version: NONE
total account-owned policies: 45   (all exactly one version)
```

Every policy with multiple versions in the account is **AWS-managed**
(`arn:aws:iam::aws:policy/...`, e.g. `AmazonEC2ReadOnlyAccess v1..v5`,
`SecurityAudit v1..v92`). `SetDefaultPolicyVersion` cannot target AWS-managed
policies, and no customer-managed policy carries a non-default version at all.

## Verdict — scenario-list error, corrected

**The permission is effective, but the exploitation target does not exist in this
deployment.** privesc2 escalates only by activating a *pre-existing* more-permissive
version of a customer-managed policy; there is no customer-managed policy with any
alternate version, and the principal cannot create one. On its own, privesc2
**cannot reach admin here**. This is `target_absent = yes`, not `no`.

`scenarios.md` recorded `target_absent = no` for both privesc2 rows on the strength
of the mechanism description, without confirming a multi-version customer policy
existed. Corrected to `yes`; logged in the scenarios.md Corrections table
(2026-08-31). Under §4.8 this also means a tool reporting privesc2 as a working
path to admin *in this account* would be overstating impact — but see below: no
tool reports it at all.

## Tool behaviour

- **PMapper (admin-flagged):** does not report privesc2 (absent from
  `query`/`analysis`).
- **cloudfox (admin-default):** `iam:SetDefaultPolicyVersion` bound to the
  principal appears only in the raw `permissions` dump; **absent** from
  `iam-simulator` (whose fixed query set does not include it).

**Genuine M by both tools.** With the target absent, the miss is not a detection
failure of consequence here; it is recorded so Phase 4 can score it in the
`target_absent` bucket rather than as a plain miss.
