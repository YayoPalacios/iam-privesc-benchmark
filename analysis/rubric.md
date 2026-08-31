# Grading rubric

**Written before any tool was run. Frozen at the commit that introduces this file.**

## Change control

Reconciles with CLAUDE.md ("the rubric does not change after tool runs begin"):

- Before the freeze commit, this document may be revised freely.
- After the freeze commit it is **append-only**. Rules are never edited, reworded, or deleted.
- A case this document does not cover gets a **new** rule appended to §9, dated, with the scenario that forced it.
- Existing rules are never silently reinterpreted.
- The git history of this file is the freeze proof. `git log -p analysis/rubric.md` shows what was committed to before Phase 2 and what was added after.

---

## 1. What is being measured

For each scenario in `analysis/scenarios.md`, whether a tool's output would lead a competent reviewer to the escalation path, running the tool as documented.

Not being measured: speed, output aesthetics, feature breadth, or whether a tool is "good." A tool that scores poorly here may be excellent at something this benchmark does not test. Say so in the writeup.

**Grading is unweighted.** A missed four-hop chain to account admin scores exactly the same as a missed single-hop to a low-value target. This is a known limitation, not an oversight: severity weighting would require an impact model this benchmark does not have, and inventing one after seeing the results is exactly the kind of post-hoc rationalization this rubric exists to prevent. State the limitation in the post.

## 2. Ground truth

The scenario list is generated from Terraform state and the AWS API, not from the lab's README.

**Known bias, state it in the post:** IAM Vulnerable derives from Rhino Security Labs' catalog of AWS privilege escalation methods. PMapper and cloudfox were substantially built to detect that same catalog. High scores on the canonical list are therefore the expected outcome and are not evidence of tool quality. The informative results are:

- scenarios on the list that a tool still misses
- false positives
- the off-list scenarios authored separately (Phase 5)

### 2.1 Scenario granularity

**A scenario row is a `(principal, mechanism)` pair.** One principal exercising one escalation mechanism is one row. The same mechanism reachable by three principals is three rows; one principal with two distinct mechanisms is two rows.

- **Headline numbers are reported at the mechanism level** — a mechanism is Detected for a tool only if the tool detects it for every principal that has it. This is the number a reader cares about: does the tool understand this class of path.
- **Per-principal detail is retained** in `analysis/grades.csv` and in the matrix, because the case where a tool catches one variant of a mechanism and misses another is a real and interesting finding that mechanism-level rollup hides.

Both denominators are published. Neither is presented without the other.

**Report absolute counts, never percentages.** "Detected 17 of 21 mechanisms" — not "81%." At this sample size a percentage implies a precision the benchmark does not have, and it invites comparison against numbers computed on a different denominator.

## 3. Grades

| Grade | Definition |
|---|---|
| **D** — Detected | Output names the principal, the enabling permission, and the reachable target or resulting privilege. A reviewer reading only the output would act on it. |
| **P** — Partial | Output binds a risky permission to a specific principal, but does not connect it to a target or characterize it as escalation. |
| **M** — Missed | Nothing in the output points a reviewer at this path. |
| **FP** — False positive | Tool reports a path that manual validation shows does not work, **or** materially overstates the privilege the path yields. See §4.8. |
| **N/A** | Tool's own documentation explicitly disclaims this category. Requires a quoted, linked disclaimer. See §4.9. Record it; do not score it as a miss. |

## 4. Decided in advance

These are the calls that get rationalized after the fact if you don't fix them now.

1. **Generic permission dumps.** A list of dangerous permission names with no principal binding is **M**, not P. Partial credit requires the output to tie the permission to a specific principal.

2. **Non-default flags.** The headline grade is the **default invocation**. If a non-default flag surfaces the path, record it in a separate column with the exact flag. Never merge the two into one score.

3. **Right answer, wrong mechanism.** If a tool reports a path that differs from the intended one but manual validation confirms it works, it scores **D**. Note the divergence — it may be a better finding than the intended scenario.

4. **Multi-hop chains.** Finding hop 1 without the chain is **P**. Finding the full chain to the target is **D**.

5. **Buried in the output.** Graded on where the finding surfaces, not on what the grader knew. Ground truth is built before grading begins, so "would I have found this on my own" is contaminated by construction and cannot be applied honestly. The third-party-checkable test:

   - **D** — the path appears in the tool's summarized or queried output surface: its default report, its documented query or filter interface, its loot files, its presets.
   - **P** — the path appears only in a raw dump, and reaching it required a search string that could not have been formed without already holding ground truth (a specific role name, a specific target ARN).

   Record the exact command or search used for every cell graded under this rule. Another reviewer with the same raw output must be able to reach the same grade.

6. **Ambiguity defaults down.** If you cannot decide between two grades, take the lower one and record why.

7. **Tool crash or partial failure is M.** If a tool errors, hangs, or silently skips a principal, the affected scenarios grade **M** — a reviewer gets nothing, and the reason does not change that. But **tally crash-Ms separately from detection-Ms** and report them as separate numbers. A tool that cannot run is a maintenance finding; a tool that runs and misses is a detection finding. Blending them produces a misleading column, particularly for an unmaintained tool.

8. **Overstated impact is a false positive.** FP is not limited to paths that fail outright. It also covers a path that works but whose privilege gain the tool materially overstates — reported as reaching administrative access when manual validation shows a lateral move or a narrower grant — and a path reported as unconditional that in fact holds only because a condition the tool never evaluated happens to be satisfied in this lab.

   **Record the total number of paths each tool reports.** One FP among 300 reported paths and one among 5 are different results, and an FP count without a denominator is not a finding.

   **Because validation is sampled, report "FPs found in a sample of N validated paths" — never an FP rate.** A rate implies the whole population was checked.

