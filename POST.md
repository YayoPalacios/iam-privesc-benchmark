# Two AWS IAM privesc tools, one path finder

*A per-scenario detection matrix for PMapper and cloudfox — and the six rows where my ground truth was wrong.*

> I spent two weekends deploying Bishop Fox's `iam-vulnerable` into a throwaway AWS account and grading two open-source IAM privilege-escalation tools against it, using a rubric I froze before I deployed anything. The result is 344 graded cells, 19 hand-validated scenarios, and every byte of raw tool output published unedited. This is what I found — including the part where the tools were right and my scenario list was wrong.

---

## §1 — What this is

Over two weekends I deployed Bishop Fox's `iam-vulnerable` into a dedicated AWS account and ran two open-source IAM privilege-escalation tools against it: **cloudfox 2.0.5** and **PMapper 1.1.5**. I graded every scenario the lab created, by hand, against a rubric I froze before I deployed anything. The result is a 344-row grade file, 19 validation files recording exact CLI commands and their outcomes, and a per-scenario matrix. All of it is published, including the raw tool output, unedited except for a one-way account-ID substitution whose script is committed alongside the output it produced.

This is not a shootout and there is no winner. Two tools is not an ecosystem survey. One account is not a population, and each run happened once. What follows is what happened when I ran these two tools against this lab, on 2026-08-31. Where I generalise beyond that, I say so and show the reasoning.

**What I graded.** The lab applied 265 resources at commit `0f29866`, from which I derived 46 escalation mechanisms across 86 `(principal, mechanism)` rows — generated from `iam get-account-authorization-details` and per-service existence checks against the live account, not from the lab's README. Each row got a grade per tool: **Detected** if the output names the principal, the enabling permission, and the reachable target; **Partial** if it binds a risky permission to a specific principal but connects it to nothing; **Missed** if nothing in the output would point a reviewer at the path. I ran each tool in two contexts: as an administrator, and as a purpose-made user holding only the AWS-managed `SecurityAudit` policy — the policy an actual auditor or CSPM integration holds.

**Three things to know before any number.**

The lab derives from Rhino Security Labs' catalogue of AWS privilege escalation methods, and both tools were substantially built to detect that catalogue. High scores on it are the expected outcome and are not evidence of quality. The informative results are the misses, the false positives, and the rows outside the catalogue.

The lab's `aws_assume_role_arn` variable defaults to the identity that deploys it, so all 45 roles it creates name my admin user in their trust policies. In the administrator context the role graph is a star centred on one principal, and every reachability result is inflated by that. It is a property of the deployment, not of either tool.

I have my own IAM tool, `iamwho`. It is deliberately not in this benchmark — the point of running these two first was to produce a baseline I had not built around my own work. Eleven `iamwho` test fixtures were already sitting in the account when I started. I deleted them, along with the CloudFormation stack that created them, before grading. It cost me a scenario: `privesc-CloudFormationUpdateStack` became unexploitable, because the only stack in the account was my own residue. Grading a scenario as live only because the withheld tool's leftovers made it live would not have been defensible.

**What I did not test.** Runtime and behavioural detection. Cross-account and Organizations-level paths. SCPs and permission boundaries beyond what the lab deploys. Resource policies other than role trust policies. Anything requiring write access or an agent.

One further omission belongs here rather than in a footnote, because it caused the most interesting mistake I made: I never ran an `iam:SimulatePrincipalPolicy` sweep as an independent oracle. My ground truth is an inventory of declared grants, and §5 is about what that cost.

Grading is unweighted. A missed four-hop chain to account admin scores exactly what a missed single hop to a low-value target scores. Weighting would need an impact model I do not have, and inventing one after seeing the results is the specific failure the frozen rubric exists to prevent.

---

## §2 — The default invocation returns nothing

PMapper builds a directed graph of every principal in an account and the edges between them, then answers questions over it. Everything it does starts with `pmapper graph create`. I ran it with administrator credentials against the freshly applied lab:

```
$ pmapper --profile personal graph create
```

It ran for five minutes and fifty-two seconds and exited 1.

The first four minutes look healthy. It pulls users, roles, groups and policies; sorts the relationships; gathers access keys and MFA devices; determines which principals are administrative. Then it starts edge checks, beginning with EC2 Auto Scaling, which means enumerating launch configurations in every region. My account has 17 regions enabled and AWS advertises far more, so most of those calls are to endpoints the account cannot use. PMapper handles that:

```
19:23:21 | Unable to search region af-south-1 for launch configs. The region may be
           disabled, or the error may be caused by an authorization issue. Continuing.
19:23:21 | Unable to search region ap-east-1 for launch configs. ... Continuing.
19:23:22 | Unable to search region ap-east-2 for launch configs. ... Continuing.
```

Fifteen regions, fifteen warnings, fifteen times *Continuing*. Then the sixteenth:

```
botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint URL:
"https://autoscaling.me-south-1.amazonaws.com/"
```

and the process dies, through `autoscaling_edges.py:60`.

The reason is one line of exception handling. `AutoScalingEdgeChecker.return_edges` wraps its paginator in a `try` whose handler is exactly the warning printed fifteen times above:

```python
except ClientError as ex:
    logger.warning('Unable to search region {} for launch configs. The region may be
                    disabled, or the error may be caused by an authorization issue.
                    Continuing.'.format(as_client.meta.region_name))
```

