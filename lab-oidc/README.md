# lab-oidc — Phase 5

The OIDC / web-identity trust-chaining scenario. Not part of the graded matrix.

Separate from `lab/` deliberately, for two reasons:

1. `lab/` is Bishop Fox's iam-vulnerable, unmodified. CLAUDE.md forbids touching
   its Terraform, and if it is vendored as a submodule, adding files to it is not
   possible anyway.
2. Keeping this in its own root with its own state means the graded runs happen
   against the canonical lab, before anything authored here exists. That
   ordering is the claim: the tools were measured on a baseline that did not
   include this scenario.

## State

Local, in this directory: `lab-oidc/terraform.tfstate`. Gitignored via the
root `.gitignore` (`*.tfstate`). It never shares state with `lab/`.

## Order of operations

Apply this **after** `analysis/matrix.md` exists, not before — rubric §7 and the
project outline. The matrix is what gives this finding context.

## Teardown

`terraform destroy` here as well as in `lab/`. Both.

---

## What is deployed

Applied 2026-08-30. **13 resources, nothing billable.** Full record, including
the rows in `analysis/scenarios.md` format and every confirmation, is in
[`SCENARIO.md`](SCENARIO.md).

| | |
|---|---|
| `token.actions.githubusercontent.com` | the account's only OIDC provider; there were none before |
| Scenario A, floor | `oidc-gha-deploy-role` -> `oidc-gha-terraform-role` (`Allow *:*`). `sub` StringLike `repo:*` |
| Scenario B, headline | `oidc-gha-wildcard-deploy-role` -> `oidc-gha-wildcard-terraform-role` (`Allow *:*`). `sub` StringLike `repo:<org>/*` |

Both chains are structurally identical. The hop-1 trust condition is the only
variable, which is what makes the pair a measurement rather than two anecdotes.

**Scenario A was authored with no `sub` condition at all and AWS refused to
create it** — then accepted `repo:*`, which admits exactly the same set. That
finding is written up in `SCENARIO.md`.

## Read this before leaving it running

These roles are assumable from the public internet, by principals holding no AWS
credentials at all. That is not true of anything in `lab/`. See
`SCENARIO.md`, "Live exposure", and tear down promptly.
