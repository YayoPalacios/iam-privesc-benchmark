# Phase 5 — GitHub Actions OIDC trust-chaining scenarios

Two authored scenarios. **Not part of the graded matrix**, not derived from
`iam-vulnerable`, and deployed only after `analysis/matrix.md` was complete.
Nothing in `analysis/scenarios.md`, `analysis/grades.csv` or `analysis/matrix.md`
was edited to accommodate them; when these are graded, they belong in a separate
bucket with their own denominator (rubric §2, §6.1).

Account IDs render as `000000000000`, matching `redact.sh`, so ARNs here join
against redacted tool output.

## Provenance

| | |
|---|---|
| Applied | 2026-08-30, `us-east-1`, 13 resources |
| Identity | `arn:aws:iam::000000000000:user/iamadmin` via `--profile personal`, confirmed against `.account-id` immediately before each apply |
| Terraform | v1.14.8, `hashicorp/aws` v6.62.0 |
| State | `lab-oidc/terraform.tfstate`, local, gitignored. Never shared with `lab/`. |
| Pre-state | `list-open-id-connect-providers` and `list-saml-providers` both returned `[]`, matching `account-baseline.md`. The provider below is the only one in the account. |
| Billable | Nothing. IAM roles, customer-managed policies and OIDC providers are free; no compute, storage or NAT was created. GuardDuty is enabled and prices CloudTrail analysis per million events, so 13 creations is effectively but not literally $0. |
| Drift | `terraform plan -detailed-exitcode` reports no differences after apply. |

---

## The shape

Both chains are two hops, identical in structure. **The hop-1 trust policy is the
only variable between them.** Everything else — the thin entry permission, the
tight hop-2 trust, the administrator terminus — is held constant on purpose, so
that a tool's result on the pair is attributable to the trust condition and to
nothing else.

```
                 OIDC provider: token.actions.githubusercontent.com
                 client_id_list (aud): sts.amazonaws.com
                        │                              │
   sts:AssumeRoleWithWebIdentity            sts:AssumeRoleWithWebIdentity
   aud pinned, sub StringLike               aud pinned, sub StringLike
            "repo:*"                        "repo:iam-tool-benchmark-lab/*"
                        │                              │
                        ▼                              ▼
      oidc-gha-deploy-role              oidc-gha-wildcard-deploy-role     hop 1
      policy: sts:AssumeRole on         policy: sts:AssumeRole on
      exactly one named role            exactly one named role
                        │                              │
              sts:AssumeRole                   sts:AssumeRole
                        ▼                              ▼
      oidc-gha-terraform-role           oidc-gha-wildcard-terraform-role  hop 2
      policy: Allow *:*                 policy: Allow *:*
      trust: entry role only            trust: wildcard entry role only
        = ACCOUNT ADMIN                   = ACCOUNT ADMIN
```

Hop 2 is correct in both chains. Its trust policy names exactly one principal and
its permission policy is what a Terraform execution role legitimately needs. The
chain is open anyway, because hop 1's front door is open. That asymmetry is the
scenario: **every control on the valuable resource is right, and it does not
matter.**

---

## Scenario A — the floor case

`sub` matches every repository on github.com. Indefensible on sight; it exists to
be the strawman that Scenario B is measured against.

```json
{
  "Sid": "GitHubActionsWebIdentity",
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:*" }
  }
}
```

### It was authored with no `sub` condition at all, and AWS refused to create it

This is the first real finding of Phase 5 and it was not anticipated.
`CreateRole` returns, verbatim:

```
MalformedPolicyDocument: Trust policy with trusted principal
arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com must
evaluate, using StringEquals, StringLike or StringEqualsIgnoreCase,
token.actions.githubusercontent.com:sub or
token.actions.githubusercontent.com:job_workflow_ref which is not scoped to all.
```

So AWS ships a guardrail against exactly the misconfiguration this scenario was
built to represent. The obvious conclusion — that the floor case no longer exists
in the wild — is wrong, and the reason is worth the section.

### The guardrail is cosmetic

Probed 2026-08-30 against this account, by `iam create-role` with a throwaway
role deleted immediately after. Four candidates, one variable:

| `sub` condition | `CreateRole` |
|---|---|
| *(absent)* | **REJECTED** |
| `StringLike "*"` | **REJECTED** |
| `StringLike "repo:*"` | **ACCEPTED** |
| `StringLike "repo:*/*"` | **ACCEPTED** |

Every default-format GitHub Actions subject claim begins with `repo:` —
`repo:<owner>/<repo>:ref:refs/heads/main`, `repo:<owner>/<repo>:pull_request`,
`repo:<owner>/<repo>:environment:prod`. **`repo:*` therefore matches all of them,
and is semantically identical to the condition AWS just refused.** The check is a
string test on the policy document, not an evaluation of what the policy admits.

