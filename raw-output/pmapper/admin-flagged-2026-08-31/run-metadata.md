# Run metadata

Required by rubric §5.

> **This is a retry of a crashed run, and it is not a default invocation.**
> The default-invocation record is `../admin-default-2026-08-31/`, where
> `graph create` terminated on an unhandled connect timeout and produced nothing.
> That directory stands; this one does not replace it. Every result below exists
> only because PMapper was given a non-default flag to route around its own
> unhandled exception, and that qualification travels with these numbers.

## Identity

Identical to the default run — same binary, same venv, nothing reinstalled or
patched between the two.

- **Tool:** PMapper (Principal Mapper)
- **Tool version:** `1.1.5` (from distribution metadata; PMapper has no
  `--version` flag)
- **Tool commit hash:** `d5136ff120d774338a68c1e073f6bcf7199154ee` (tag `v1.1.5`).
  `master` HEAD `91d2e60102bdadf346d77b60d90ddaa4a678f037`, dated 2022-02-03.
- **Install method:** `pip install principalmapper` into `tools/pmapper-venv/`.
  Wheel SHA-256
  `5145e172b2607885b50abf66221cc9e5bea318501b315196620a5a5bae798594`.
- **Python version:** **3.9.25** (Homebrew `python@3.9`)
- **Dependency pinning required:** the interpreter, not the libraries. See
  `analysis/tool-install.md` and the default run's metadata.
- **Source modifications:** **none.** The installed package is byte-identical to
  the published wheel. See the workaround section below.

## Environment under test

- **iam-vulnerable commit hash:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **tfvars used:** `aws_local_profile = "personal"`, everything else default.
- **lab-oidc applied at time of run:** **no.**
- **PMapper data on disk before this run:** **none.** The console captures
  `ls` of `~/Library/Application Support/com.nccgroup.principalmapper/` showing
  an empty directory — confirming the default run wrote no graph, and that this
  graph was built from scratch rather than inherited.
- **Account regions:** 17 opted-in, 17 not-opted-in.

## The workaround: option 1, PMapper's own region allow-list

Preference order was: a native region-scoping option, then config or
environment-level region restriction, then a minimal patch to the `except`
clause. **The first option was available and sufficient. Options 2 and 3 were
never reached, and nothing was patched — so there is no diff to commit.**

`pmapper graph create` exposes region scoping natively:

```
--include-regions [REGION ...]
      An allow-list of regions to pull data from, cannot be combined with
      --exclude-regions, the `global` region is always included
--exclude-regions [REGION ...]
      A deny-list of regions to pull data from, ...
```

These feed `botocore_tools.get_regions_to_search(session, service, allow, deny)`
— the same function `autoscaling_edges.py:52` calls to build the client list that
crashed the default run. Restricting the allow-list removes the unreachable
endpoint before a client is ever constructed for it, so the unhandled
`ConnectTimeoutError` never has a chance to be raised.

### Why the allow-list rather than `--exclude-regions me-south-1`

The deny-list form is a smaller textual delta and was rejected:

1. **It would be tuned to the observed failure.** `me-south-1` is not special —
   it is one of 17 not-opted-in regions, and it crashed because its endpoint
   timed out rather than answering. Any of the other 16 could do the same on a
   later run or at a different edge check. Excluding only the one that happened
   to fail yields a run that looks fixed and is not.
2. **It would not be reproducible.** A reader re-running this would be relying on
   16 disabled regions all failing in the catchable `ClientError` way.

The allow-list states the actual intent — look only where this account has
regions enabled — and holds regardless of which disabled endpoint misbehaves.

### Why the flag is detection-neutral

This matters more than the convenience, because a flag that changed what PMapper
can find would make this run incomparable to anything else.

**A not-opted-in region cannot contain resources.** AWS does not permit resource
creation in a region the account has not enabled, so no launch configuration, no
Lambda, no SageMaker notebook, no CloudFormation stack — nothing PMapper builds
an edge from — can exist in any of the 17 excluded regions. Excluding them cannot
remove a findable edge.

Corroborated independently: `analysis/account-baseline.md` swept all 17 **enabled**
regions directly and found compute in `us-east-1` only, plus three unused EC2 key
pairs. The lab deploys to `us-east-1` alone, hardcoded in its provider block.

So the flag changes what PMapper *reaches for*, not what it can *find*. It is
disclosed as non-default regardless, per rubric §4.2.

### This is not a rubric §5.2 flagged run

§5.2 governs flag runs performed because a default-run **M** looked
flag-fixable — flags that might change detection. This is not that. It is a
workaround for a crash that stopped the tool running at all. The directory
convention `<context>-<flagset>-<date>` offers only `default` and `flagged`, so
it is filed as `flagged`, but the two kinds of flagged run should not be pooled
in the writeup.

## Run conditions

