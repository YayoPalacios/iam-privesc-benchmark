# Tool installation record — Phase 2

Rubric §5 requires tool version, commit hash, and for PMapper the Python version
and any dependency pinning needed to make it run. This file is the narrative
version of those fields; the per-run copies live in each
`raw-output/<tool>/<context>-<flagset>-<date>/run-metadata.md`.

Installed 2026-08-31 (UTC) on macOS 15 / Darwin 24.6.0, arm64.

Both tools are installed under `./tools/`, which is gitignored. Nothing here is
committed as a binary; the identifying hashes below are what makes the install
reproducible.

---

## cloudfox

| | |
|---|---|
| Version | `2.0.5` (self-reported by `cloudfox --version`) |
| Release | [`v2.0.5`](https://github.com/BishopFox/cloudfox/releases/tag/v2.0.5), published 2026-05-26 |
| Commit | `ba4ff4701a537750f0aa11b1fb0ffa1f545cc000` |
| Annotated tag object | `ad787c28cfdc57df48edbaa7924b976a28078e42` |
| Install method | Official release binary — `cloudfox-macos-arm64.zip` from GitHub Releases |
| Archive SHA-256 | `04c13e576953d46501ad20885c109a740014391baa40c168703a0e7cc470d060` |
| Binary SHA-1 | `ced12705cb84606d97dc41c83ad187725f0d44a0` |
| Installed at | `tools/bin/cloudfox` |

The release ships its own `sha1sum.txt`; the extracted binary's SHA-1 matches it.
The commit hash is the tag `v2.0.5` dereferenced through its annotated tag object
via the GitHub API, since the binary does not embed one.

### Friction: none

Recorded because the contrast with PMapper is part of the finding, not because
there is anything to report.

- No Go toolchain is required and none is installed on this machine. The binary
  is the documented install path.
- The extracted binary carried no `com.apple.quarantine` attribute — only
  `com.apple.provenance` — so no Gatekeeper workaround was needed. (`xattr -c`
  was run on the installed copy anyway; for this purpose it was a no-op.)
- `--version` worked on first invocation.

Elapsed: under a minute, download included.

---

## PMapper (Principal Mapper)

| | |
|---|---|
| Version | `1.1.5` |
| Upstream | [`nccgroup/PMapper`](https://github.com/nccgroup/PMapper) |
| Commit (tag `v1.1.5`) | `d5136ff120d774338a68c1e073f6bcf7199154ee` |
| Commit (`master` HEAD at install time) | `91d2e60102bdadf346d77b60d90ddaa4a678f037`, dated **2022-02-03** |
| Install method | `pip install principalmapper` — the README's documented path |
| PyPI artifact | `principalmapper-1.1.5-py3-none-any.whl`, uploaded **2022-01-13** |
| Wheel SHA-256 | `5145e172b2607885b50abf66221cc9e5bea318501b315196620a5a5bae798594` |
| **Python version used** | **3.9.25** (Homebrew `python@3.9`) |
| Installed at | `tools/pmapper-venv/` |

PMapper has no `--version` flag and no `version` subcommand; `pmapper --version`
exits with `unrecognized arguments: --version`. The version above is from the
installed distribution metadata.

`master` is 4.5 years stale as of this run, and is one commit past the `v1.1.5`
tag. Nothing relevant has changed upstream since the release.

### Friction: the package does not run on any Python this machine shipped with

**Attempt 1 — Python 3.11.14** (Homebrew, this machine's default `python3`).

`pip install principalmapper` **succeeded**, resolving `botocore 1.43.83`,
`pydot 4.0.1`, `packaging 26.3`, `python-dateutil 2.9.0`, `urllib3 2.7.0`. There
is no warning at install time. The failure is at first import:

```
$ tools/pmapper-venv/bin/pmapper --version
Traceback (most recent call last):
  File ".../bin/pmapper", line 3, in <module>
    from principalmapper.__main__ import main
  ...
  File ".../principalmapper/util/case_insensitive_dict.py", line 34, in <module>
    from collections import Mapping, MutableMapping, OrderedDict
ImportError: cannot import name 'Mapping' from 'collections'
```

The ABC aliases in `collections` were deprecated in Python 3.3 and **removed in
Python 3.10**. PMapper imports them at module scope on the path every subcommand
takes, so the tool cannot start at all — not degrade, not warn, not run with a
reduced feature set. Every invocation is this traceback.

**This is not fixed upstream.** `case_insensitive_dict.py` on `master` still
carries the identical line, fetched at install time and quoted here.

**The package metadata is wrong about its own requirement.** `setup.py` declares
`python_requires='>=3.5, <4'` and the README says *"Principal Mapper is built
using the `botocore` library and Python 3.5+."* Both are false above 3.9. Because
the declared range is satisfied, `pip` installs without complaint on 3.10–3.13
and the user discovers the incompatibility only by running the tool. The real
supported ceiling is **Python 3.9**.

**Attempt 2 — Python 3.9.25.** Installed via `brew install python@3.9`, venv
rebuilt on it, `pip install principalmapper` again. `pmapper --help` works and
all seven subcommands (`graph`, `orgs`, `query`, `argquery`, `repl`, `visualize`,
`analysis`) are present.

### What had to be pinned

**The interpreter, not the libraries.** This distinction matters for the writeup.

- `setup.py` pins no dependency versions at all
  (`install_requires=['botocore', 'packaging', 'python-dateutil', 'pydot']`).
  Current releases of all four resolve and work — no dependency needed to be held
  back. The 2022 code is fine against 2026 `botocore`.
- The only pin required was **Python 3.9**, and it had to be installed for the
  purpose.

Resolved dependency set on Python 3.9, for reproduction:

```
botocore==1.42.97
jmespath==1.1.0
packaging==26.3
principalmapper==1.1.5
pydot==4.0.1
pyparsing==3.3.2
python-dateutil==2.9.0.post0
six==1.17.0
urllib3==1.26.20
```

### The fix has a deadline

Homebrew's `python@3.9` is itself deprecated:

> Deprecated because it is deprecated upstream! It will be disabled on
> **2026-10-15**.

Python 3.9 reached upstream end-of-life in October 2025. So the only interpreter
that runs PMapper as shipped is one Homebrew stops distributing about six weeks
after this run. A reader reproducing this benchmark later will have to source a
3.9 build some other way, or patch the tool.

### What was deliberately not done

**The source was not patched.** Changing
`from collections import Mapping` to `from collections.abc import Mapping` is a
one-line fix and would have let PMapper run on 3.13. It was rejected: the
benchmark grades the tool as it ships, and a patched PMapper is not the artifact
a reader gets from `pip install principalmapper`. Installing an old interpreter
leaves the tool under test byte-identical to the published release.

This is recorded as a decision rather than a footnote because it is reversible —
if the writeup would rather report a patched-modern-Python run, the raw output on
disk is from the unmodified tool and the alternative can be added as a separate
run directory.

---

## Cross-tool note relevant to the runs

cloudfox v2.0.5 ships two modules that **consume PMapper's data if it is present
on disk**: `aws pmapper` ("Looks for pmapper data for the account and builds a
PrivEsc graph in golang if it exists") and `aws cape`.

To keep the two tools independent, **the cloudfox run was executed first, before
any `pmapper graph create` had ever run on this machine.** Absence of PMapper
data was verified immediately beforehand: both
`~/.local/share/principalmapper` and
`~/Library/Application Support/com.nccgroup.principalmapper` did not exist.

cloudfox's own privesc findings in that run are therefore its own. This is
recorded in the cloudfox run metadata as well, because a later reader looking at
a `pmapper` section in cloudfox output needs to know which state it was produced
in.