9. **N/A requires a quoted disclaimer.** N/A applies only where the tool's own documentation explicitly states it does not cover the category. Quote the sentence and link the source in the cell note. Absent that, the grade is **M**. A generous reading of "doesn't claim to do this" would void most misses for a tool that never advertised path enumeration, and would make the matrix vacuous.

## 5. Run conditions

Held constant across all tools. Record in `raw-output/<tool>/<context>-<flagset>-<date>/run-metadata.md`.

- **Tool version and commit hash.** For PMapper, also record the Python version and any dependency pinning required to make it run.
- **iam-vulnerable commit hash** and the tfvars used for the deployment under test.
- **Exact command and timestamp** for every invocation. Wall-clock duration is **not** recorded — §1 states speed is not measured, and collecting a metric already committed to being ignored is overhead.
- **Raw output committed unedited**, subject to the redaction convention below.

### 5.1 Principal contexts

- **`admin`** — full IAM read access. **The headline grade for every scenario is the admin-context run.** The matrix is an admin-context matrix.
- **`limited`** — the AWS-managed **`SecurityAudit`** policy, attached to a purpose-made principal. Chosen because it is what an actual auditor or CSPM integration holds, so the delta means something. A principal missing `iam:ListRoles` would produce near-empty output from both tools and a finding that is true but trivial.

  **The limited context is one run per tool, over the same command set as the admin run. It is not graded per scenario.** It is reported as a qualitative delta: what disappeared, what degraded, what survived. Per-scenario grading of a second context quadruples the artifact volume to support a finding that is a paragraph. If the delta turns out to be more interesting than expected, the admin grades and raw output are still on disk and the pass can be added later.

  **Note in the post that a different limited principal changes the delta.** `SecurityAudit` is one point on a spectrum; the result is not "tools degrade by X under low privilege," it is "tools degrade this way under this policy."

### 5.2 Flagged runs

**There is no unconditional flagged run.** A non-default-flag run is performed only where a default-run **M** looks plausibly flag-fixable. Running flag variants across the board generates output that nobody grades.

Where a flagged run is performed, record the exact flag, grade it in the separate column per §4.2, and state in the note why the default run's M prompted it.

### 5.3 Redaction

Raw output is committed **unedited except for one published, one-way substitution**: `redact.sh`, applied to every file under `raw-output/`, replaces the AWS account ID and access key IDs with fixed placeholder tokens.

The script is committed alongside the output it produced. "Unedited" therefore means "unedited modulo one auditable rule," which preserves the property that matters — a reader can check any grade against the source — while satisfying the CLAUDE.md constraint that account IDs and access keys are never committed.

The repository stays private until the writeup is ready.

## 6. Validation sampling

Manual CLI validation for a minimum of:

- 3 scenarios graded **D** by at least one tool (confirm the path actually works)
- 3 scenarios graded **M** by all tools (confirm the path is real and the miss is genuine)
- every **FP** candidate, without exception

One file per scenario in `analysis/validation/<scenario_id>.md`, with exact commands and outcomes.

A **M** that turns out not to be a real path is a scenario-list error, not a tool miss. Fix the list and note the correction.

### 6.1 Paths discovered during validation

Manual validation may turn up a working path that the Terraform-state-derived scenario list never showed — a combination across principals, a trust policy looser than the module intended, a managed-policy body that state records only as an ARN. This is expected: state is an inventory of declared resources, not an evaluation of effective permissions.

Such paths are **allowed into the benchmark, must be disclosed as late additions, and are tallied in their own bucket** — reported separately from the pre-registered scenario list, with the date found and how they were found.

They are not silently folded into the main denominator. A tool "missing" a path that the ground-truth process itself missed is a different claim from a tool missing a path that was on the list from the start, and the post must be able to tell a reader which is which.

## 7. Out of scope

Not tested here, and the post should say so:

- Runtime and behavioral detection (CloudTrail, GuardDuty)
- Cross-account and Organizations-level paths
- SCPs and permission boundaries beyond what the lab deploys
- Resource policies other than IAM role trust policies
- Anything requiring an agent or write access

**Deliberately out of scope, and named because it is the obvious next step:** an `iam:SimulatePrincipalPolicy` sweep over the (principal × sensitive-action) matrix, used as a ground-truth oracle independent of both graded tools. AWS's own policy evaluator would give a path source that does not inherit the Rhino-catalog bias described in §2, and it is the natural way to attack the "path neither tool reported that works" question at scale. It is excluded from this phase to keep the scope bounded. Its absence is a real limitation of these results and the post should say so rather than implying the scenario list is complete.

## 8. Pre-registered predictions

Write these now, before any run. Compare against results in the writeup and report the misses honestly — a wrong prediction you disclosed is worth more to a reader than a matrix with no author in it.

1. **At the mechanism level, in the admin context, both tools grade D on at least four fifths of the canonical Rhino-catalog mechanisms** — expressed as counts against the mechanism denominator once `analysis/scenarios.md` exists, not as a percentage.
2. The `limited` (`SecurityAudit`) run shows a materially reduced output surface for both tools, qualitatively.
3. PMapper produces more **P** than **D** on multi-hop chains at default settings.
4. At least one **FP** appears across the two tools, within the validated sample.
5. Neither tool detects the OIDC / web-identity trust-chaining scenario in Phase 5.

Prediction 5 is the thesis. If it turns out false, that is a real result and the post changes shape rather than getting shelved.

## 9. Amendments

Append-only. New rules only — never edits to the rules above. Each entry: date, the scenario that forced it, the rule.

_(none yet)_

---

**Frozen:** at the commit introducing this file. See `git log -p analysis/rubric.md`.