Fifteen of those regions answered. They answered with an error (`AuthFailure`, or a disabled-region refusal) but they answered, and a service error that arrives over HTTP is a `botocore` `ClientError`, which the handler catches. `me-south-1` did not answer at all. A connection that never establishes raises `ConnectTimeoutError`, which descends from `BotoCoreError`, not `ClientError`, so it goes straight past the handler, out of the region loop, out of `obtain_edges`, and out of `main`.

The handler is not missing. It's there, it's deliberate, it's written for precisely this situation, and it's scoped to the wrong exception class.

What that costs is disproportionate to the cause. Auto Scaling is the **first of nine** edge checks — `autoscaling`, `cloudformation`, `codebuild`, `ec2`, `iam`, `lambda`, `sagemaker`, `ssm`, `sts` — and `obtain_edges` accumulates all nine into one list, returning it only at the end. There is no partial result and no checkpoint. The IAM data that took four minutes to collect is still in memory when the process exits, and it is never written to disk. One unreachable regional endpoint discards the entire graph.

Everything downstream depends on that file. I ran the seven other commands anyway, to record what a user actually experiences. Six of them died identically:

```
ValueError: Did not find file at: /Users/.../com.nccgroup.principalmapper/000000000000
```

`graph display`, both privilege-escalation queries, both analysis outputs, the visualiser. The seventh, `graph list`, exited 0 — and printed:

```
Account IDs:
---
```

The only command that succeeded is the one whose job is to tell you there is nothing there.

Under the rubric, a tool that errors or silently skips a principal grades **Missed** on the affected scenarios, because a reviewer gets nothing and the reason does not change that. So the default PMapper column is 86 rows of M. I tally those separately from detection misses throughout. A tool that cannot run is a maintenance finding; a tool that runs and misses is a detection finding, and blending them produces a column that misleads in both directions. What PMapper does when it *does* run is §4's subject, and it is not what this section implies.

I'm recording one observation, not a reproduction rate. Whether that particular endpoint times out again, I don't know. I saw it once and I'm reporting it once. The defect is not environmental, though. It does not depend on my network, my credentials, or my region set — any unreachable endpoint among the hundreds this loop touches produces it, and `autoscaling_edges.py` sits on the only code path that builds the graph. The line is unchanged on upstream `master`, whose HEAD is dated **2022-02-03**.

### The same shape, one altitude down

Getting to the crash took longer than the crash did.

`pip install principalmapper` succeeds on the Python this machine ships with, resolving current versions of all four dependencies without a warning. Then every invocation fails at import:

```
File ".../principalmapper/util/case_insensitive_dict.py", line 34, in <module>
    from collections import Mapping, MutableMapping, OrderedDict
ImportError: cannot import name 'Mapping' from 'collections'
```

Those aliases were deprecated in Python 3.3 and removed in **3.10**. The import is at module scope on the path every subcommand takes, so the tool does not degrade or warn. It cannot start. And `setup.py` declares `python_requires='>=3.5, <4'` while the README says "Python 3.5+", both of which are false above 3.9. Because the declared range is satisfied, `pip` installs cheerfully on 3.10 through 3.13 and you discover the incompatibility by running the tool.

For contrast, and because the contrast is the finding rather than a courtesy: cloudfox took under a minute. Download the release binary for the platform, verify the SHA-1 the release publishes, run it. No toolchain, no interpreter, no quarantine attribute. Worked on first invocation. I recorded it in the install log only because the difference matters.

The real ceiling is Python 3.9, which reached end of life in October 2025. I installed it via Homebrew, which told me:

> Deprecated because it is deprecated upstream! It will be disabled on **2026-10-15**.

Six weeks after this run, the only interpreter that runs PMapper as published is one Homebrew stops distributing.

Notably, nothing needed pinning except the interpreter. `setup.py` pins no dependency versions at all, and the 2022 code works fine against 2026 `botocore`. The rot is in one import and one metadata declaration.

I did not patch it. Changing that line to `from collections.abc import Mapping` is a one-character-class fix that would have let PMapper run on 3.13, and I rejected it: the benchmark grades the tool as it ships, and a patched PMapper is not what `pip install principalmapper` gives you. Installing an old interpreter leaves the artifact under test byte-identical to the published release.

---

## §3 — The other tool runs clean, and finds no paths, because it does not look for them

cloudfox ran without incident. One command, `cloudfox aws all-checks -p personal -y`, produced fifteen CSVs and their JSON equivalents: 94 principals, 6,008 permission grants, 43 active access keys, 44 role-to-principal trust edges, 17 role-to-service edges, three resource policies. Nothing crashed. Nothing needed a flag.

Among the columns it emits is one called `CanPrivEscToAdmin?`. It appears 140 times across four output files — once for each of the 94 principals, once for each of the 44 trust edges, once for the account's single root-trust finding, once for its single workload. In this run, all 140 instances read:

```
"CanPrivEscToAdmin?": "Skipping, no pmapper data",
```

cloudfox has no path finder. It delegates privilege-escalation path enumeration to PMapper, and it is unusually forthright about doing so. Three places, at increasing volume.

The wiki page that cloudfox itself prints a link to during the run:

> Cloudfox will not install or run `pmapper` for you, but because `pmapper` stores it's graph data in a predictable location, this CloudFox command will look to see if that data exists, and if it does, it give you a list of all of the principals that pmapper thinks can escalate to admin.

The console, mid-run:

> `[iam-simulator][personal] We suggest running the pmapper commands in the loot file to get the same information but taking privesc paths into account.`

And then the loot file itself — `loot/iam-simulator-pmapper-commands.txt`, sixteen lines, one `graph create` and fifteen `query` invocations, every one of them `pmapper`, none of them cloudfox:

