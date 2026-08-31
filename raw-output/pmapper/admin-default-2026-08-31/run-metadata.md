# Run metadata

Required by rubric §5.

> **This run produced no graph and no findings.** `graph create` terminated on an
> unhandled exception, and all seven subsequent commands failed because the graph
> it was supposed to write does not exist. Details under **Outcome**. Nothing
> here is a grade; rubric §4.7 governs how a crash is scored, and that is Phase 4.

## Identity

- **Tool:** PMapper (Principal Mapper)
- **Tool version:** `1.1.5`. PMapper has no `--version` flag and no `version`
  subcommand — `pmapper --version` exits with
  `unrecognized arguments: --version` — so the version is from the installed
  distribution metadata.
- **Tool commit hash:** `d5136ff120d774338a68c1e073f6bcf7199154ee` (upstream tag
  `v1.1.5`, `nccgroup/PMapper`). `master` HEAD at install time was
  `91d2e60102bdadf346d77b60d90ddaa4a678f037`, dated **2022-02-03** — one commit
  past the tag, and 4.5 years stale as of this run.
- **Install method:** `pip install principalmapper`, the README's documented
  path, into a dedicated venv at `tools/pmapper-venv/`. PyPI artifact
  `principalmapper-1.1.5-py3-none-any.whl`, uploaded 2022-01-13, SHA-256
  `5145e172b2607885b50abf66221cc9e5bea318501b315196620a5a5bae798594`.
- **Python version:** **3.9.25** (Homebrew `python@3.9`).
- **Dependency pinning required:** **the interpreter, not the libraries.**

  PMapper does not run on any Python this machine shipped with. On Python 3.11.14
  the install succeeds silently and then every invocation dies at import:

  ```
  File ".../principalmapper/util/case_insensitive_dict.py", line 34, in <module>
      from collections import Mapping, MutableMapping, OrderedDict
  ImportError: cannot import name 'Mapping' from 'collections'
  ```

  Those ABC aliases were removed in Python 3.10. The line is unchanged on
  upstream `master`. `setup.py` declares `python_requires='>=3.5, <4'` and the
  README says "Python 3.5+", so `pip` installs happily on 3.10–3.13 and the
  incompatibility surfaces only at runtime. The real ceiling is 3.9.

  No dependency *version* had to be held back — `setup.py` pins nothing and
  current releases work. Resolved set on 3.9:

  ```
  botocore==1.42.97      jmespath==1.1.0        packaging==26.3
  principalmapper==1.1.5 pydot==4.0.1           pyparsing==3.3.2
  python-dateutil==2.9.0.post0                  six==1.17.0
  urllib3==1.26.20
  ```

  Homebrew's `python@3.9` is itself deprecated — *"deprecated upstream! It will
  be disabled on 2026-10-15."* The tool source was **not** patched; full
  reasoning in `analysis/tool-install.md`.

## Environment under test

- **iam-vulnerable commit hash:** `0f298666f9b7cfa01488b86912afdb211773188a`
- **tfvars used:** `aws_local_profile = "personal"`; every other variable at its
  default, so `aws_assume_role_arn` falls back to the caller and all 45 lab roles
  trust `user/iamadmin`. Full record: `raw-output/lab-deployment.md`.
- **lab-oidc applied at time of run:** **no.** `lab-oidc/` holds only its README.
- **Account:** 17 enabled regions. `me-south-1` is `not-opted-in` — this matters,
  see Outcome.

## Run conditions

- **Context:** `admin` — `user/iamadmin`, `AdministratorAccess`.
- **Flagset:** `default`
- **Exact commands**, in order, each captured to its own pair of files under
  `output/`:

  | # | Command | Exit |
  |---|---|---:|
  | 01 | `pmapper --profile personal graph create` | **1** |
  | 02 | `pmapper --profile personal graph display` | 1 |
  | 03 | `pmapper --profile personal graph list` | 0 |
  | 04 | `pmapper --profile personal query "preset privesc *"` | 1 |
  | 05 | `pmapper --profile personal argquery --preset privesc --principal "*"` | 1 |
  | 06 | `pmapper --profile personal analysis --output-type text` | 1 |
  | 07 | `pmapper --profile personal analysis --output-type json` | 1 |
  | 08 | `pmapper --profile personal visualize --filetype dot` | 1 |

  This is the command set CLAUDE.md names for Phase 2 — *"`graph create`, then
  `query` and `argquery` for the privesc preset"* — plus `analysis`, PMapper's
  own issue report, and `visualize`.

  **On the two non-default flags, per rubric §4.2.** Neither changes what PMapper
  looks for:

  | Flag | Why | Detection effect |
  |---|---|---|
  | `--profile personal` | selects the sandbox profile; required by CLAUDE.md | none |
  | `--output-type json` (07) | rubric §5 asks for JSON where the tool supports it; `text` is the default and was captured separately as 06 | none — serialisation only |

  `--filetype dot` on 08 was chosen over the `svg` default because `dot` needs no
  Graphviz binary, so a missing system dependency could not be confused with a
  tool failure. It never got the chance to matter.

  **Detection-affecting flags deliberately NOT used:** `-s/--skip-admin` (admins
  were not excluded from queries), `-u/--include-unauthorized`, `--scps`,
  `--with-resource-policy`, `--session-policy`, `--only-privesc` and
  `--with-services` on `visualize`.

