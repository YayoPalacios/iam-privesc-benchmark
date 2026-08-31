# IAM tool benchmark

The evidence behind a write-up benchmarking two open-source AWS IAM
privilege-escalation tools — PMapper 1.1.5 and cloudfox 2.0.5 — against Bishop
Fox's `iam-vulnerable` lab in a throwaway account. Everything here is what I
graded from: the rubric I froze first, the grades, the checks I did by hand, and
the untouched tool output.

**Read the article first: [POST-short.md](POST.md).** The long working
draft it was cut from is [POST.md](FINDINGS-full.md).

## What's here

**[analysis/rubric.md](analysis/rubric.md)** — what counts as Detected, Partial,
Missed, and a false alarm. Committed before I deployed anything, so `git log` on
that file is the proof the bar didn't move after I saw results. Amended only by
append.

**[analysis/grades.csv](analysis/grades.csv)** — 344 rows, one per
`(scenario, tool, context, flagset)`. Each carries its grade, the path to the
raw output it came from, the exact query or search I used, and whether I
confirmed it by hand or inferred it. That last column is published, not buried:
most rows are `inferred`, and you can see which.

**[analysis/validation/](analysis/validation/)** — 19 files, one per scenario I
checked by hand, with the exact commands and what came back. This is where the
"my answer key was wrong" section of the article comes from.

**[raw-output/](raw-output/)** — unedited output from every run, one directory
per tool per run: cloudfox and PMapper, as admin and as a read-only
`SecurityAudit` user, default flags and flagged. The only change is `redact.sh`,
a one-way substitution that swaps the account ID for `000000000000` and access
key IDs for placeholders. The script is committed next to its output, so
"unedited" means "unedited apart from one rule you can read."

Also: `analysis/scenarios.md` (the ground truth, generated from the AWS API
rather than the lab's README), `analysis/matrix.md` (the per-scenario matrix,
written by hand from `grades.csv` — there is no generator), `lab/`
(`iam-vulnerable`, unmodified) and `lab-oidc/` (the GitHub OIDC scenario from
the last section of the article, in its own state).

## If you reproduce this, tear it down

Both Terraform states in this repo are empty — 0 resource instances each — so
these labs are already destroyed. That's a statement about the local state
files; check the account itself if you need certainty.

If you deploy them yourself, destroy the OIDC one first:

```
cd lab-oidc && terraform destroy   # 13 resources — first
cd ../lab   && terraform destroy   # 265 resources
```

**OIDC first, because those roles are reachable from outside AWS with no
credentials at all.** One of them trusts every repo in a GitHub org, and the
only thing keeping strangers out is that the org name is unregistered. If
someone registers it, they get admin in that account. The main lab at least
requires stealing existing credentials first.

The main lab is the bigger cleanup: it creates 41 real access keys, so
`lab/terraform.tfstate` holds 41 live AWS secret keys in plaintext. The state
file is gitignored, so it never gets committed, but it's real credential
material sitting on a laptop until the keys are deleted. Confirm with
`terraform state list` coming back empty, or `aws iam list-access-keys` over the
lab users.

## Account hygiene

Throwaway account only. `iam-vulnerable` creates real users, real access keys,
and real roles built to escalate to account admin — this is not something to
point at an account tied to anything you care about, and definitely not a shared
one.

I used a dedicated personal sandbox under the profile `personal`, and every AWS
call in this repo names it explicitly. Check `aws sts get-caller-identity`
before you run anything.