```
pmapper --profile personal graph create
pmapper --profile personal query "who can do sts:AssumeRole with *" | tee ...
pmapper --profile personal query "who can do iam:PassRole with *" | tee ...
pmapper --profile personal query "who can do secretsmanager:GetSecretValue with *" | tee ...
...
```

The tool that ran successfully wrote me a shell script for the tool that had not run yet.

This is deliberate, and cloudfox's documentation is clear about the trade it makes: without PMapper data, its fallback answers *who is an admin*, not *what paths exist*, and it says as much — the fallback "is really just a wrapper around AWS's IAM simulate principal policy API call." The same page calls PMapper "the most accurate open source AWS policy simulator project that takes into account privilege escalation." cloudfox v2.0.5 shipped 2026-05-26. It points at a project whose last commit is dated 2022-02-03.

Two consequences follow, and I want to be precise about the scope of each.

**The narrow one is about my matrix.** My rubric grades a category N/A only where the tool's own documentation explicitly disclaims it, quoted and linked. cloudfox clears that bar for path enumeration, so its path column is N/A on all 86 rows — recorded, not scored as a miss. But N/A applies to that column and not to cloudfox as a tool. Reading the disclaimer generously enough to void every miss would make the matrix vacuous, so everything cloudfox computes itself — `permissions`, `principals`, `iam-simulator`, `role-trusts`, `lambda`, `workloads` — is graded normally, and that is where its results in §4 come from.

**The broader one is about what I was actually able to measure.** I set out to compare two tools on path detection and found I had one path-enumeration engine and one tool that renders its output. Had PMapper's graph been on disk when cloudfox ran, `CanPrivEscToAdmin?` would have been a rendering of PMapper's answer, and I would have graded the same engine twice under two names while believing I had two data points. That did not happen only because I ordered the runs to prevent it: cloudfox ran first, on a machine where PMapper had never run, with `~/.local/share/principalmapper` and `~/Library/Application Support/com.nccgroup.principalmapper` both confirmed absent immediately beforehand. It is recorded in both run metadata files.

I am not claiming to have surveyed the ecosystem. I ran two tools. What I can say from those two is this: the one that is actively maintained does not enumerate paths and refers you to the one that does; the one that does has been dormant for four and a half years and, in §2, discarded its entire graph on a connect timeout. Anyone assembling a comparison of open-source AWS IAM path finders should check, before treating two columns as independent evidence, whether the second column is reading the first one's output off disk.

---

## §4 — What the tools found

PMapper detected 20 of the 23 canonical escalation mechanisms in this lab. Its default invocation returns nothing at all. Both sentences describe the same tool on the same account on the same night, and the rest of this section is an attempt to hold them together without letting either one swallow the other.

### Before the numbers: this lab is the tools' home turf

`iam-vulnerable` implements Rhino Security Labs' catalogue of AWS privilege escalation methods. PMapper and cloudfox were both substantially built to detect that catalogue. A high score on it is the expected outcome and is close to worthless as evidence of quality. It measures whether a tool detects the list it was written against.

So the numbers below are a control, not a verdict. What is actually informative sits in three narrower places: the mechanisms a tool misses *despite* the home-turf advantage, the paths it reports that do not work, and the rows outside the catalogue. I report the control anyway, because without it none of the rest is calibrated, and because a benchmark that only publishes its interesting cells is not a benchmark.

### The denominators

The lab's 46 mechanisms and 86 principal rows do not all pose the same question, so they are counted in three buckets and never pooled.

**Detection — 31 mechanisms, 52 rows.** A real path with a live target. This is the D/P/M ladder and the headline.

**Target-absent — 8 mechanisms, 16 rows.** The grant is real and the thing it needs to point at does not exist here: no EC2 instances, no SSM-managed nodes, no CloudFormation stacks, no SageMaker notebooks, and Glue dev endpoints retired account-wide by AWS. Verified across all 17 enabled regions. Excluded from every detection count.

**No-path — 18 rows.** Nothing to detect. Five of these are the lab's designed false-positive fixtures — `Allow` and `Deny` in one policy, `Deny iam:*` with no allow, a resource constraint scoped to the unwritable AWS-owned policy namespace. Correct behaviour is silence, so these grade *Correctly Silent* or *false positive*, never on the detection ladder.

The remaining six no-path rows were not in that bucket when I started. They moved there because of a mistake I made, and that mistake is §5.

**One caveat travels with every PMapper number below.** They come from a rerun with `--include-regions` restricted to the account's 17 opted-in regions — the flag I used to route around the crash in §2. It's detection-neutral by construction, since AWS does not permit resource creation in a region an account has not enabled. It is still non-default, and my rubric forbids merging a flagged run into a default score. The default column is 86 rows of Missed. Every number in this section is the flagged run.

### Detection bucket

**31 mechanisms:**

| | D | P | M | N/A |
|---|---:|---:|---:|---:|
| PMapper — default | 0 | 0 | **31** | 0 |
| PMapper — region-scoped | **27** | 0 | 4 | 0 |
| cloudfox — own surfaces | 3 | **26** | 2 | 0 |
| cloudfox — path column | 0 | 0 | 0 | **31** |

**52 principal rows:** PMapper region-scoped D 44 / M 8; cloudfox 3 D, 47 P, 2 M.

Restricted to the canonical Rhino catalogue with a live target — 23 mechanisms, 40 rows — PMapper detects 20 of 23 mechanisms and 34 of 40 rows. cloudfox detects none of them and partials 21 of 23.

### The two tools have different shapes, and the grades are mostly measuring that

