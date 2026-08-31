# Run metadata

Required by rubric §5. This is the `limited` context of rubric §5.1, run as the
AWS-managed `SecurityAudit` policy.

Per §5.1 this run **is not graded per scenario**. It is a qualitative delta.
Nothing below is a grade.

> **Comparison baseline: `../admin-flagged-2026-08-31/`, not
> `../admin-default-2026-08-31/`.** This run uses the same non-default
> `--include-regions` allow-list as that run, so the two are directly comparable.
> The default-invocation admin run crashed and produced nothing, so it is not a
> usable baseline for a privilege delta — comparing against it would credit the
> `SecurityAudit` context with a 32-path "gain" that is really just the
> difference between a run that completed and one that did not.

## Identity

Identical to both admin runs — same venv, same wheel, nothing reinstalled, no
source modification.

- **Tool:** PMapper (Principal Mapper)
- **Tool version:** `1.1.5` (no `--version` flag; from distribution metadata)
- **Tool commit hash:** `d5136ff120d774338a68c1e073f6bcf7199154ee` (tag `v1.1.5`);
  `master` HEAD `91d2e60102bdadf346d77b60d90ddaa4a678f037`, 2022-02-03
- **Install method:** `pip install principalmapper` into `tools/pmapper-venv/`
- **Python version:** **3.9.25** (Homebrew `python@3.9`)
- **Dependency pinning required:** the interpreter, not the libraries. See
  `analysis/tool-install.md`.
- **Graphviz:** 15.1.1, installed 2026-08-31 for `visualize`. Absent during the
  admin runs, which is why `visualize` failed there and succeeds here.

## The limited principal

Same purpose-made principal as the cloudfox `securityaudit` run —
`user/benchmark-securityaudit`, created 2026-08-31T01:47:41Z with only
`arn:aws:iam::aws:policy/SecurityAudit` attached. Creation details, read-only
verification and teardown commands are in
`../../cloudfox/securityaudit-default-2026-08-31/run-metadata.md`; they are not
repeated here.

**It did not exist during the admin runs.** It is benchmark apparatus, not a
scenario row, and must be excluded from any denominator. Its effect on this run
is isolated below.

## Environment under test

- **iam-vulnerable commit hash:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **tfvars used:** `aws_local_profile = "personal"`, everything else default.
- **lab-oidc applied at time of run:** **no.**
- **PMapper data on disk before this run:** **none** — the `ls` proving it is in
  `console.txt`. The admin graph was archived to
  `../admin-flagged-2026-08-31/pmapper-graph/` and deleted first, because PMapper
  stores one graph per account and this run overwrites it.

## Run conditions

- **Context:** `limited` (`SecurityAudit`), directory-named `securityaudit`.
- **Flagset:** `default` in the directory name, but see the flag note below.

- **The `--include-regions` flag is carried over deliberately.** `graph create`
  was run with the identical 17-region allow-list used by
  `admin-flagged-2026-08-31`:

  ```
  ap-northeast-1 ap-northeast-2 ap-northeast-3 ap-south-1 ap-southeast-1
  ap-southeast-2 ca-central-1 eu-central-1 eu-north-1 eu-west-1 eu-west-2
  eu-west-3 sa-east-1 us-east-1 us-east-2 us-west-1 us-west-2
  ```

  — the account's opted-in set. **This run is therefore not a default invocation
  of PMapper either**, and the directory name's `default` refers to the flagset
  convention rather than to a genuinely unflagged run. Two reasons for carrying
  the flag rather than dropping it:

  1. **Comparability.** A privilege delta is only meaningful if the flag set is
     held constant. Rubric §5.1 requires the limited context to be "over the same
     command set as the admin run", and the admin run that produced results used
     this flag.
  2. **It would likely have crashed the same way.** The unhandled
     `ConnectTimeoutError` in `autoscaling_edges.py` is not privilege-dependent.

  The flag is detection-neutral by construction — AWS does not permit resource
  creation in a region the account has not enabled, so no edge can exist in an
  excluded region. Full argument in the admin-flagged run's metadata.

- **Exact commands**, identical to the admin-flagged run except the profile, plus
  command 09 which that run gained retroactively once Graphviz was installed:

  | # | Command | Exit |
  |---|---|---:|
  | 01 | `pmapper --profile benchmark-securityaudit graph create --include-regions <17 regions>` | 0 |
  | 02 | `pmapper --profile benchmark-securityaudit graph display` | 0 |
  | 03 | `pmapper --profile benchmark-securityaudit graph list` | 0 |
  | 04 | `pmapper --profile benchmark-securityaudit query "preset privesc *"` | 0 |
  | 05 | `pmapper --profile benchmark-securityaudit argquery --preset privesc --principal "*"` | 0 |
  | 06 | `pmapper --profile benchmark-securityaudit analysis --output-type text` | 0 |
  | 07 | `pmapper --profile benchmark-securityaudit analysis --output-type json` | 0 |
  | 08 | `pmapper --profile benchmark-securityaudit visualize --filetype dot` | 0 |
  | 09 | `pmapper --profile benchmark-securityaudit visualize --filetype svg` | 0 |

  **Flags NOT used**, same list as the admin runs: `-s/--skip-admin`,
  `-u/--include-unauthorized`, `--scps`, `--with-resource-policy`,
  `--session-policy`, `--ignore-orgs`, `--include-services`/`--exclude-services`,
  `--only-privesc`, `--with-services`.

