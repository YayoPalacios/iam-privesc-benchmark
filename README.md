# IAM tool benchmark

This is the evidence behind the article. I deployed Bishop Fox's
`iam-vulnerable` in a throwaway AWS account, ran two open-source IAM
privilege-escalation tools against it, cloudfox 2.0.5 and PMapper 1.1.5, and
graded every scenario by hand. Everything I graded from is in here: the rules I
froze first, the grades, the checks I did by hand, and the untouched tool
output.

**Read the article first: [POST.md](POST.md).** The long working draft it was
cut from is [FINDINGS-full.md](FINDINGS-full.md).

## What's here

**[analysis/rubric.md](analysis/rubric.md)** — what counts as Detected, Partial,
Missed, and a false alarm. I committed it before I deployed anything, so
`git log` on that file shows the bar didn't move once I saw results. It only
ever got appended to.

**[analysis/grades.csv](analysis/grades.csv)** — 344 rows, one per
`(scenario, tool, context, flagset)`. Every row carries its grade, the raw
output it came from, the exact query or search I ran, and whether I confirmed it
by hand or inferred it. That last one is a column, not a caveat buried in prose.
Most rows are inferred, and you can see which.

**[analysis/validation/](analysis/validation/)** — 19 files, one per scenario I
checked by hand, with the exact commands and what came back. Section 3 of the
article comes from here. It's the part where my answer key turned out to be the
thing that was wrong.

**[raw-output/](raw-output/)** — every run, unedited, one directory per tool per
run: cloudfox and PMapper, as admin and as a read-only `SecurityAudit` user,
default flags and flagged. The one change is `redact.sh`, a one-way substitution
that swaps the account ID for `000000000000` and access key IDs for
placeholders. The script sits next to its own output, so "unedited" means
unedited apart from one rule you can read yourself.

The rest: `analysis/scenarios.md` is the ground truth, generated from the AWS
API rather than the lab's README. `analysis/matrix.md` is the per-scenario
matrix, written by hand from `grades.csv` — there's no generator. `lab/` is
`iam-vulnerable`, unmodified. `lab-oidc/` is the GitHub OIDC scenario from
section 4, kept in its own state.

## If you reproduce this, tear it down

Both Terraform states in here are empty, 0 resource instances each, so these
labs are already destroyed. That's a statement about the local state files.
Check the account itself if you want certainty.

If you deploy them yourself, destroy the OIDC one first:

```bash
cd lab-oidc && terraform destroy   # 13 resources, first
cd ../lab   && terraform destroy   # 265 resources
```

OIDC goes first because those roles are reachable from outside AWS with no
credentials at all. One of them trusts every repo in a GitHub org, and the only
thing keeping strangers out is that the org name is unregistered. Register it
and you get admin in that account. The main lab at least makes you steal
credentials first.

The main lab is the bigger cleanup. It creates 41 real access keys, so
`lab/terraform.tfstate` holds 41 live AWS secret keys in plaintext. The state
file is gitignored and never gets committed, but it's real credential material
sitting on a laptop until those keys are gone. Confirm with `terraform state
list` coming back empty, or `aws iam list-access-keys` across the lab users.

## Account hygiene

Throwaway account only. `iam-vulnerable` creates real users, real access keys,
and real roles built to escalate to account admin. Don't point this at an
account tied to anything you care about, and definitely not a shared one.

I used a dedicated personal sandbox under the profile `personal`, and every AWS
call in this repo names it explicitly. Run `aws sts get-caller-identity` and
read the answer before you run anything else.