**PMapper produced zero Partial grades.** Not few — none. It has no partial output form. A principal is on the privilege-escalation list with a named target and a named mechanism, or it is absent. That is what a graph gives you: the edge either closes or it does not.

**cloudfox produced 47 Partials out of 52 rows, and that is not a failure grade.** Its `permissions.csv` is 6,008 rows of `(principal, policy, effect, action, resource, condition)`. Every dangerous permission in this lab is in there, bound to the specific principal that holds it. My rubric's bar for partial credit is exactly that binding — a list of scary permission names with no principal attached would have been Missed. cloudfox clears it comprehensively and then stops one step short of a claim. It tells you `privesc10-PutUserPolicy-user` can call `iam:PutUserPolicy` on `*`. It does not tell you that this makes the user an administrator.

The clearest single comparison in the whole matrix is the lab's three-role assume-role chain. cloudfox's `role-trusts-principals.csv` contains this row:

```
ending-role | Trusted Principal = intermediate-role | IsAdmin? = YES
```

and, one row later:

```
intermediate-role | Trusted Principal = starting-role | IsAdmin? = No
```

Every hop of the chain is present in cloudfox's output. The chain is not. Nothing in those two rows joins them, and my rubric scores hop 1 without the chain as Partial. PMapper prints both hops under a single heading and scores Detected. That pair of cells is the most economical statement I can make about what a path finder buys you. Not better data; cloudfox's underlying data is arguably richer. The join.

The three rows where cloudfox does reach Detected are the two roles it names outright (`iam-simulator` says *"Appears to be an administrator"*, `principals.csv` sets `IsAdminRole? = YES`), plus that first trust row, where principal, trust edge and administrative target happen to land on one line. I flagged the third as inferred, because the grade comes from joining two columns myself rather than from any escalation statement cloudfox makes.

### The four mechanisms PMapper misses

Three are confirmed working paths. One rests on ground truth I could not confirm.

**`privesc13-AddUserToGroup`.** I validated this by exercising it: the role added a zero-permission user to `privesc-sre-group`, and that user immediately held `iam:CreateUser` and `iam:AttachUserPolicy`. I restored the membership afterwards. PMapper models group edges for permission resolution but does not surface `AddUserToGroup` as an escalation into an admin-carrying group.

**`fn3-exploitableConditionConstraint`** is the pointed one. The lab wraps `iam:CreatePolicyVersion` in a condition — `DateGreaterThan aws:TokenIssueTime 2020-01-01` — which is always true. AWS's own simulator allows the action once the context key is supplied. PMapper reports the sibling fixtures `fn2` (a resource constraint that looks limiting but matches the principal's own policy) and `fn4` (a `NotAction` that still permits `iam:PutUserPolicy`) as administrative, and drops only the condition-wrapped variant. That is precisely the failure mode `fn3` was built to expose.

**`privesc17-EditExistingLambdaFunctionWithRole`** is a miss by design. PMapper draws edges only toward principals it has already determined are administrative, and this scenario's only reachable target — a pre-existing `EC2-AutoRemediation` function whose role grants EC2 read, tagging and logs — is not one. The path is real and the miss is genuine. The same design decision is why PMapper did not overstate it, which matters below.

**`privesc21-PassExistingRoleToNewDataPipeline`.** PMapper has no Data Pipeline edge check. But AWS Data Pipeline is closed to new customers, and I never attempted to create a pipeline in this account, so whether the target exists at all is inferred rather than confirmed. The cell stays flagged. It is one of only four PMapper misses, which means it carries more weight than an unconfirmed row should have to.

cloudfox misses none of these outright — it binds every one of the enabling permissions to every principal that holds it. It connects none of them to a target either.

### Four false positives, all PMapper, all the same mistake

PMapper reported 32 escalation paths and asserted 17 principals administrative. cloudfox reported 0 escalation paths and made 78 `iam-simulator` assertions. Against those denominators, and within a validated sample of 22 principal rows across 19 files: **PMapper 4 confirmed false positives, cloudfox 0.** That is a count from a sample, not a rate — I did not check the whole population and will not imply I did.

All four are one error, twice over. PMapper asserts, on its primary surface and again in its analysis report at severity High:

```
user/privesc-ssmSendCommand-user can call ssm:SendCommand to access an EC2
   instance with access to role/privesc-high-priv-service-role
```

There is no such instance. Zero EC2 instances and zero SSM-managed nodes across all 17 enabled regions. PMapper's own supporting finding gives away the inference: *"The following IAM Roles are attached to at least one instance profile."* It reasons from the existence of an **instance profile** on the administrative role to the existence of an **instance** carrying it. The profile is real. The instance is not.

What makes this a false positive rather than a modelling preference is the contrast sitting next to it in the same account. `privesc3-CreateEC2WithExistingInstanceProfile` uses the *same* instance profile and *is* a working path, because that principal holds `ec2:RunInstances` and creates the instance it then uses. The SSM principals hold `ec2:DescribeInstances` and the SSM actions and nothing else — they can only act on an instance that is already there, and none is.

I want to be exact about what this is not. PMapper is not wrong about the permission, the mechanism, or the risk. In an account with SSM-managed instances, the path works. It is a false positive about *this account*: PMapper reasons over declared IAM state and does not check whether the compute its path traverses exists. That's a design boundary and worth naming as one, because in §5 the same declared-state-only reasoning produces the identical error in my ground truth, running the other direction.

Three other candidates I validated and cleared. The sharpest was `privesc17` overstating impact — the reachable Lambda target grants EC2 read and tagging, not admin, so a tool calling it a path to administrator would have been wrong. Neither tool did: PMapper does not report it at all, and cloudfox lists the role with `IsAdminRole? = No`. Both correct, by different routes.