- **Timestamp (UTC, start):** `2026-08-31T01:53:58Z` (end `2026-08-31T01:55:54Z`).
  `graph create` took 1m49s, against 1m48s for the admin-flagged run.
- **Caller identity** (post-redaction):

  ```json
  {
      "UserId": "AIDAZV7NGMXUPAGKPKUG3",
      "Account": "000000000000",
      "Arn": "arn:aws:iam::000000000000:user/benchmark-securityaudit"
  }
  ```

## Outcome

- **Exit status:** `0` on **all nine commands**. **Every stderr file is 0 bytes.**
  Nothing failed, nothing warned.

### Total paths reported (rubric §4.8)

**Escalation paths reported: 32** — the same number as the admin-flagged run.

| Unit | admin-flagged | SecurityAudit | delta |
|---|---:|---:|---:|
| **escalation paths** | **32** | **32** | **0** |
| escalation hop lines | 33 | 33 | 0 |
| principals asserted administrative | 17 | 17 | 0 |
| `analysis` findings | 8 | 8 | 0 |
| graph nodes | 94 | 95 | +1 |
| graph edges | 307 | 311 | +4 |
| graph groups | 3 | 3 | 0 |
| tracked policies | 59 | 60 | +1 |

### The delta: PMapper lost nothing under SecurityAudit

- **`04-query-preset-privesc.txt` is byte-identical between the two contexts.**
  Not equivalent — identical. Same 32 paths, same 17 administrative principals,
  same ordering, same 10520 bytes. Set difference in both directions is empty.
- `05-argquery` likewise, and it remains byte-identical to `04` within this run
  as well.
- **`06-analysis-text.txt` differs in exactly one line**, the timestamp:
  `Date and Time: 2026-08-31T01:41:34…` → `…T01:55:50…`. All 324 other lines
  match. Same 8 findings, same titles, same severities, same descriptions.
- The graph grew by exactly the new principal and the edges into it.

**The +4 edges are all inbound to the new principal**, and none creates a path:

```
role/privesc4-CreateAccessKey-role  -> user/benchmark-securityaudit | can create access keys to authenticate as
user/privesc4-CreateAccessKey-user  -> user/benchmark-securityaudit | can create access keys to authenticate as
role/privesc5-CreateLoginProfile-role -> user/benchmark-securityaudit | can set the password to authenticate as
user/privesc5-CreateLoginProfile-user -> user/benchmark-securityaudit | can set the password to authenticate as
```

`benchmark-securityaudit` is not an administrative principal — `is_admin` counts
17 in both graphs — so these edges reach a non-admin target and the privesc
preset, which reports paths to administrative principals, is unchanged. The
apparatus is visible in the graph and absent from the results, which is the
behaviour it needed to have.

### Nothing failed differently under reduced privilege

Unlike cloudfox, PMapper produced **no errors at all** in either context: every
stderr file is empty in this run, and in the admin-flagged run every stderr was
empty except `visualize` before Graphviz existed. There is no PMapper equivalent
of the cloudfox finding where Glue's `InternalFailure` under admin became
`AccessDeniedException` under `SecurityAudit` — PMapper does not call the Glue
list APIs that cloudfox does.

`SecurityAudit` grants everything `graph create` needs: it read all 95
principals, all attached and inline policies, group memberships, access keys, MFA
devices, and every service the eight edge checks query. `graph create` printed
the same "region may be disabled" warnings as under admin, for the same regions.

**This bears on pre-registered prediction §8.2** — *"The `limited`
(`SecurityAudit`) run shows a materially reduced output surface for both tools,
qualitatively."* For PMapper the reduction is not merely small; the primary
output is bit-for-bit the same file. Combined with the cloudfox result (all 94
shared principals field-identical, `permissions.json` identical excluding the new
principal), **neither tool shows a materially reduced output surface under
`SecurityAudit`.** Whether that falsifies §8.2 is a Phase 4 judgement; it is
recorded here as the observation.

Worth carrying into that judgement: §5.1 already anticipates this — *"a different
limited principal changes the delta … the result is not 'tools degrade by X under
low privilege', it is 'tools degrade this way under this policy.'"* The finding
here is about `SecurityAudit` specifically, which turns out to grant enough IAM
read access that neither tool notices the difference.

- **Crashed / skipped principals (rubric §4.7):** **none.** All 95 principals
  were read and evaluated.

- **Redaction applied:** `./redact.sh raw-output/pmapper`, run
  **2026-08-31T01:58 UTC**, over all three PMapper run directories. Result:
  *"redacted 71 file(s) and renamed 6 path(s)"*, then *"check passed: 71 file(s),
  no account ID or access key IDs in contents or path names"*. The six renamed
  paths are the archived graph directories and the `visualize` output files, all
  of which PMapper names after the account ID.

## Files in this run directory

- `console.txt` — driver transcript: caller identity, the attached-policy check,
  the pre-run proof that PMapper's storage was empty, then each command.
- `output/NN-<slug>.txt` / `.stderr.txt` — stdout and stderr per command,
  unedited. All stderr files are empty.
- `pmapper-graph/000000000000/` — the graph PMapper built and that commands 02–09
  read: `metadata.json` plus `graph/{nodes,edges,groups,policies}.json`. Archived
  because PMapper stores one graph per account and any later run overwrites it.
- `figure/` — the `.dot` and `.svg` `visualize` produced. For figures, not for
  grading.