The floor case survives intact; only its spelling changed. And the finding is
sharper than the scenario it was blocking:

- A reviewer, an auditor, or a tool that treats "a `sub` condition is present" as
  the control is measuring the same thing AWS's guardrail measures, and is
  wrong in the same way.
- The rejection message is educational and specific, which makes it more likely,
  not less, that an engineer hitting it will paste in the first pattern that gets
  accepted.

**Caveat, disclosed:** the equivalence holds for the default subject-claim
template. GitHub lets an organisation customise the claim (`include_claim_keys`),
which can produce a `sub` that does not begin with `repo:` — for such an org
`repo:*` matches nothing. This is not the default and not the common case, but
"matches every GitHub Actions token in existence" is imprecise and the precise
claim is "matches every default-format Actions subject claim."

---

## Scenario B — the headline case

`sub` is present, `StringLike`, and scoped to an organisation.

```json
{
  "Sid": "GitHubActionsWebIdentityOrgWildcard",
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:iam-tool-benchmark-lab/*" }
  }
}
```

This is the one that ships. It passes a skim review: the audience is pinned, the
subject is constrained, the organisation is named, and the whole thing looks like
the documented pattern. What it admits is **every repository under that
organisation** — every branch, every tag, every environment, every
`pull_request` run, and every repository created after the review by anyone who
can create one.

What it was presumably meant to enforce, recorded in the `sub_patterns` output so
the gap is legible without reading Terraform:

| | |
|---|---|
| enforced | `repo:iam-tool-benchmark-lab/*` |
| intended | `repo:iam-tool-benchmark-lab/deploy:ref:refs/heads/main` |

The distance between those two strings is one `*`, and it is the difference
between one branch of one repository and the whole organisation's future.

**Why B is the headline and A is the strawman.** A is caught by inspection and,
as of now, half-caught by AWS itself. B is caught by neither: AWS accepts it, and
a reviewer sees a `sub` condition and moves on. Any claim this benchmark makes
about tooling rests on B.

---

## Rows, in `analysis/scenarios.md` format

Four rows: two entry principals and two chain termini. Two classes are new and
are defined below the table rather than assumed.

| scenario_id | principal ARN | mechanism | enabling permission | intended target | access key | viable start | target_absent | class |
|---|---|---|---|---|---|---|:--:|---|
| `oidc1-SubMatchesAllRepos--role` | `arn:aws:iam::000000000000:role/oidc-gha-deploy-role` | oidc1-SubMatchesAllRepos | Trust: `sts:AssumeRoleWithWebIdentity`, `sub` StringLike `repo:*`; Allow: `sts:AssumeRole` on `role/oidc-gha-terraform-role` | `role/oidc-gha-terraform-role` -> account admin | no | yes - any GitHub Actions workflow in any repository on github.com | **no** | oidc-entry |
| `oidc1-SubMatchesAllRepos--target` | `arn:aws:iam::000000000000:role/oidc-gha-terraform-role` | oidc1-SubMatchesAllRepos | Allow: `*:*` | n/a - this is the terminus | no | no - assumable only by `role/oidc-gha-deploy-role` | **n/a** | target-only |
| `oidc2-SubMatchesOrgWildcard--role` | `arn:aws:iam::000000000000:role/oidc-gha-wildcard-deploy-role` | oidc2-SubMatchesOrgWildcard | Trust: `sts:AssumeRoleWithWebIdentity`, `sub` StringLike `repo:iam-tool-benchmark-lab/*`; Allow: `sts:AssumeRole` on `role/oidc-gha-wildcard-terraform-role` | `role/oidc-gha-wildcard-terraform-role` -> account admin | no | yes - any workflow in any repository under org `iam-tool-benchmark-lab` | **no** | oidc-entry |
| `oidc2-SubMatchesOrgWildcard--target` | `arn:aws:iam::000000000000:role/oidc-gha-wildcard-terraform-role` | oidc2-SubMatchesOrgWildcard | Allow: `*:*` | n/a - this is the terminus | no | no - assumable only by `role/oidc-gha-wildcard-deploy-role` | **n/a** | target-only |

**`oidc-entry`** — new class. The principal is reachable only by
`sts:AssumeRoleWithWebIdentity` from a federated identity **outside the AWS
account**. It has no access key, and no principal inside the account can assume
it. Every start point in `analysis/scenarios.md` is an in-account principal or an
access key; this class has neither, which is the whole point.

**`target-only`** — reused from `analysis/scenarios.md` unchanged: an endpoint,
not a start point.

---

## Confirmed

### No principal inside the account can reach any of the four roles

`user/iamadmin` holds `AdministratorAccess`, so its identity policy permits
`sts:AssumeRole` on everything. All four denials are therefore the *resource*
trust policies refusing, which is exactly what is being confirmed.

```
$ aws sts assume-role --profile personal \
    --role-arn arn:aws:iam::000000000000:role/<ROLE> \
    --role-session-name phase5-reachability-check
```