And neither tool reported any of the five designed false-positive fixtures. Both were silent where silence was the right answer. That result is worth stating and discounting in the same breath: a tool that reports nothing anywhere passes every false-positive test ever devised, which is why the crashed PMapper column scores those rows as crash-Missed rather than crediting it for silence it did not choose.

### Two things that only show up in the error log

cloudfox's `iam-simulator` exhausted its three retries on `SimulatePrincipalPolicy … Throttling: Rate exceeded` for three principals. My rubric makes the affected scenarios Missed, which costs cloudfox two detection grades. The sharper problem is that **those failures are invisible in cloudfox's output.** The three principals still appear in `principals.csv` with `IsAdminRole? = No`, indistinguishable from a genuine negative. Only `cloudfox-logs/cloudfox-error.log` knows the question was never answered.

The second is what happened when I reran both tools as a `SecurityAudit` user instead of an administrator. I predicted a materially reduced output surface. I was wrong, and not marginally: PMapper's privilege-escalation output is **byte-identical** between the two contexts — same 32 paths, same 17 administrative principals, same ordering, same 10,520 bytes — and its analysis report differs by one line, the timestamp. cloudfox's 94 principals are field-for-field identical including `IsAdminRole?`, and `permissions.json` compares equal once the new principal's own 1,031 grant rows are removed. `SecurityAudit` grants enough IAM read access that neither tool notices the difference. That result is about this policy, not about low privilege in general; a principal missing `iam:ListRoles` would have produced a very different and much less interesting answer.

But the error logs differ, and the difference is the finding. cloudfox's `Glue: ListDevEndpoints` call fails 17 times under administrator with `InternalFailure` — which is what AWS returns for a feature it has retired, and is the evidence my scenario list cites for two mechanisms having no target. Under `SecurityAudit` the same call fails 17 times with `AccessDeniedException`. **The report looks identical either way.** An auditor holding `SecurityAudit` cannot distinguish *this capability no longer exists* from *I was not allowed to look*, and both render as an absent section.

### Scoring my own predictions

I wrote five predictions into the frozen rubric before deploying anything. Four were wrong or unanswerable.

I predicted both tools would detect at least four fifths of the canonical mechanisms; PMapper clears the bar at 20 of 23 and cloudfox scores zero, because its path column is disclaimed and its own surfaces stop at Partial. The prediction failed on the word "both". It did not anticipate a tool graded on a partial-credit surface, and it did not anticipate a crash. I predicted the limited context would degrade both tools; it did not. I predicted PMapper would produce more Partials than Detecteds on multi-hop chains; it produced no Partials at any point and detected both chain hops, so the prediction was not testable as written and wrong in spirit. I predicted at least one false positive; there were four. The fifth prediction concerns the OIDC scenarios and is unresolved — §6.

---

## §5 — My ground truth was wrong, and the tool was right

Six mechanisms in the lab exist in two variants: one held by a user, one by a role, with identical permissions. `iam:AttachUserPolicy`. `iam:PutUserPolicy`. `iam:AttachGroupPolicy`. `iam:PutGroupPolicy`. `iam:AttachRolePolicy`. `iam:PutRolePolicy`.

On the first pass PMapper reported exactly one variant of each and not the other, and my matrix scored the missing six as misses. That asymmetry is the reason my rubric requires both a mechanism-level and a per-principal denominator — a tool catching one variant of a mechanism and missing its twin is a real finding that a mechanism-level rollup hides. I flagged it as the top validation priority and wrote it down as PMapper being inconsistent.

It is not inconsistent. It is right, and I was wrong.

I validated all six by hand, one file each. Every one holds exactly one grant, and in every case that grant targets a construct the principal is not:

`iam:AttachUserPolicy` and `iam:PutUserPolicy` operate on users. The role variants cannot point them at themselves. They also hold no key-minting permission, and roles carry no access keys, so there is no route to authenticating as any user they could empower.

`iam:AttachGroupPolicy` and `iam:PutGroupPolicy` operate on groups. A role cannot be a member of an IAM group — the API does not allow it — so the role variants can make a group administrative and can never be in it.

`iam:AttachRolePolicy` and `iam:PutRolePolicy` operate on roles. The user variants can write `AdministratorAccess` onto any role in the account and can assume none of them: each is named in no trust policy, holds no `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy`, and no `iam:PassRole`.

In every case the variant PMapper *did* report is the one that can point the permission at itself. Its graph records the distinction directly: those six principals are marked `is_admin: true`, and these six `is_admin: false`. The rule it applies is legible once you see it: **PMapper reports a principal where the principal can escalate itself**, not where the principal can escalate something.

My scenario list did not make that distinction, because it could not. I generated it from Terraform state and `iam get-account-authorization-details`: principal, permission, resource. That is the right source for an inventory and it is silent on whether a principal can reach what its permission empowers. Six of my 86 rows asserted a path that does not close.

My rubric anticipated this case in the abstract — *a Missed that turns out not to be a real path is a scenario-list error, not a tool miss* — so the six rows were reclassified out of the detection bucket and into a class with no path to detect. Here is what that did to the headline:

| | before | after |
|---|---|---|
| Detection bucket, mechanisms | D 21 of 31 | **D 27 of 31** |
| Detection bucket, rows | D 44 of 58 | **D 44 of 52** |
| Canonical catalogue, mechanisms | D 14 of 23 | **D 20 of 23** |