- **Timestamp (UTC, start):** `2026-08-31T01:23:01Z` (end `2026-08-31T01:28:57Z`).
- **Caller identity** (post-redaction):

  ```json
  {
      "UserId": "AIDAZV7NGMXUIHN6FVLRB",
      "Account": "000000000000",
      "Arn": "arn:aws:iam::000000000000:user/iamadmin"
  }
  ```

### Ordering relative to cloudfox

cloudfox ran first, and finished at `2026-08-31T01:21:02Z`, ~2 minutes before
this run started. At that time no PMapper data had ever existed on this machine,
which cloudfox recorded in its own output (`No pmapper data found for this
account`). See the cloudfox run metadata for why that ordering was chosen and for
what cloudfox's documentation says about the dependency.

## Outcome

- **Exit status:** `1` on `graph create`, and `1` on six of the seven commands
  after it. Only `graph list` returned `0`, and it returned an empty list.

### `graph create` terminated on an unhandled connect timeout

PMapper gathered all the IAM data successfully, reached the edge-generation
phase, and then died on the **first** edge check:

```
2026-08-30 19:23:19-0600 | Determining which principals have administrative privileges
2026-08-30 19:23:20-0600 | Initiating edge checks.
2026-08-30 19:23:20-0600 | Generating Edges based on EC2 Auto Scaling.
2026-08-30 19:23:21-0600 | Unable to search region af-south-1 for launch configs. ... Continuing.
        [14 more disabled regions handled the same way]
2026-08-30 19:23:46-0600 | Unable to search region me-central-1 for launch configs. ... Continuing.
```

then, on stderr:

```
botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint URL:
"https://autoscaling.me-south-1.amazonaws.com/"
```

**Call site**, from the traceback in `output/01-graph-create.stderr.txt`:

```
principalmapper/graphing/graph_cli.py:179       process_arguments
principalmapper/graphing/graph_actions.py:39    create_new_graph
principalmapper/graphing/gathering.py:84        create_graph
principalmapper/graphing/edge_identification.py:63  obtain_edges
principalmapper/graphing/autoscaling_edges.py:60    return_edges
```

**Cause, confirmed in the installed source.** `autoscaling_edges.py` wraps the
per-region call in a handler written for exactly this situation, but catches only
`ClientError`:

```python
except ClientError as ex:
    logger.warning('Unable to search region {} for launch configs. The region may be disabled, or the error may '
                   'be caused by an authorization issue. Continuing.'.format(as_client.meta.region_name))
```

`me-south-1` is `not-opted-in` for this account, like the 15 regions PMapper
skipped cleanly. The difference is the failure mode, not the region status: the
others returned an API-level error, which is a `ClientError` and is caught; the
`me-south-1` endpoint did not answer at all, and `ConnectTimeoutError` is a
`BotoCoreError`, not a `ClientError`, so it propagates out of `return_edges`,
out of `obtain_edges`, and terminates the process.

**Consequence:** the graph is never serialised. All IAM data collected in the
preceding 20 seconds is discarded, and the whole run is lost to one unreachable
regional endpoint on the first of PMapper's edge checks.

### Every downstream command failed for the same reason

Commands 02 and 04–08 each ended in the same 14-line traceback:

```
File ".../principalmapper/common/graphs.py", line 132, in create_graph_from_local_disk
    raise ValueError('Did not find file at: {}'.format(rootpath))
ValueError: Did not find file at: /Users/.../com.nccgroup.principalmapper/000000000000
```

`graph list` (03) exited `0` and printed an empty list, which is the correct
answer and also the only confirmation in the output surface that nothing exists:

```
Account IDs:
---
```