- **Context:** `admin` — `user/iamadmin`, `AdministratorAccess`.
- **Flagset:** `flagged` — see above.
- **Exact commands**, in order:

  | # | Command | Exit |
  |---|---|---:|
  | 01 | `pmapper --profile personal graph create --include-regions <17 regions>` | 0 |
  | 02 | `pmapper --profile personal graph display` | 0 |
  | 03 | `pmapper --profile personal graph list` | 0 |
  | 04 | `pmapper --profile personal query "preset privesc *"` | 0 |
  | 05 | `pmapper --profile personal argquery --preset privesc --principal "*"` | 0 |
  | 06 | `pmapper --profile personal analysis --output-type text` | 0 |
  | 07 | `pmapper --profile personal analysis --output-type json` | 0 |
  | 08 | `pmapper --profile personal visualize --filetype dot` | **1** |

  The 17 regions, verbatim as passed: `ap-northeast-1 ap-northeast-2
  ap-northeast-3 ap-south-1 ap-southeast-1 ap-southeast-2 ca-central-1
  eu-central-1 eu-north-1 eu-west-1 eu-west-2 eu-west-3 sa-east-1 us-east-1
  us-east-2 us-west-1 us-west-2` — the output of
  `aws ec2 describe-regions`, i.e. exactly the opted-in set.

  `--include-regions` was passed to `graph create` **only**. The downstream
  commands read the stored graph and take no region argument, so they are
  byte-for-byte the same invocations as in the default run.

  **Flags NOT used, same list as the default run:** `-s/--skip-admin`,
  `-u/--include-unauthorized`, `--scps`, `--with-resource-policy`,
  `--session-policy`, `--ignore-orgs`, `--include-services`/`--exclude-services`,
  and `--only-privesc`/`--with-services` on `visualize`.

- **Timestamp (UTC, start):** `2026-08-31T01:39:43Z` (end `2026-08-31T01:41:36Z`).
  `graph create` took 1m48s and completed.
- **Caller identity** (post-redaction):

  ```json
  {
      "UserId": "AIDAZV7NGMXUIHN6FVLRB",
      "Account": "000000000000",
      "Arn": "arn:aws:iam::000000000000:user/iamadmin"
  }
  ```

## Outcome

- **Exit status:** `0` on seven of eight commands. `visualize` exited `1`; see
  below. The crash that defined the default run did not recur.

### The graph

From `output/02-graph-display.txt`:

```
Graph Data for Account:  000000000000
  # of Nodes:              94 (17 admins)
  # of Edges:              307
  # of Groups:             3
  # of (tracked) Policies: 59
```

94 nodes matches the 94 principals cloudfox enumerated independently (42 users,
52 roles).

- **Crashed / skipped principals (rubric §4.7):** **none.**
  `output/01-graph-create.stderr.txt` is empty — zero bytes — and no principal
  was reported as skipped. The 601 lines of stdout are progress logging. This is
  the cleanest run of the three so far.

  One command did fail, but it skipped no principal:

  **`visualize` (08) — missing Graphviz, an environment gap, not a tool defect.**

  ```
  FileNotFoundError: [Errno 2] "dot" not found in path.
  ```

  raised from `pydot/core.py:1833` via
  `principalmapper/visualizing/graphviz_writer.py:68`. Graphviz is a system
  binary PMapper needs but cannot install through pip, and it is not on this
  machine.

  **My flag choice failed to avoid this and I should record that plainly:** I
  chose `--filetype dot` over the `svg` default specifically so no Graphviz
  binary would be needed. That reasoning was wrong — `pydot`'s `write()` shells
  out to `dot` for *every* output format, including `dot` itself, so the
  substitution bought nothing. Either format would have failed identically here.

  **Resolved 2026-08-31, after the fact — for a figure, not for grading.**
  `brew install graphviz` (graphviz 15.1.1), then commands 08 and 09 re-run
  against the **same stored graph**, unchanged and untouched:

  | # | Command | Exit | Result |
  |---|---|---:|---|
  | 08 | `pmapper --profile personal visualize --filetype dot` | 0 | `Created file ./<account>.dot` |
  | 09 | `pmapper --profile personal visualize --filetype svg` | 0 | `Created file ./<account>.svg` |

  Both wrote to the working directory, not to a flag-specified path; they were
  moved into `figure/` in this run directory. `svg` is `visualize`'s default
  filetype and is the renderable one, which is why 09 was added.

  This is an **environment fix applied after the run**, not a re-run of the
  benchmark: commands 01–07 were not repeated, the graph was not rebuilt, and no
  count in this file changed. `visualize` renders the graph that 02–07 already
  read, so nothing in the privesc preset or `analysis` output depends on it. The
  original failing invocation and its traceback remain in `console.txt` above the
  re-run entries.

### Total paths reported (rubric §4.8 — the FP denominator)

**Escalation paths reported: 32.**

That is the count of `X can escalate privileges by accessing the administrative
principal Y:` statements in `output/04-query-preset-privesc.txt`, which is
PMapper's privesc preset — its documented answer to "what paths exist". 32
distinct escalating principals, 17 roles and 15 users.