**D didn't move. The denominator did.** PMapper detected 44 rows before the correction and 44 rows after it. Nothing about its output changed — the same file was graded twice against two versions of the ground truth. Any reading of this as PMapper improving is wrong, and the four-fifths threshold it now clears in §4 is one it clears because I fixed my list, not because it found anything more.

The general form of the mistake is the part worth carrying away. **A list derived from declared IAM state is a list of grants. A path finder answers a question about reachability. Grading the second against the first manufactures misses**, and it manufactures them in a specific, non-random direction: against exactly the tools that model reachability correctly. A cruder tool that flagged all twelve variants would have scored better on my list than PMapper did, for being less right.

The fix has a name and I did not run it. An `iam:SimulatePrincipalPolicy` sweep across the principal-by-action matrix gives you a path oracle sourced from AWS's own policy evaluator, independent of both graded tools and free of the catalogue bias in §4. My rubric names it and puts it out of scope to keep the phase bounded. This section is the cost of that decision, paid in six rows I corrected by hand after they had already been scored.

There is a symmetry here that I did not plan and cannot take credit for. In §4, PMapper reasons over declared IAM state and asserts a path through an EC2 instance that does not exist — four false positives. In §5, I reason over declared IAM state and assert six paths that do not close — six manufactured misses. Same blind spot, same cause, opposite directions, one of them in the tool and one in the benchmark grading it.

Three caveats, because this section is flattering to PMapper and I do not want it to flatter further than the evidence goes.

**The six principals are not harmless.** Each can make another principal administrative, and two of them are users holding live access keys, which makes them usable starting points for someone who has them. What they cannot do is escalate themselves, which is what my Detected grade measures and what PMapper's model tracks. A reader whose threat model is "an attacker with these keys can leave an administrative principal behind for later" is looking at something my matrix does not score. Every validation file says so and this section does too.

**PMapper's rule is not universally correct, and the lab contains the counterexample.** `privesc13-AddUserToGroup` is the mirror image: there the group *is* reachable, because the user adds itself to it, and I confirmed the escalation by exercising it. That is a self-escalation path by PMapper's own criterion, and it is one of the four mechanisms PMapper misses. The rule it applies is right about these six rows and does not save it there.

**The late-additions bucket is empty.** My rubric reserved a separate tally for working paths discovered during validation that the scenario list never showed. I found none. Given that I never ran the oracle that would systematically look for them, that empty bucket is a fact about my method, not a finding about the account. Forty-one of the 344 graded cells remain flagged as inferred rather than read from output or a validation file, and the flag is a published column rather than a caveat in prose.

---

## §6 — The edge I had to build, and what AWS does about it

`iam-vulnerable` ships no web-identity scenario. There is no OIDC provider in it, no SAML provider, and no federated trust of any kind — which is why cloudfox's `role-trusts-federated.csv` came back with zero rows in §4. The surface exists in the tool. There was nothing in the account for it to hold.

So I built one, after the matrix was finished and frozen. Thirteen resources in a separate Terraform state, deployed 2026-08-30, never folded into any denominator in this post. **I did not run either tool against them.** What follows is a measured fact about AWS, a measured fact about reachability, and an argument about architecture, in that order and clearly separated. The thing everyone wants me to claim here is the one thing I did not test.

### The shape

Two chains, two hops each, structurally identical. **The hop-1 trust policy is the only variable between them**; the thin entry permission, the tight hop-2 trust, and the administrative terminus are held constant so that any difference in outcome is attributable to the trust condition and nothing else.

Hop 1 is a GitHub Actions deploy role, assumable by web identity, whose only permission is `sts:AssumeRole` on exactly one named role. Hop 2 is that role: `Allow *:*`, with a trust policy naming exactly one principal — the entry role, and nothing else.

Hop 2 is correct in both chains. Its trust is as tight as a trust policy gets and its permissions are what a Terraform execution role legitimately needs. The chain is open anyway, because hop 1's front door is open. That asymmetry is the whole scenario: **every control on the valuable resource is right, and it does not matter.**

### Scenario A was supposed to be the strawman, and AWS refused to build it

Scenario A is the floor case — a `sub` condition that matches every repository on GitHub. Indefensible on sight, present only to be the baseline that Scenario B is measured against.

I first wrote it with **no `sub` condition at all**, which is the canonical version of this misconfiguration. `CreateRole` refused, verbatim:

```
MalformedPolicyDocument: Trust policy with trusted principal
arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com must
evaluate, using StringEquals, StringLike or StringEqualsIgnoreCase,
token.actions.githubusercontent.com:sub or
token.actions.githubusercontent.com:job_workflow_ref which is not scoped to all.
```

This was not in my plan. AWS ships a guardrail against precisely the misconfiguration I was trying to deploy. The obvious conclusion, that the floor case cannot exist any more, is wrong. Finding out why took four `create-role` calls against a throwaway role I deleted immediately after.

One variable, four candidates:

| `sub` condition | `CreateRole` |
|---|---|
| *(absent)* | **REJECTED** |
| `StringLike "*"` | **REJECTED** |
| `StringLike "repo:*"` | **ACCEPTED** |
| `StringLike "repo:*/*"` | **ACCEPTED** |

Every default-format GitHub Actions subject claim begins with `repo:` — `repo:<owner>/<repo>:ref:refs/heads/main`, `repo:<owner>/<repo>:pull_request`, `repo:<owner>/<repo>:environment:prod`. **`repo:*` matches all of them.** It admits the same set as the condition AWS had just refused, and AWS accepts it.

