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