Layered counts, so a later FP claim can name its denominator precisely:

| Unit | Count | Source |
|---|---:|---|
| **escalation paths** | **32** | `04` — `can escalate privileges by accessing…` |
| escalation hop lines | 33 | `04` — indented lines; 33 not 32 because one path is two hops |
| principals asserted administrative | 17 | `04` — `is an administrative principal`; 9 users, 8 roles |
| graph edges | 307 | `02` |
| graph nodes | 94 | `02` |
| `analysis` findings | 8 | `07` |

Targets of the 32 paths: `role/privesc-high-priv-service-role` ×22,
`user/fn2-exploitableResourceConstraint-user` ×4,
`role/fn2-exploitableResourceConstraint-role` ×2, `user/iamadmin` ×2,
`role/privesc-AssumeRole-ending-role` ×2.

The one multi-hop path is the AssumeRole chain, and PMapper prints the
intermediate hop:

```
role/privesc-AssumeRole-starting-role can escalate privileges by accessing the administrative principal role/privesc-AssumeRole-ending-role:
   role/privesc-AssumeRole-starting-role can access via sts:AssumeRole role/privesc-AssumeRole-intermediate-role
   role/privesc-AssumeRole-intermediate-role can access via sts:AssumeRole role/privesc-AssumeRole-ending-role
```

The 8 `analysis` findings, by title and PMapper's own severity: *IAM Principals
Can Escalate Privileges* (High), *Instance Profile Has Administrator Privileges*
(High), *IAM Users With Administrative Permissions But No MFA Device* (Medium),
*Administrative IAM Users Can Call Sensitive Actions Without MFA* (Medium), *IAM
Role Available to Lambda Functions Has Administrative Privileges* (Medium), *IAM
Role With Unsafe SSM Permissions* (Medium), *IAM Role Available to CloudFormation
Stacks Has Administrative Privileges* (Low), *IAM Principals with Circular
Access* (Low).

**No FP determination is made here**, and none of these counts is a grade.
Rubric §6 requires manual validation first, which is Phase 3.

### `query` and `argquery` returned byte-identical output

`output/04-query-preset-privesc.txt` and
`output/05-argquery-preset-privesc.txt` are identical (`cmp` reports no
difference; both 10520 bytes, 114 lines). `query "preset privesc *"` and
`argquery --preset privesc --principal "*"` are two interfaces onto the same
preset, and CLAUDE.md's Phase 2 instruction to run both is satisfied by either.
Recorded so that a reader does not mistake the two files for corroborating
evidence — they are one result stored twice.

### A neutral observation, offered as a count and not a grade

`grep -cE 'fp[1-5]-|privesc-permissive-role-trust|privesc-AssumeRole-start-user'`
over `04-query-preset-privesc.txt` returns **0**. None of the lab's designed
false-positive fixtures, and neither the policy-less permissive-trust role nor
the inert start user, appears anywhere in the privesc preset output. What that is
worth is a Phase 4 question against the rubric; it is recorded here only because
it is a fact about this file that a grader will want to have already been
observed before grading began.

### The stored graph was archived, then deleted from PMapper's storage

PMapper stores one graph per **account**, at
`~/Library/Application Support/com.nccgroup.principalmapper/<account-id>/`, with
no per-principal separation. The `securityaudit` context run of the same date
therefore **overwrites** this run's graph — there is no flag that keeps both.

Before that happened the graph was copied into `pmapper-graph/` in this
directory: `metadata.json` plus `graph/{nodes,edges,groups,policies}.json`,
556 KB. It is the actual artifact commands 02–09 read, so the queries in this
run are reproducible offline from it.

It was then **deleted from PMapper's storage**, for a second reason beyond the
overwrite: cloudfox reads PMapper's data from that path if it exists. Leaving it
in place would have meant the `securityaudit` cloudfox run found PMapper data
while the `admin` cloudfox run had none, and the two cloudfox runs would not have
been comparable. Clearing it keeps the only difference between them the principal.

- **Redaction applied:** `./redact.sh raw-output/pmapper`, run
  **2026-08-31T01:47 UTC**, covering both PMapper run directories together.
  Result: *"redacted 36 file(s) and renamed 0 path(s)"*, then *"check passed: 36
  file(s), no account ID or access key IDs in contents or path names"*. No path
  needed renaming: PMapper writes no files, so the account ID appeared only
  inside captured stdout.

## Files in this run directory

- `console.txt` — driver transcript: caller identity, the pre-run check that
  PMapper's storage was empty, then each command with start time, exit status and
  output line counts.
- `output/NN-<slug>.txt` / `output/NN-<slug>.stderr.txt` — stdout and stderr per
  command, unedited. All stderr files are empty except `08`.

PMapper writes no output files of its own; everything goes to stdout or stderr,
which is why the capture is structured this way.