The check is a string test on the policy document. It is not an evaluation of what the policy admits.

One caveat belongs directly here rather than at the end: GitHub lets an organisation customise the subject claim via `include_claim_keys`, producing a `sub` that need not begin with `repo:`. For such an organisation, `repo:*` matches nothing. That is not the default and not the common case, so the precise claim is "matches every default-format Actions subject claim," not "matches every Actions token."

Two things follow. A reviewer, an auditor, or an automated check that treats *a `sub` condition is present* as the control is measuring the same property AWS's guardrail measures, and is wrong in the same way. And the rejection message is specific and educational, which makes it *more* likely, not less, that an engineer who hits it pastes in the first pattern that gets accepted.

That failure mode already appeared once in this post, in a different tool at a different layer. In §4, `permissions.csv` prints `Condition=Yes` for the lab's always-true `DateGreaterThan` fixture and `Condition=Yes` for its never-true `DateLessThan` twin — identical rows, one exploitable and one inert, because the column records that a condition exists rather than what it permits. The same file renders the `Resource` column verbatim, which is why the resource-constraint pair *is* separable from the same output. Presence of a constraint is cheap to check and tells you very little. What the constraint admits is the whole question, and it is the part that keeps getting dropped.

### Scenario B is the one that ships

```json
"StringLike": { "token.actions.githubusercontent.com:sub": "repo:iam-tool-benchmark-lab/*" }
```

`sub` is present. It is `StringLike`. It names an organisation. It passes a skim review, and it looks like the documented pattern.

What it admits is every repository under that organisation — every branch, every tag, every environment, every `pull_request` run, and every repository created after the review by anyone who can create one.

| | |
|---|---|
| enforced | `repo:iam-tool-benchmark-lab/*` |
| intended | `repo:iam-tool-benchmark-lab/deploy:ref:refs/heads/main` |

One asterisk apart. B is the headline and A is the strawman: A is caught by inspection and, as of now, half-caught by AWS itself. B is caught by neither.

### What is measured about reachability, and what is only argued

The measured part is a denial table. `user/iamadmin` holds `AdministratorAccess`, so its identity policy permits `sts:AssumeRole` on every resource in the account. Every denial below is therefore the *resource* trust policy refusing, which is exactly what needed confirming:

```
$ aws sts assume-role --profile personal \
    --role-arn arn:aws:iam::000000000000:role/<ROLE> \
    --role-session-name phase5-reachability-check
```

| role | result |
|---|---|
| `oidc-gha-deploy-role` | `AccessDenied … not authorized to perform: sts:AssumeRole` |
| `oidc-gha-terraform-role` | `AccessDenied … not authorized to perform: sts:AssumeRole` |
| `oidc-gha-wildcard-deploy-role` | `AccessDenied … not authorized to perform: sts:AssumeRole` |
| `oidc-gha-wildcard-terraform-role` | `AccessDenied … not authorized to perform: sts:AssumeRole` |

No principal inside this account can reach any of the four roles, including the account administrator. Two consequences, both factual. These thirteen resources add zero intra-account escalation paths, so the graded matrix in §4 is unaffected as a matter of fact and not merely of ordering. And the only route into either chain is `sts:AssumeRoleWithWebIdentity` presenting a GitHub-issued token.

The argued part is what that implies. An account-internal graph is built from the principals, policies and trust relationships the account contains — in PMapper's case, `get-account-authorization-details` plus nine per-service edge checks, all of them enumerating in-account resources. The first edge of both chains originates outside that boundary, at an identity provider, and its admissibility turns on string-matching a claim in a token that the account does not issue and never sees at graph-build time. Nothing in the denial table above is visible as an edge to anything reasoning over in-account state alone.

That is an argument about where the boundary of a graph falls. It is not a measurement, and I'm not converting it into one. cloudfox has a federated-trust surface; what that surface would have produced against these four roles is untested, because I did not point it at them.

### What is not proven

End-to-end exploitability of both chains is **inferred, not demonstrated**. Confirmed: the trust policies exist as written, AWS accepted them, the permission policies grant the hop, hop 2 holds `Allow *:*`, and no in-account principal can reach either chain. Not confirmed: that a real GitHub Actions token satisfies these conditions and yields administrator. Proving it needs a repository running a workflow with `id-token: write`, calling `AssumeRoleWithWebIdentity` and then `AssumeRole` on hop 2. No such repository exists and I did not run one.

The inference rests on the documented format of the Actions `sub` claim and on AWS's own condition-evaluation semantics. Both are well documented and the inference is strong. It is still an inference, and it applies equally to Scenario A and Scenario B.

### This is a live trust in a live account

It is worth saying plainly, because anyone reproducing it should understand what they are standing up. Scenario A's entry role can be assumed by anyone who runs a GitHub Actions workflow and knows the role ARN; the only thing between it and account administrator is that the ARN is not published. Scenario B's entry role can be assumed by anyone who controls a repository under the GitHub organisation `iam-tool-benchmark-lab` — a name I chose because it was unregistered, checked against `api.github.com/orgs/…` and `/users/…` immediately before apply, both HTTP 404. **If someone registers it, they get administrator in that account.**

Hence the handling: the account ID stays out of the repository behind a published one-way substitution, the repository stayed private until this post, and teardown here is more urgent than for the main lab. `iam-vulnerable`'s principals are exploitable by someone who already holds credentials in the account. These two are exploitable by someone who holds none.

---

## §7 — What this does not show

The caveats attached to individual claims are next to those claims. These are the limits on the whole exercise.

