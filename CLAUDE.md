# IAM Vulnerable tool benchmark — Claude Code working outline

Track B, phase 1. Goal: a per-scenario detection matrix comparing PMapper and cloudfox on a known-vulnerable AWS IAM environment. `iamwho` gets added last, deliberately, so it is measured against a baseline you did not build around it.

---

## Feasibility

Yes, this works in Claude Code. It's close to an ideal fit: Terraform apply, running CLI tools, parsing JSON, cross-referencing outputs into a table, and writing the results up. All of that is plumbing, and plumbing is what it's good at.

Two things it will not do for you:

1. **Judge whether a reported path is real.** Both tools produce false positives and both miss things. The value of your writeup is entirely in the manual validation step, and that step is yours.
2. **Decide what "detected" means.** PMapper reporting that a principal has `iam:PutUserPolicy` is not the same as it reporting an escalation path. You have to define the grading rubric before you run anything, or you'll rationalize it afterward to fit whatever result you got.

---

## Before you start: account hygiene

Non-negotiable, because you have Scopely credentials on the same machine.

- **Fresh personal AWS account.** Not Scopely, not an account linked to anything you touch at work. IAM Vulnerable intentionally creates exploitable users, roles, and access keys.
- **Named CLI profile** for the lab (`personal`), and confirm what `aws sts get-caller-identity --profile personal` returns before you run anything. Set `AWS_PROFILE` explicitly in the session rather than relying on default credentials.
- **Budget alarm** at a low threshold. The IAM resources themselves are free; check what else the Terraform stands up before you apply.
- **`.gitignore` before the first commit**: `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*.pem`, `credentials*`, `raw-output/` if it contains access key IDs.
- **`terraform destroy` when done.** Put it in the README as step one of the teardown so future-you doesn't leave a lab full of privesc paths running.

Tell Claude Code all of this up front. It will otherwise happily suggest running things against whatever credentials it finds.

---

## Repo layout

```
iam-tool-benchmark/
├── CLAUDE.md
├── README.md
├── lab/                  # iam-vulnerable submodule or clone, terraform
├── raw-output/           # unedited tool output, one dir per tool per run
│   ├── pmapper/
│   └── cloudfox/
├── analysis/
│   ├── rubric.md         # written BEFORE any tool runs
│   ├── scenarios.md      # enumerated from the lab, one row per scenario
│   ├── validation/       # manual proof for each path you check by hand
│   └── matrix.md         # the deliverable
└── scripts/
```

Keeping raw output unedited matters. When you write the post, someone will ask how you scored a scenario, and "here is the untouched JSON" is the answer.

---

## Phases

### Phase 0 — Rubric first

Write `analysis/rubric.md` before deploying anything. Define what counts as:

- **Detected** — tool names the escalation path, or names the specific permission and the reachable target
- **Partial** — tool surfaces the risky permission but not the path or the target
- **Missed** — nothing in the output would lead a reviewer to the path
- **False positive** — tool reports a path you manually confirm does not work

Also decide: are you grading default invocation, or best-effort with flags? Default is more honest and more useful to a reader. Note any flag you had to add.

### Phase 1 — Deploy the lab

Bishop Fox's `iam-vulnerable` (Terraform). Deploy, then enumerate what it actually created rather than trusting the README's scenario list. Have Claude Code produce `analysis/scenarios.md` from the Terraform state and the AWS API: one row per scenario, with the principal, the permission that enables it, and the intended target.

You want this list generated from reality, not from documentation, because that's the list the tools get graded against.

### Phase 2 — Run the tools

- **cloudfox** (Go, actively maintained). `permissions`, `principals`, `role-trusts`, `iam-simulator` at minimum.
- **PMapper** (Python, NCC Group). `graph create`, then `query` and `argquery` for the privesc preset. Expect friction: the project has been dormant since 2022, so a modern Python is likely to fight you on dependencies. Pin the environment, note the version, and record what you had to do to make it run. That's a legitimate finding in itself and it belongs in the post.

Capture everything to `raw-output/` in JSON where the tool supports it. Run each tool twice — once as the admin principal, once as a lower-privileged one — because access to the IAM API changes what these tools can see, and that difference is worth a paragraph.

### Phase 3 — Manual validation

The step that makes this credible. Pick 6–10 scenarios spanning detected, partial, and missed, and prove each one by hand with the CLI. Record the exact commands and the outcome in `analysis/validation/`.

Specifically check for the two failure directions:

- A path a tool reported that does not actually work (usually a permission boundary, an SCP-equivalent, or a condition key the tool didn't evaluate)
- A path neither tool reported that does work

The second category is where your thesis lives.

### Phase 4 — Build the matrix

Scenario rows, tool columns, rubric grades, with a link to the raw output and the validation note for each cell. Claude Code can assemble this from the artifacts; you check it.

### Phase 5 — The OIDC scenario (your differentiator)

Note that IAM Vulnerable does not ship a web-identity / OIDC trust-chaining scenario. You will need to author it: a GitHub Actions OIDC provider, a role with a loose `sub` condition or a wildcard, and a chain from that role to something worth reaching.

This is the part you should build yourself rather than delegate, because it's the novel claim in the post and you'll be defending it. It's also directly the same problem as your JFrog OIDC pilot at work, which is why both stories reinforce each other.

Do this after the matrix exists, not before. The matrix is what gives the OIDC finding context.

---

## CLAUDE.md draft

Paste something like this into the repo so the new session starts oriented:

```markdown
# Project context

Benchmarking AWS IAM privilege-escalation analysis tools against a known-
vulnerable environment, to produce a per-scenario detection matrix for a
public writeup.

## Environment
- Dedicated personal AWS sandbox account. Profile: personal. The account ID
  is never written into this repo - it lives in ./.account-id, which is
  gitignored, and redact.sh substitutes it out of raw-output/ before commit.
- ALWAYS use --profile personal or an explicit AWS_PROFILE.
- Other AWS profiles on this machine are work accounts. Never use them.
  Confirm sts get-caller-identity before any AWS call.
- Lab is Bishop Fox iam-vulnerable, deployed via Terraform in ./lab.

## Tools under test
- cloudfox (Go)
- PMapper (Python, dormant since 2022, expect dependency friction)
- iamwho (my own tool) — NOT part of this phase, added later

## Method
1. Rubric in analysis/rubric.md is written first and does not change
   after tool runs begin.
2. Scenario list in analysis/scenarios.md is generated from Terraform
   state and the AWS API, not from the lab's README.
3. All tool output goes to raw-output/ unedited. Never hand-edit it.
   The one exception is redact.sh, a published one-way substitution for
   the account ID and access key IDs, committed alongside its output.
4. Manual CLI validation for a sample of scenarios, recorded in
   analysis/validation/ with exact commands and outcomes.
5. Matrix assembled from those artifacts only.

## Constraints
- Never commit tfstate, access keys, or account IDs.
- Do not modify the lab's Terraform to make a tool look better or worse.
- If a tool needs a non-default flag to find something, record the flag
  and grade it separately from the default run.
- Flag any scenario where you are inferring rather than confirming.
```

That last constraint is worth keeping. The model will produce a confident-sounding matrix whether or not the evidence supports it, and you want it saying "I'm inferring here" out loud.

---

## Scope discipline

Things that are not part of this:

- Building the AI agent gateway
- Refactoring iamwho
- Adding a third or fourth tool because it seemed relevant
- Account-wide graphing
- Making the lab prettier

The deliverable is `analysis/matrix.md` plus the post. Two weekends of work if you keep it bounded, considerably more if you don't.