| role | result |
|---|---|
| `oidc-gha-deploy-role` | `AccessDenied ... not authorized to perform: sts:AssumeRole on resource: .../oidc-gha-deploy-role` |
| `oidc-gha-terraform-role` | `AccessDenied ... on resource: .../oidc-gha-terraform-role` |
| `oidc-gha-wildcard-deploy-role` | `AccessDenied ... on resource: .../oidc-gha-wildcard-deploy-role` |
| `oidc-gha-wildcard-terraform-role` | `AccessDenied ... on resource: .../oidc-gha-wildcard-terraform-role` |

Two consequences:

1. **These 13 resources add zero new intra-account escalation paths.** The graded
   baseline in `analysis/matrix.md` is unaffected as a matter of fact, not only
   as a matter of ordering. Both entry roles are unreachable from every principal
   the graded runs saw.
2. The only route in is `sts:AssumeRoleWithWebIdentity` with a GitHub-issued
   token, which is precisely the edge an account-internal graph does not contain.

### Deployed inventory

One OIDC provider (`token.actions.githubusercontent.com`), four roles, four
customer-managed policies each attached exactly once. Verified by
`iam list-open-id-connect-providers`, `list-roles`, `list-policies --scope Local`
and `list-attached-role-policies` after apply.

---

## Inferred, not confirmed

**End-to-end exploitability of both chains has NOT been proven.** Per the
CLAUDE.md constraint to flag inference rather than assert it:

- What is confirmed: the trust policies exist as written, AWS accepted them, the
  permission policies grant the hop, hop 2 holds `Allow *:*`, and no in-account
  principal can reach either chain.
- What is not: that a GitHub Actions token actually satisfies these conditions
  and yields admin. Proving it needs a real repository running a workflow with
  `permissions: id-token: write`, calling
  `sts:AssumeRoleWithWebIdentity`, then `sts:AssumeRole` on hop 2. That was not
  done and no such repository exists.
- The inference rests on the documented format of the GitHub Actions `sub` claim
  and on AWS's own condition-evaluation semantics. Both are well documented; the
  inference is strong. It is still an inference, and it applies equally to
  Scenario A and Scenario B.
- The `repo:*` equivalence carries the additional subject-claim-template caveat
  recorded in Scenario A.

Anyone grading these scenarios should treat the exploitability column as
`inferred` until a workflow run is recorded here.

---

## Live exposure

**This is a real OIDC trust in a real AWS account, and it is reachable from the
public internet.** Not theoretical:

- Scenario A's entry role can be assumed by **anyone** who runs a GitHub Actions
  workflow and knows the role ARN. The only thing standing between it and account
  admin is that the ARN is not published.
- Scenario B's entry role can be assumed by anyone who controls a repository
  under the GitHub organisation `iam-tool-benchmark-lab`. That name was chosen
  because it is unregistered — `api.github.com/orgs/iam-tool-benchmark-lab` and
  `/users/iam-tool-benchmark-lab` both returned HTTP 404 on 2026-08-30, checked
  before apply. **If someone registers it, they get admin in this account.**

Consequences, and they are not optional:

- The account ID must stay out of the repository. `redact.sh` already enforces
  this and `--check` covers path names as well as contents (rubric §9,
  2026-08-31). Any Phase 5 tool output goes through it like everything else.
- The repository stays private until the writeup is ready, per rubric §5.3.
- **Teardown is more urgent here than for `lab/`.** iam-vulnerable's principals
  are exploitable by someone who already has credentials in the account. These
  two are exploitable by someone who has none.
- Re-check the org registration if this is left standing for any length of time.

---

## Teardown

`terraform destroy` in **both** roots. This one and `../lab`.

```
cd lab-oidc && terraform destroy   # 13 resources
cd ../lab   && terraform destroy   # 265 resources
```

Neither removes `user/benchmark-securityaudit` (see `analysis/account-baseline.md`)
and neither touches the `EC2-AutoRemediation` Lambda, which is deliberate and
must be kept.

---

## Notes for whoever grades this

1. **Grade these in their own bucket.** They are authored, not canonical, and the
   rubric §2 bias note does not apply to them — no tool was built against this
   catalogue. That is the point of Prediction 5.
2. **The pair is the measurement, not either row.** A tool that flags A and not B
   has done the same thing AWS's guardrail does: matched on the presence of a
   condition rather than on what it admits. Report the pair.
3. **Watch for the overstated-impact direction too** (rubric §4.8). Both chains
   really do terminate at `Allow *:*`, so "reaches admin" is correct here — but a
   tool that reports the *entry* roles as reachable by an in-account principal is
   asserting something the denial table above disproves.
4. Prediction 5 in `analysis/rubric.md` §8 says neither tool detects this. It is
   recorded as untested; no tool has been run against these resources.
