# Manual validation

One file per scenario: `analysis/validation/<scenario_id>.md`, where
`<scenario_id>` matches the `scenario_id` column in `../grades.csv` exactly.

Minimum sample, per rubric §6:

- 3 scenarios graded **D** by at least one tool — confirm the path works
- 3 scenarios graded **M** by all tools — confirm the path is real and the miss
  is genuine
- every **FP** candidate, without exception

Each file records the exact commands run and the outcome, verbatim. A scenario
validated here flips its `validation_status` in `grades.csv` from `inferred` to
`validated`.

A path found here that the Terraform-derived scenario list never showed is
allowed in, disclosed as a late addition, and tallied in its own bucket —
rubric §6.1. Note the date found and how it was found.