PMapper's storage directory
`~/Library/Application Support/com.nccgroup.principalmapper/` was created and is
**empty** — no account subdirectory, no `nodes.json`, no graph.

- **Crashed / skipped principals (rubric §4.7):** **not "some principals" — the
  entire run.** No principal was evaluated for edges, no query executed, no
  analysis produced. Every scenario in `analysis/scenarios.md` is affected, and
  §4.7 requires these to be tallied as crash-Ms separately from detection-Ms:
  *"A tool that cannot run is a maintenance finding; a tool that runs and misses
  is a detection finding."* This run is entirely the former.

- **Total paths reported (rubric §4.8 — the FP denominator): 0.**

  Zero by crash, not by detection, and the distinction has to survive into the
  matrix. An FP denominator of 0 does not mean PMapper reported nothing false; it
  means PMapper reported nothing at all, so no false-positive statement about
  PMapper can be made from this run. Any FP claim in the writeup must come from a
  run that produced output.

  | Surface | Count |
  |---|---:|
  | privesc paths (`query "preset privesc *"`) | 0 — command failed |
  | privesc paths (`argquery --preset privesc`) | 0 — command failed |
  | issues (`analysis`) | 0 — command failed, both output types |
  | graph nodes / edges | 0 — no graph written |
  | accounts known to PMapper (`graph list`) | 0 |

### Is this reproducible?

**Unknown — this is a single observation, and it is recorded as one.** The
immediate trigger is environmental: a TCP connect timeout to one opt-in-disabled
region's endpoint, which may or may not recur. The *defect* is not
environmental — the `except ClientError` above will fail to catch a transport
timeout every time it happens, and it sits in the first edge check of eight, on
the only code path that builds the graph.

Two things follow, and both are decisions for the next session rather than calls
made here:

1. **This run stands as the record of the default admin-context PMapper
   invocation, whatever comes next.** It is not deleted or overwritten. If a
   retry succeeds, this directory remains the first attempt.
2. **A retry needs a directory of its own** and a note saying which attempt it
   is. Rubric §5.2's "no unconditional flagged run" rule is about detection
   flags; a retry of a crashed default run is not a flagged run. Whether to retry
   as-is, or to record the crash as the headline result, changes what the PMapper
   column in the matrix means, and that is not a decision to make silently.

### Retried, 2026-08-31 — `../admin-flagged-2026-08-31/`

**This directory remains the record of the default invocation.** The retry is
filed separately and disclosed as non-default.

The workaround was PMapper's own `graph create --include-regions`, scoped to the
account's 17 opted-in regions. That is the least invasive option available: it is
a native, documented flag, no config or environment-level restriction was needed,
and **the tool source was not patched** — the installed package is still
byte-identical to the published wheel.

The flag removes the unreachable endpoint before a client is constructed for it,
so the unhandled `ConnectTimeoutError` is never raised. It is detection-neutral
by construction: AWS does not permit resource creation in a region the account
has not enabled, so no edge can exist in any excluded region.

With that flag `graph create` completed in 1m48s with an empty stderr, and
PMapper reported **32 escalation paths**, 17 administrative principals, a
94-node / 307-edge graph and 8 `analysis` findings — against **0** from this
default run.

The gap between the two is the finding: PMapper's default invocation against this
account does not complete, and every PMapper number in the benchmark exists only
because the tool was given a flag to route around its own unhandled exception.

- **Redaction applied:** `./redact.sh raw-output/pmapper`, run
  **2026-08-31T01:39 UTC**. Result: *"redacted 18 file(s) and renamed 0 path(s)"*,
  then *"check passed: 18 file(s), no account ID or access key IDs in contents or
  path names"*. No path needed renaming here because PMapper wrote no files —
  the account ID appeared only inside the tracebacks. `redact.sh` covers path names as well as file contents from
  2026-08-31 (rubric §9 amendment of that date); PMapper's own error messages
  print its storage path, which contains the account ID, so this directory
  depends on that widening.

## Files in this run directory

- `console.txt` — driver transcript: the caller-identity check, then each
  command with its start time, exit status and output line counts.
- `output/NN-<slug>.txt` — that command's stdout, unedited.
- `output/NN-<slug>.stderr.txt` — that command's stderr, unedited. For this run
  the stderr files carry the substance: `01-graph-create.stderr.txt` is the
  94-line traceback ending in the connect timeout, and the six files of 14 lines
  each are the missing-graph failures.

PMapper writes no output files of its own; everything it produces goes to stdout
or stderr, which is why the capture is structured this way rather than pointing
the tool at an output directory.
