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
