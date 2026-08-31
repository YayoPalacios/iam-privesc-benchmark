# `cached-data/` was moved out of this directory before commit

`cloudfox --outdir` writes two things: the tool's output
(`cloudfox-output/`) and its own AWS API response cache (`cached-data/`).
Only the first is tool output. The second is moved, not deleted, to:

    tools/cloudfox-cache/admin-default-2026-08-31/

(`tools/` is gitignored.) It is still on disk and can be restored to this
directory if a reader needs it.

## Why it is not committed

- **1838 files, 36 MB**, of which most are `.gob` — Go binary gobs, not text.
- **The account ID is in every filename** (e.g.
  `000000000000-iam-ListAccessKeys-privesc-ssmSendCommand-user.gob`).
  `redact.sh` substitutes file *contents*; it does not rename files, so
  committing this tree would put the account ID in the repo 1838 times in a
  form the redaction check does not catch.
- Running a text substitution over binary `.gob` files is not a safe or
  auditable operation, and rubric §5.3 depends on the redaction being exactly
  one auditable rule.

## What is not lost

Nothing that a grade could be checked against. The cache holds raw AWS API
responses, which are inputs to cloudfox, not findings by cloudfox. Every
finding is in `cloudfox-output/` in `json/`, `csv/`, `table/` and `loot/`.

Recorded here rather than done silently, because the raw-output README says
this directory is unedited and this is the one deviation in this run.