**Everything here is n=1.** One AWS account, one lab deployment, one run per tool per context, on 2026-08-31. The connect timeout in §2 is a single observation and I report it as one — I do not know how often that endpoint fails to answer. The defect it exposes does not depend on my network or my region set, but the frequency does, and I have no data on it.

**Two tools is not a survey.** The claim in §3 is about what I could measure with the two tools I ran: one enumerates paths, the other renders its output and says so. I did not review the field.

**`SecurityAudit` is one point on a spectrum, not "low privilege."** The null result in §4 says these two tools produce near-identical output under that specific AWS-managed policy. A principal missing `iam:ListRoles` would have produced a different answer and a much less interesting one.

**Target absence was verified by resource-existence checks, not by exploitation.** Across all 17 enabled regions I confirmed there are no EC2 instances, no SSM-managed nodes, no stacks, no notebooks. I did not launch an instance to confirm that the SSM paths in §4 would then work. The false-positive determination rests on the absence of the resource the reported path traverses, which is sufficient for *this path does not work as the account stands* and is not a claim about the mechanism in general. Symmetrically, a target being present means a target exists — not that the path has been driven end to end.

**Validation is sampled.** Nineteen files covering 22 of 86 principal rows. Every false-positive count in this post is *found in a sample of 22 validated rows*, never a rate, because I did not check the population. Forty-one of 344 graded cells remain flagged as inferred rather than read from output or a validation file, and one of PMapper's four misses — the Data Pipeline mechanism — rests on ground truth I never confirmed, since Data Pipeline is closed to new customers and I never attempted to create one.

**Grading is unweighted.** A missed four-hop chain to account administrator scores exactly what a missed single hop to a low-value target scores. Weighting needs an impact model I do not have, and building one after seeing results is the failure the frozen rubric exists to prevent. It does mean the counts in §4 flatten a real difference in severity.

**One rubric requirement I satisfied on a reading rather than to the letter.** I required at least three scenarios graded Missed by *all* tools to be validated, and wrote three: `privesc2`, `privesc13`, `fn3`. Under the final grades, no row is Missed in every column — cloudfox's principal-bound permission dump earns Partial on all three. I validated them as *Missed on the escalation question*, which is what the requirement was for and how the files were written. Stating the choice rather than quietly satisfying the weaker version of it.

**No independent path oracle was run**, which is the load-bearing one. Without a `SimulatePrincipalPolicy` sweep, my scenario list enumerates declared grants and nothing systematically looked for paths the lab's author did not place. §5 is what that cost when it went wrong in a direction I could detect. It says nothing about what it cost in the direction I could not.

---

## §8 — Reproducing this

Everything is in the repository: the rubric, frozen in git before the lab was deployed and append-only afterwards, so `git log -p analysis/rubric.md` shows what I committed to before I saw any output; the scenario list; `grades.csv`, one row per `(scenario, tool, context, flagset)`, 344 of them, each carrying its evidence path and the exact search string used to reach the grade; the validation files with their commands and outcomes; and `matrix.md`, written by hand from `grades.csv` with no generator in between.

Raw tool output is committed unedited except for one published, one-way substitution — `redact.sh` replaces the account ID and access key IDs with fixed placeholders, in file contents and in path components, and the script is committed alongside the output it produced. "Unedited" means "unedited modulo one auditable rule." Any grade in the matrix can be checked against its source.

**Versions.** cloudfox `2.0.5` (release binary, commit `ba4ff47`, published SHA-1 verified against the release's own `sha1sum.txt`). PMapper `1.1.5` (tag `d5136ff`, wheel uploaded 2022-01-13; `master` HEAD `91d2e60`, dated 2022-02-03), on Python `3.9.25`. `iam-vulnerable` at `0f29866`. Terraform `1.14.8`, `hashicorp/aws` `6.62.0`.

**One reproduction hazard.** PMapper 1.1.5 does not import on Python 3.10 or later, and the Homebrew build of `python@3.9` I used is scheduled for disablement on 2026-10-15. Anyone repeating this after that date will have to source a 3.9 interpreter another way or patch the import — and a patched PMapper is a different artifact from the published one, which is why I did not patch mine.

**Account hygiene, because the lab is exactly what it says it is.** Dedicated personal sandbox account, never an account connected to anything else I touch. A named CLI profile used explicitly on every call, with `sts get-caller-identity` confirmed before anything ran. `iam-vulnerable` creates users, roles and access keys that exist specifically to escalate to administrator; it is not something to point at a shared account.

**Teardown is containment, not tidying.** There are two Terraform roots and both need destroying:

```
cd lab-oidc && terraform destroy   # 13 resources — do this one first
cd ../lab   && terraform destroy   # 265 resources
```

The OIDC root goes first for the reason in §6: those two chains are reachable by someone who holds no credentials in the account at all, and one of them depends on a GitHub organisation name staying unregistered. The main lab is the opposite risk and a larger one in volume — it creates 41 `aws_iam_access_key` resources, so `lab/terraform.tfstate` holds **41 live AWS secret access keys in plaintext**, one per lab user, every one attached to a principal built to reach administrator. The file is gitignored and will not be committed. It is still credential material sitting on a laptop, and those keys stay valid until they are deleted. Confirm with `terraform state list` returning empty.

Two things neither destroy removes, deliberately: the purpose-made `SecurityAudit` user, and the pre-existing `EC2-AutoRemediation` Lambda that is the only reachable target for one of the scenarios.

I have my own IAM tool. It is not in this benchmark, its test fixtures were deleted from the account before grading, and the reason for both is that a baseline is only worth having if it was built before the thing it is meant to measure.