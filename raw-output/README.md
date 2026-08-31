# Raw tool output

Unedited, one directory per run:

```
raw-output/<tool>/<context>-<flagset>-<date>/
```

- `<tool>` — `pmapper` | `cloudfox`
- `<context>` — `admin` | `limited`
- `<flagset>` — `default` | `flagged`
- `<date>` — `YYYY-MM-DD`

Example: `raw-output/cloudfox/admin-default-2026-09-06/`

Every run directory contains a `run-metadata.md` (copy
`run-metadata.template.md`) alongside the tool's own output files, in JSON
wherever the tool supports it.

## Do not hand-edit

The point of this directory is that a reader can check any grade in
`analysis/grades.csv` against the source. The single permitted transformation is
`../redact.sh`, a published one-way substitution for the AWS account ID and
access key IDs, run over this directory before commit. The script is committed
alongside the output it produced, so "unedited" means "unedited modulo one
auditable rule."

Rubric §5.3. Repo stays private until the writeup is ready.

### The rule covers path names as well as file contents

Extended 2026-08-31, during the first tool runs. Both tools put the account ID
in a **directory name**, not only inside files:

- cloudfox writes to `<outdir>/cloudfox-output/aws/<profile>-<account-id>/`
- PMapper stores its graph under
  `<appdata>/com.nccgroup.principalmapper/<account-id>/`

Substituting file contents but not names would have left the account ID
committed, against the CLAUDE.md constraint that it never is. `redact.sh` now
applies the *same three substitutions* to each path component and renames
bottom-up, and `--check` fails on an offending name as it does on offending
contents. It is one rule, not two: `redacted_basename()` in the script is the
same expression set the content pass uses.

This widens the scope of the existing rule; it does not add a second
transformation, and nothing about how output is graded changes.

### One deviation, recorded in the run directory

`cloudfox --outdir` also writes cloudfox's own AWS API response *cache*
(`cached-data/`): 1838 files, 36 MB, mostly Go `.gob` binaries, with the account
ID in every filename. That cache is an input to cloudfox, not a finding by it,
and a text substitution over binaries is not an auditable operation. It is
**moved, not deleted**, to `tools/cloudfox-cache/` (gitignored) and the move is
recorded in `cloudfox/admin-default-2026-08-31/cached-data-NOT-COMMITTED.md`.
Every cloudfox finding remains in `cloudfox-output/`.
