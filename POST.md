# Two AWS IAM privesc tools, one path finder

*A per-scenario detection matrix for PMapper and cloudfox, and the six rows where my ground truth was wrong.*

> I spent two weekends deploying Bishop Fox's `iam-vulnerable` into a throwaway AWS account and grading two open-source IAM privilege-escalation tools against it, using a rubric I froze before deploying anything. That gave me 344 graded cells, 19 hand-validated scenarios, and every byte of raw tool output published unedited. Here's what I found, including the part where the tools were right and my scenario list was wrong.

---

## 1. What this is

Over two weekends I deployed Bishop Fox's `iam-vulnerable` into a dedicated AWS account and ran two open-source IAM privilege-escalation tools against it: **cloudfox 2.0.5** and **PMapper 1.1.5**. I graded every scenario the lab created by hand, against a rubric I froze in git before deploying anything. That gave me a 344-row grade file, 19 validation files with the exact CLI commands I ran and what they returned, and a per-scenario matrix. It's all published, raw tool output included. The only edit is a one-way account-ID substitution, and that script is committed next to the output it produced.

This isn't a shootout and there's no winner. Two tools isn't an ecosystem survey, one account isn't a population, and each run happened once. This is what happened when I ran these two tools against this lab on 2026-08-31. Where I generalise past that, I say so and show the reasoning.

**What I graded.** The lab applied 265 resources at commit `0f29866`. From those I derived 46 escalation mechanisms across 86 `(principal, mechanism)` rows, generated from `iam get-account-authorization-details` plus per-service existence checks against the live account, not from the lab's README. Each row got a grade per tool:

- **Detected:** the output names the principal, the enabling permission, and the reachable target.
- **Partial:** it ties a risky permission to a specific principal but connects it to nothing.
- **Missed:** nothing in the output would point a reviewer at the path.

I ran each tool twice, once as an administrator and once as a purpose-made user holding only the AWS-managed `SecurityAudit` policy, which is what an actual auditor or CSPM integration would have.

**Three things to know before any of the numbers.**

The lab is built from Rhino Security Labs' catalogue of AWS privesc methods, and both tools were largely written to detect that catalogue. High scores are the expected result, not evidence of quality. The interesting cells are the misses, the false positives, and anything outside the catalogue.

The lab's `aws_assume_role_arn` variable defaults to whoever deploys it, so all 45 roles it creates name my admin user in their trust policies. Under admin credentials the role graph is a star centred on one principal, and every reachability result is inflated by that. That's a property of how the lab deploys, not of either tool.

I have my own IAM tool, `iamwho`, and it's deliberately not in this benchmark. The point of running these two first was to get a baseline I hadn't built around my own work. Eleven `iamwho` test fixtures were already sitting in the account when I started, so I deleted them and the CloudFormation stack that created them before grading. It cost me a scenario: `privesc-CloudFormationUpdateStack` became unexploitable, since the only stack in the account was my own leftovers. Grading it as live would have meant crediting the withheld tool's residue.

**What I didn't test.** Runtime and behavioural detection. Cross-account and Organizations-level paths. SCPs and permission boundaries beyond what the lab deploys. Resource policies other than role trust policies. Anything needing write access or an agent.

One more omission that matters, because it caused the most interesting mistake I made: I never ran an `iam:SimulatePrincipalPolicy` sweep as an independent oracle. My ground truth is an inventory of declared grants, and section 5 is what that cost me.

Grading is unweighted. A missed four-hop chain to account admin scores the same as a missed single hop to a low-value target. Weighting would need an impact model I don't have, and inventing one after seeing the results is exactly what the frozen rubric was meant to prevent.

---

## 2. The default invocation returns nothing

PMapper builds a directed graph of every principal in an account and the edges between them, then answers questions over it. Everything starts with `pmapper graph create`, so I ran that with admin credentials against the freshly applied lab:

```
$ pmapper --profile personal graph create
```

It ran for five minutes and fifty-two seconds and exited 1.

The first four minutes look fine. It pulls users, roles, groups and policies, sorts the relationships, gathers access keys and MFA devices, works out which principals are administrative. Then it starts edge checks, beginning with EC2 Auto Scaling, which means enumerating launch configurations in every region. My account has 17 regions enabled and AWS advertises far more, so most of those calls go to endpoints the account can't use. PMapper handles that:

```
19:23:21 | Unable to search region af-south-1 for launch configs. The region may be
           disabled, or the error may be caused by an authorization issue. Continuing.
19:23:21 | Unable to search region ap-east-1 for launch configs. ... Continuing.
19:23:22 | Unable to search region ap-east-2 for launch configs. ... Continuing.
```

Fifteen regions, fifteen warnings, fifteen times "Continuing." Then the sixteenth:

```
botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint URL:
"https://autoscaling.me-south-1.amazonaws.com/"
```

and the process dies at `autoscaling_edges.py:60`.

It comes down to one line of exception handling. `AutoScalingEdgeChecker.return_edges` wraps its paginator in a `try` whose handler is exactly the warning printed fifteen times above:

```python
except ClientError as ex:
    logger.warning('Unable to search region {} for launch configs. The region may be
                    disabled, or the error may be caused by an authorization issue.
                    Continuing.'.format(as_client.meta.region_name))
```

Fifteen of those regions answered, just with an error (`AuthFailure`, or a disabled-region refusal). A service error arriving over HTTP is a botocore `ClientError`, which the handler catches. `me-south-1` didn't answer at all. A connection that never establishes raises `ConnectTimeoutError`, which inherits from `BotoCoreError` rather than `ClientError`, so it goes straight past the handler, out of the region loop, out of `obtain_edges`, and out of `main`.

The handler isn't missing. It's there, it's deliberate, it's written for this exact situation, and it's scoped to the wrong exception class.

What it costs is way out of proportion to the cause. Auto Scaling is the **first of nine** edge checks (`autoscaling`, `cloudformation`, `codebuild`, `ec2`, `iam`, `lambda`, `sagemaker`, `ssm`, `sts`) and `obtain_edges` accumulates all nine into one list, returning it only at the end. There's no partial result and no checkpoint. The IAM data that took four minutes to collect is still sitting in memory when the process exits, and it never gets written to disk. One unreachable regional endpoint throws away the entire graph.

Everything downstream depends on that file. I ran the seven other commands anyway, to record what a user actually experiences. Six of them died identically:

```
ValueError: Did not find file at: /Users/.../com.nccgroup.principalmapper/000000000000
```

That's `graph display`, both privesc queries, both analysis outputs, and the visualiser. The seventh, `graph list`, exited 0 and printed:

```
Account IDs:
---
```

The only command that succeeded is the one whose job is to tell you there's nothing there.

Under my rubric, a tool that errors or silently skips a principal grades **Missed** on the affected scenarios, because a reviewer gets nothing and the reason doesn't change that. So the default PMapper column is 86 rows of M. I tally those separately from detection misses all the way through. A tool that can't run is a maintenance finding, a tool that runs and misses is a detection finding, and blending them gives you a column that misleads in both directions. What PMapper does when it *does* run is section 4's subject, and it's not what this section implies.

I'm recording one observation, not a reproduction rate. I don't know whether that endpoint times out again. I saw it once and I'm reporting it once. The defect itself isn't environmental though. It doesn't depend on my network, my credentials, or my region set. Any unreachable endpoint among the hundreds this loop touches produces it, and `autoscaling_edges.py` sits on the only code path that builds the graph. The line is unchanged on upstream `master`, whose HEAD is dated **2022-02-03**.

### The same problem, one layer down

Getting to the crash took longer than the crash did.

`pip install principalmapper` succeeds on the Python this machine ships with, resolving current versions of all four dependencies without a warning. Then every invocation fails at import:

```
File ".../principalmapper/util/case_insensitive_dict.py", line 34, in <module>
    from collections import Mapping, MutableMapping, OrderedDict
ImportError: cannot import name 'Mapping' from 'collections'
```

Those aliases were deprecated in Python 3.3 and removed in **3.10**. The import sits at module scope on the path every subcommand takes, so the tool doesn't degrade or warn, it just can't start. And `setup.py` declares `python_requires='>=3.5, <4'` while the README says "Python 3.5+", both of which are false above 3.9. Since the declared range is satisfied, pip installs happily on 3.10 through 3.13 and you find out by running the tool.

For contrast, and the contrast is the point rather than a courtesy: cloudfox took under a minute. Download the release binary for your platform, verify the SHA-1 the release publishes, run it. No toolchain, no interpreter, no quarantine attribute. Worked first try. I only recorded it in the install log because the difference matters.

The real ceiling is Python 3.9, which reached end of life in October 2025. I installed it via Homebrew, which told me:

> Deprecated because it is deprecated upstream! It will be disabled on **2026-10-15**.

Six weeks after this run, the only interpreter that runs PMapper as published is one Homebrew stops distributing.

Worth noting that nothing needed pinning except the interpreter. `setup.py` pins no dependency versions at all, and the 2022 code works fine against 2026 botocore. The rot is in one import and one metadata declaration.

I didn't patch it. Changing that line to `from collections.abc import Mapping` is a one-word fix that would have let PMapper run on 3.13, and I turned it down: the benchmark grades the tool as it ships, and a patched PMapper isn't what `pip install principalmapper` gives you. Installing an old interpreter leaves the thing under test byte-identical to the published release.

---

## 3. The other tool runs clean, finds no paths, and doesn't look for them

cloudfox ran without any trouble. One command, `cloudfox aws all-checks -p personal -y`, produced fifteen CSVs and their JSON equivalents: 94 principals, 6,008 permission grants, 43 active access keys, 44 role-to-principal trust edges, 17 role-to-service edges, three resource policies. Nothing crashed and nothing needed a flag.

One of the columns it emits is `CanPrivEscToAdmin?`. It shows up 140 times across four output files, once for each of the 94 principals, once for each of the 44 trust edges, once for the account's single root-trust finding, and once for its single workload. In this run all 140 instances read:

```
"CanPrivEscToAdmin?": "Skipping, no pmapper data",
```

cloudfox has no path finder. It delegates privesc path enumeration to PMapper, and it's unusually upfront about it. Three places, at increasing volume.

The wiki page that cloudfox itself prints a link to during the run:

> Cloudfox will not install or run `pmapper` for you, but because `pmapper` stores it's graph data in a predictable location, this CloudFox command will look to see if that data exists, and if it does, it give you a list of all of the principals that pmapper thinks can escalate to admin.

The console, mid-run:

> `[iam-simulator][personal] We suggest running the pmapper commands in the loot file to get the same information but taking privesc paths into account.`

And then the loot file itself, `loot/iam-simulator-pmapper-commands.txt`, sixteen lines, one `graph create` and fifteen `query` invocations, every one of them `pmapper` and none of them cloudfox:

```
pmapper --profile personal graph create
pmapper --profile personal query "who can do sts:AssumeRole with *" | tee ...
pmapper --profile personal query "who can do iam:PassRole with *" | tee ...
pmapper --profile personal query "who can do secretsmanager:GetSecretValue with *" | tee ...
...
```

The tool that ran successfully wrote me a shell script for the tool that hadn't run yet.

This is deliberate, and cloudfox's documentation is clear about the trade it's making. Without PMapper data, its fallback answers *who is an admin* rather than *what paths exist*, and it says so. The fallback "is really just a wrapper around AWS's IAM simulate principal policy API call." The same page calls PMapper "the most accurate open source AWS policy simulator project that takes into account privilege escalation." cloudfox v2.0.5 shipped 2026-05-26 and it points at a project whose last commit is dated 2022-02-03.

Two consequences follow, and I want to be careful about the scope of each.

**The narrow one is about my matrix.** My rubric grades a category N/A only where the tool's own documentation explicitly disclaims it, quoted and linked. cloudfox clears that bar for path enumeration, so its path column is N/A on all 86 rows, recorded rather than scored as a miss. But the N/A applies to that column, not to cloudfox as a tool. Reading the disclaimer generously enough to void every miss would make the matrix meaningless, so everything cloudfox computes itself (`permissions`, `principals`, `iam-simulator`, `role-trusts`, `lambda`, `workloads`) is graded normally, and that's where its results in section 4 come from.

**The broader one is about what I was actually able to measure.** I set out to compare two tools on path detection and found I had one path-enumeration engine and one tool that renders its output. If PMapper's graph had been on disk when cloudfox ran, `CanPrivEscToAdmin?` would have been a rendering of PMapper's answer, and I'd have graded the same engine twice under two names while thinking I had two data points. That only didn't happen because I ordered the runs to prevent it. cloudfox ran first, on a machine where PMapper had never run, with `~/.local/share/principalmapper` and `~/Library/Application Support/com.nccgroup.principalmapper` both confirmed absent immediately beforehand. It's recorded in both run metadata files.

I'm not claiming to have surveyed the ecosystem, I ran two tools. What I can say from those two is that the actively maintained one doesn't enumerate paths and refers you to the one that does, and the one that does has been dormant for four and a half years and, in section 2, threw away its entire graph on a connect timeout. Anyone putting together a comparison of open-source AWS IAM path finders should check whether the second column is reading the first one's output off disk before treating them as independent evidence.

---

## 4. What the tools found

PMapper detected 20 of the 23 canonical escalation mechanisms in this lab. Its default invocation returns nothing at all. Both sentences describe the same tool on the same account on the same night, and the rest of this section is an attempt to hold them together without letting either one swallow the other.

### Before the numbers: this lab is the tools' home turf

`iam-vulnerable` implements Rhino Security Labs' catalogue of AWS privilege escalation methods, and both PMapper and cloudfox were largely built to detect that catalogue. A high score on it is the expected outcome and is close to worthless as evidence of quality, because all it measures is whether a tool detects the list it was written against.

So the numbers below are a control, not a verdict. What's actually informative sits in three narrower places: the mechanisms a tool misses *despite* the home-turf advantage, the paths it reports that don't work, and the rows outside the catalogue. I report the control anyway, because without it none of the rest is calibrated, and because a benchmark that only publishes its interesting cells isn't a benchmark.

### The denominators

The lab's 46 mechanisms and 86 principal rows don't all pose the same question, so they're counted in three buckets and never pooled.

**Detection: 31 mechanisms, 52 rows.** A real path with a live target. This is the D/P/M ladder and the headline.

**Target-absent: 8 mechanisms, 16 rows.** The grant is real and the thing it needs to point at doesn't exist here. No EC2 instances, no SSM-managed nodes, no CloudFormation stacks, no SageMaker notebooks, and Glue dev endpoints retired account-wide by AWS. Verified across all 17 enabled regions and excluded from every detection count.

**No-path: 18 rows.** Nothing to detect. Five of these are the lab's designed false-positive fixtures: `Allow` and `Deny` in one policy, `Deny iam:*` with no allow, a resource constraint scoped to the unwritable AWS-owned policy namespace. Correct behaviour is silence, so these grade *Correctly Silent* or *false positive*, never on the detection ladder.

The remaining six no-path rows weren't in that bucket when I started. They moved there because of a mistake I made, and that mistake is section 5.

**One caveat travels with every PMapper number below.** They come from a rerun with `--include-regions` restricted to the account's 17 opted-in regions, which is the flag I used to route around the crash in section 2. It's detection-neutral by construction, since AWS doesn't let you create resources in a region an account hasn't enabled. It's still non-default, and my rubric forbids merging a flagged run into a default score. The default column is 86 rows of Missed. Every number in this section is the flagged run.

### Detection bucket

**31 mechanisms:**

| | D | P | M | N/A |
|---|---:|---:|---:|---:|
| PMapper, default | 0 | 0 | **31** | 0 |
| PMapper, region-scoped | **27** | 0 | 4 | 0 |
| cloudfox, own surfaces | 3 | **26** | 2 | 0 |
| cloudfox, path column | 0 | 0 | 0 | **31** |

**52 principal rows:** PMapper region-scoped D 44 / M 8; cloudfox 3 D, 47 P, 2 M.

Restricted to the canonical Rhino catalogue with a live target (23 mechanisms, 40 rows), PMapper detects 20 of 23 mechanisms and 34 of 40 rows. cloudfox detects none of them and partials 21 of 23.

### The two tools have different shapes, and the grades are mostly measuring that

**PMapper produced zero Partial grades.** Not few, none. It has no partial output form. A principal is on the privesc list with a named target and a named mechanism, or it's absent. That's what a graph gives you, since the edge either closes or it doesn't.

**cloudfox produced 47 Partials out of 52 rows, and that isn't a failure grade.** Its `permissions.csv` is 6,008 rows of `(principal, policy, effect, action, resource, condition)`. Every dangerous permission in this lab is in there, bound to the specific principal that holds it. My rubric's bar for partial credit is exactly that binding, and a list of scary permission names with no principal attached would have been Missed. cloudfox clears the bar comprehensively and then stops one step short of a claim. It tells you `privesc10-PutUserPolicy-user` can call `iam:PutUserPolicy` on `*`. It doesn't tell you that this makes the user an administrator.

The clearest single comparison in the whole matrix is the lab's three-role assume-role chain. cloudfox's `role-trusts-principals.csv` contains this row:

```
ending-role | Trusted Principal = intermediate-role | IsAdmin? = YES
```

and one row later:

```
intermediate-role | Trusted Principal = starting-role | IsAdmin? = No
```

Every hop of the chain is in cloudfox's output, but the chain isn't. Nothing in those two rows joins them, and my rubric scores hop 1 without the chain as Partial. PMapper prints both hops under a single heading and scores Detected. That pair of cells is the most economical statement I can make about what a path finder buys you, and it isn't better data, since cloudfox's underlying data is arguably richer. It's the join.

The three rows where cloudfox does reach Detected are the two roles it names outright (`iam-simulator` says *"Appears to be an administrator"* and `principals.csv` sets `IsAdminRole? = YES`), plus that first trust row, where principal, trust edge and administrative target happen to land on one line. I flagged the third as inferred, because the grade comes from me joining two columns rather than from any escalation statement cloudfox makes.

### The four mechanisms PMapper misses

Three are confirmed working paths. One rests on ground truth I couldn't confirm.

**`privesc13-AddUserToGroup`.** I validated this by exercising it. The role added a zero-permission user to `privesc-sre-group`, and that user immediately held `iam:CreateUser` and `iam:AttachUserPolicy`. I restored the membership afterwards. PMapper models group edges for permission resolution but doesn't surface `AddUserToGroup` as an escalation into an admin-carrying group.

**`fn3-exploitableConditionConstraint`** is the pointed one. The lab wraps `iam:CreatePolicyVersion` in a condition, `DateGreaterThan aws:TokenIssueTime 2020-01-01`, which is always true. AWS's own simulator allows the action once the context key is supplied. PMapper reports the sibling fixtures `fn2` (a resource constraint that looks limiting but matches the principal's own policy) and `fn4` (a `NotAction` that still permits `iam:PutUserPolicy`) as administrative, and drops only the condition-wrapped variant. That's precisely the failure mode `fn3` was built to expose.

**`privesc17-EditExistingLambdaFunctionWithRole`** is a miss by design. PMapper draws edges only toward principals it has already determined are administrative, and this scenario's only reachable target is a pre-existing `EC2-AutoRemediation` function whose role grants EC2 read, tagging and logs. That role isn't administrative. The path is real and the miss is genuine. The same design decision is why PMapper didn't overstate it, which matters further down.

**`privesc21-PassExistingRoleToNewDataPipeline`.** PMapper has no Data Pipeline edge check. But AWS Data Pipeline is closed to new customers and I never attempted to create a pipeline in this account, so whether the target exists at all is inferred rather than confirmed. The cell stays flagged. It's one of only four PMapper misses, which means it carries more weight than an unconfirmed row should have to.

cloudfox misses none of these outright, since it binds every one of the enabling permissions to every principal that holds it. It connects none of them to a target either.

### Four false positives, all PMapper, all the same mistake

PMapper reported 32 escalation paths and asserted 17 principals administrative. cloudfox reported 0 escalation paths and made 78 `iam-simulator` assertions. Against those denominators, and within a validated sample of 22 principal rows across 19 files: **PMapper 4 confirmed false positives, cloudfox 0.** That's a count from a sample rather than a rate. I didn't check the whole population and I won't imply I did.

All four are the same error, twice over. PMapper asserts, on its primary surface and again in its analysis report at severity High:

```
user/privesc-ssmSendCommand-user can call ssm:SendCommand to access an EC2
   instance with access to role/privesc-high-priv-service-role
```

There is no such instance. Zero EC2 instances and zero SSM-managed nodes across all 17 enabled regions. PMapper's own supporting finding gives away the inference: *"The following IAM Roles are attached to at least one instance profile."* It's reasoning from the existence of an **instance profile** on the administrative role to the existence of an **instance** carrying it. The profile is real, the instance isn't.

What makes this a false positive rather than a modelling preference is the contrast sitting next to it in the same account. `privesc3-CreateEC2WithExistingInstanceProfile` uses the *same* instance profile and *is* a working path, because that principal holds `ec2:RunInstances` and creates the instance it then uses. The SSM principals hold `ec2:DescribeInstances` and the SSM actions and nothing else, so they can only act on an instance that's already there, and there isn't one.

To be exact about what this isn't: PMapper isn't wrong about the permission, the mechanism, or the risk. In an account with SSM-managed instances the path works. It's a false positive about *this account*, because PMapper reasons over declared IAM state and doesn't check whether the compute its path traverses exists. That's a design boundary and worth naming as one, because in section 5 the same declared-state-only reasoning produces the identical error in my ground truth, running the other direction.

Three other candidates I validated and cleared. The sharpest was `privesc17` overstating impact, since the reachable Lambda target grants EC2 read and tagging rather than admin, so a tool calling it a path to administrator would have been wrong. Neither tool did. PMapper doesn't report it at all, and cloudfox lists the role with `IsAdminRole? = No`. Both correct, by different routes.

Neither tool reported any of the five designed false-positive fixtures, so both were silent where silence was the right answer. That result is worth stating and discounting in the same breath, because a tool that reports nothing anywhere passes every false-positive test ever devised, which is why the crashed PMapper column scores those rows as crash-Missed rather than crediting it for silence it didn't choose.

### Two things that only show up in the error log

cloudfox's `iam-simulator` exhausted its three retries on `SimulatePrincipalPolicy … Throttling: Rate exceeded` for three principals. My rubric makes the affected scenarios Missed, which costs cloudfox two detection grades. The sharper problem is that **those failures are invisible in cloudfox's output.** The three principals still appear in `principals.csv` with `IsAdminRole? = No`, indistinguishable from a genuine negative. Only `cloudfox-logs/cloudfox-error.log` knows the question was never answered.

The second is what happened when I reran both tools as a `SecurityAudit` user instead of an administrator. I predicted a materially reduced output surface, and I was wrong, not marginally. PMapper's privesc output is **byte-identical** between the two contexts: same 32 paths, same 17 administrative principals, same ordering, same 10,520 bytes. Its analysis report differs by one line, the timestamp. cloudfox's 94 principals are field-for-field identical including `IsAdminRole?`, and `permissions.json` compares equal once the new principal's own 1,031 grant rows are removed. `SecurityAudit` grants enough IAM read access that neither tool notices the difference. That result is about this policy, not about low privilege in general. A principal missing `iam:ListRoles` would have produced a very different and much less interesting answer.

The error logs do differ, though, and that difference is the finding. cloudfox's `Glue: ListDevEndpoints` call fails 17 times under administrator with `InternalFailure`, which is what AWS returns for a feature it has retired, and is the evidence my scenario list cites for two mechanisms having no target. Under `SecurityAudit` the same call fails 17 times with `AccessDeniedException`. **The report looks identical either way.** An auditor holding `SecurityAudit` can't distinguish *this capability no longer exists* from *I wasn't allowed to look*, and both render as an absent section.

### Scoring my own predictions

I wrote five predictions into the frozen rubric before deploying anything. Four were wrong or unanswerable.

I predicted both tools would detect at least four fifths of the canonical mechanisms. PMapper clears the bar at 20 of 23 and cloudfox scores zero, because its path column is disclaimed and its own surfaces stop at Partial. The prediction failed on the word "both". It didn't anticipate a tool graded on a partial-credit surface and it didn't anticipate a crash. I predicted the limited context would degrade both tools, and it didn't. I predicted PMapper would produce more Partials than Detecteds on multi-hop chains, but it produced no Partials at any point and detected both chain hops, so the prediction wasn't testable as written and was wrong in spirit. I predicted at least one false positive, and there were four. The fifth prediction concerns the OIDC scenarios and is unresolved, which is section 6.

---

## 5. My ground truth was wrong, and the tool was right

Six mechanisms in the lab exist in two variants, one held by a user and one by a role, with identical permissions: `iam:AttachUserPolicy`, `iam:PutUserPolicy`, `iam:AttachGroupPolicy`, `iam:PutGroupPolicy`, `iam:AttachRolePolicy`, `iam:PutRolePolicy`.

On the first pass PMapper reported exactly one variant of each and not the other, and my matrix scored the missing six as misses. That asymmetry is the reason my rubric requires both a mechanism-level and a per-principal denominator, since a tool catching one variant of a mechanism and missing its twin is a real finding that a mechanism-level rollup hides. I flagged it as the top validation priority and wrote it down as PMapper being inconsistent.

It isn't inconsistent. It's right, and I was wrong.

I validated all six by hand, one file each. Every one holds exactly one grant, and in every case that grant targets a construct the principal isn't.

`iam:AttachUserPolicy` and `iam:PutUserPolicy` operate on users. The role variants can't point them at themselves. They also hold no key-minting permission, and roles carry no access keys, so there's no route to authenticating as any user they could empower.

`iam:AttachGroupPolicy` and `iam:PutGroupPolicy` operate on groups. A role can't be a member of an IAM group, the API doesn't allow it, so the role variants can make a group administrative and can never be in it.

`iam:AttachRolePolicy` and `iam:PutRolePolicy` operate on roles. The user variants can write `AdministratorAccess` onto any role in the account and can assume none of them, since each is named in no trust policy and holds no `sts:AssumeRole`, no `iam:UpdateAssumeRolePolicy`, and no `iam:PassRole`.

In every case the variant PMapper *did* report is the one that can point the permission at itself. Its graph records the distinction directly, marking those six principals `is_admin: true` and these six `is_admin: false`. The rule is legible once you see it: **PMapper reports a principal where the principal can escalate itself**, not where the principal can escalate something.

My scenario list didn't make that distinction, because it couldn't. I generated it from Terraform state and `iam get-account-authorization-details`, which gives you principal, permission, resource. That's the right source for an inventory and it's silent on whether a principal can reach what its permission empowers. Six of my 86 rows asserted a path that doesn't close.

My rubric anticipated this case in the abstract ("a Missed that turns out not to be a real path is a scenario-list error, not a tool miss"), so the six rows were reclassified out of the detection bucket and into a class with no path to detect. Here's what that did to the headline:

| | before | after |
|---|---|---|
| Detection bucket, mechanisms | D 21 of 31 | **D 27 of 31** |
| Detection bucket, rows | D 44 of 58 | **D 44 of 52** |
| Canonical catalogue, mechanisms | D 14 of 23 | **D 20 of 23** |

D didn't move, the denominator did. PMapper detected 44 rows before the correction and 44 rows after it. Nothing about its output changed, since the same file was graded twice against two versions of the ground truth. Reading this as PMapper improving would be wrong, and the four-fifths threshold it now clears in section 4 is one it clears because I fixed my list, not because it found anything more.

The general form of the mistake is the part worth carrying away. A list derived from declared IAM state is a list of grants, and a path finder answers a question about reachability. Grading the second against the first manufactures misses, and it manufactures them in a specific, non-random direction: against exactly the tools that model reachability correctly. A cruder tool that flagged all twelve variants would have scored better on my list than PMapper did, for being less right.

The fix has a name and I didn't run it. An `iam:SimulatePrincipalPolicy` sweep across the principal-by-action matrix gives you a path oracle sourced from AWS's own policy evaluator, independent of both graded tools and free of the catalogue bias in section 4. My rubric names it and puts it out of scope to keep the phase bounded. This section is the cost of that decision, paid in six rows I corrected by hand after they'd already been scored.

There's a symmetry here I didn't plan and can't take credit for. In section 4, PMapper reasons over declared IAM state and asserts a path through an EC2 instance that doesn't exist, giving four false positives. In section 5, I reason over declared IAM state and assert six paths that don't close, giving six manufactured misses. Same blind spot, same cause, opposite directions, one of them in the tool and one in the benchmark grading it.

Three caveats, because this section is flattering to PMapper and I don't want it to flatter further than the evidence goes.

**The six principals aren't harmless.** Each can make another principal administrative, and two of them are users holding live access keys, which makes them usable starting points for someone who has them. What they can't do is escalate themselves, which is what my Detected grade measures and what PMapper's model tracks. A reader whose threat model is "an attacker with these keys can leave an administrative principal behind for later" is looking at something my matrix doesn't score. Every validation file says so and so does this section.

**PMapper's rule isn't universally correct, and the lab contains the counterexample.** `privesc13-AddUserToGroup` is the mirror image. There the group *is* reachable, because the user adds itself to it, and I confirmed the escalation by exercising it. That's a self-escalation path by PMapper's own criterion, and it's one of the four mechanisms PMapper misses. The rule is right about these six rows and doesn't save it there.

**The late-additions bucket is empty.** My rubric reserved a separate tally for working paths discovered during validation that the scenario list never showed, and I found none. Given that I never ran the oracle that would systematically look for them, that empty bucket is a fact about my method rather than a finding about the account. Forty-one of the 344 graded cells remain flagged as inferred rather than read from output or a validation file, and the flag is a published column rather than a caveat in prose.

---

## 6. The edge I had to build, and what AWS does about it

`iam-vulnerable` ships no web-identity scenario. There's no OIDC provider in it, no SAML provider, and no federated trust of any kind, which is why cloudfox's `role-trusts-federated.csv` came back with zero rows in section 4. The surface exists in the tool, there was just nothing in the account for it to hold.

So I built one, after the matrix was finished and frozen. Thirteen resources in a separate Terraform state, deployed 2026-08-30, never folded into any denominator in this post. **I didn't run either tool against them.** What follows is a measured fact about AWS, a measured fact about reachability, and an argument about architecture, in that order and clearly separated. The thing everyone wants me to claim here is the one thing I didn't test.

### The shape

Two chains, two hops each, structurally identical. **The hop-1 trust policy is the only variable between them.** The thin entry permission, the tight hop-2 trust, and the administrative terminus are held constant, so any difference in outcome is attributable to the trust condition and nothing else.

Hop 1 is a GitHub Actions deploy role, assumable by web identity, whose only permission is `sts:AssumeRole` on exactly one named role. Hop 2 is that role: `Allow *:*`, with a trust policy naming exactly one principal, the entry role, and nothing else.

Hop 2 is correct in both chains. Its trust is as tight as a trust policy gets and its permissions are what a Terraform execution role legitimately needs. The chain is open anyway, because hop 1's front door is open. That asymmetry is the whole scenario: every control on the valuable resource is right, and it doesn't matter.

### Scenario A was supposed to be the strawman, and AWS refused to build it

Scenario A is the floor case, a `sub` condition that matches every repository on GitHub. Indefensible on sight, and present only to be the baseline that Scenario B is measured against.

I first wrote it with **no `sub` condition at all**, which is the canonical version of this misconfiguration. `CreateRole` refused, verbatim:

```
MalformedPolicyDocument: Trust policy with trusted principal
arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com must
evaluate, using StringEquals, StringLike or StringEqualsIgnoreCase,
token.actions.githubusercontent.com:sub or
token.actions.githubusercontent.com:job_workflow_ref which is not scoped to all.
```

This wasn't in my plan. AWS ships a guardrail against precisely the misconfiguration I was trying to deploy. The obvious conclusion, that the floor case can't exist any more, is wrong, and finding out why took four `create-role` calls against a throwaway role I deleted immediately after.

One variable, four candidates:

| `sub` condition | `CreateRole` |
|---|---|
| *(absent)* | **REJECTED** |
| `StringLike "*"` | **REJECTED** |
| `StringLike "repo:*"` | **ACCEPTED** |
| `StringLike "repo:*/*"` | **ACCEPTED** |

Every default-format GitHub Actions subject claim begins with `repo:`, as in `repo:<owner>/<repo>:ref:refs/heads/main`, `repo:<owner>/<repo>:pull_request`, `repo:<owner>/<repo>:environment:prod`. So `repo:*` matches all of them. It admits the same set as the condition AWS had just refused, and AWS accepts it.

The check is a string test on the policy document. It isn't an evaluation of what the policy admits.

One caveat belongs here rather than at the end. GitHub lets an organisation customise the subject claim via `include_claim_keys`, producing a `sub` that needn't begin with `repo:`. For such an organisation, `repo:*` matches nothing. That isn't the default and isn't the common case, so the precise claim is "matches every default-format Actions subject claim," not "matches every Actions token."

Two things follow. A reviewer, an auditor, or an automated check that treats *a `sub` condition is present* as the control is measuring the same property AWS's guardrail measures, and is wrong in the same way. And the rejection message is specific and educational, which makes it *more* likely, not less, that an engineer who hits it pastes in the first pattern that gets accepted.

That failure mode already showed up once in this post, in a different tool at a different layer. In section 4, `permissions.csv` prints `Condition=Yes` for the lab's always-true `DateGreaterThan` fixture and `Condition=Yes` for its never-true `DateLessThan` twin. Identical rows, one exploitable and one inert, because the column records that a condition exists rather than what it permits. The same file renders the `Resource` column verbatim, which is why the resource-constraint pair *is* separable from the same output. Presence of a constraint is cheap to check and tells you very little. What the constraint admits is the whole question, and it's the part that keeps getting dropped.

### Scenario B is the one that ships

```json
"StringLike": { "token.actions.githubusercontent.com:sub": "repo:iam-tool-benchmark-lab/*" }
```

`sub` is present, it's `StringLike`, and it names an organisation. It passes a skim review and it looks like the documented pattern.

What it admits is every repository under that organisation: every branch, every tag, every environment, every `pull_request` run, and every repository created after the review by anyone who can create one.

| | |
|---|---|
| enforced | `repo:iam-tool-benchmark-lab/*` |
| intended | `repo:iam-tool-benchmark-lab/deploy:ref:refs/heads/main` |

One asterisk apart. B is the headline and A is the strawman, since A is caught by inspection and, as of now, half-caught by AWS itself. B is caught by neither.

### What's measured about reachability, and what's only argued

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

No principal inside this account can reach any of the four roles, including the account administrator. Two consequences, both factual. These thirteen resources add zero intra-account escalation paths, so the graded matrix in section 4 is unaffected as a matter of fact rather than just of ordering. And the only route into either chain is `sts:AssumeRoleWithWebIdentity` presenting a GitHub-issued token.

The argued part is what that implies. An account-internal graph is built from the principals, policies and trust relationships the account contains. In PMapper's case that's `get-account-authorization-details` plus nine per-service edge checks, all of them enumerating in-account resources. The first edge of both chains originates outside that boundary, at an identity provider, and its admissibility turns on string-matching a claim in a token that the account doesn't issue and never sees at graph-build time. Nothing in the denial table above is visible as an edge to anything reasoning over in-account state alone.

That's an argument about where the boundary of a graph falls. It isn't a measurement and I'm not converting it into one. cloudfox has a federated-trust surface, and what that surface would have produced against these four roles is untested, because I didn't point it at them.

### What isn't proven

End-to-end exploitability of both chains is **inferred, not demonstrated**. Confirmed: the trust policies exist as written, AWS accepted them, the permission policies grant the hop, hop 2 holds `Allow *:*`, and no in-account principal can reach either chain. Not confirmed: that a real GitHub Actions token satisfies these conditions and yields administrator. Proving it needs a repository running a workflow with `id-token: write`, calling `AssumeRoleWithWebIdentity` and then `AssumeRole` on hop 2. No such repository exists and I didn't run one.

The inference rests on the documented format of the Actions `sub` claim and on AWS's own condition-evaluation semantics. Both are well documented and the inference is strong. It's still an inference, and it applies equally to Scenario A and Scenario B.

### This is a live trust in a live account

Worth saying plainly, because anyone reproducing it should understand what they're standing up. Scenario A's entry role can be assumed by anyone who runs a GitHub Actions workflow and knows the role ARN, and the only thing between it and account administrator is that the ARN isn't published. Scenario B's entry role can be assumed by anyone who controls a repository under the GitHub organisation `iam-tool-benchmark-lab`, a name I chose because it was unregistered, checked against `api.github.com/orgs/…` and `/users/…` immediately before apply, both HTTP 404. **If someone registers it, they get administrator in that account.**

Hence the handling. The account ID stays out of the repository behind a published one-way substitution, the repository stayed private until this post, and teardown here is more urgent than for the main lab. `iam-vulnerable`'s principals are exploitable by someone who already holds credentials in the account. These two are exploitable by someone who holds none.

---

## 7. What this doesn't show

The caveats attached to individual claims are next to those claims. These are the limits on the whole exercise.

**Everything here is n=1.** One AWS account, one lab deployment, one run per tool per context, on 2026-08-31. The connect timeout in section 2 is a single observation and I report it as one, since I don't know how often that endpoint fails to answer. The defect it exposes doesn't depend on my network or my region set, but the frequency does, and I have no data on it.

**Two tools isn't a survey.** The claim in section 3 is about what I could measure with the two tools I ran: one enumerates paths, the other renders its output and says so. I didn't review the field.

**`SecurityAudit` is one point on a spectrum, not "low privilege."** The null result in section 4 says these two tools produce near-identical output under that specific AWS-managed policy. A principal missing `iam:ListRoles` would have produced a different answer and a much less interesting one.

**Target absence was verified by resource-existence checks, not by exploitation.** Across all 17 enabled regions I confirmed there are no EC2 instances, no SSM-managed nodes, no stacks, no notebooks. I didn't launch an instance to confirm that the SSM paths in section 4 would then work. The false-positive determination rests on the absence of the resource the reported path traverses, which is enough for *this path doesn't work as the account stands* and isn't a claim about the mechanism in general. The same goes the other way: a target being present means a target exists, not that the path has been driven end to end.

**Validation is sampled.** Nineteen files covering 22 of 86 principal rows. Every false-positive count in this post is *found in a sample of 22 validated rows* rather than a rate, because I didn't check the population. Forty-one of 344 graded cells remain flagged as inferred rather than read from output or a validation file, and one of PMapper's four misses, the Data Pipeline mechanism, rests on ground truth I never confirmed, since Data Pipeline is closed to new customers and I never attempted to create one.

**Grading is unweighted.** A missed four-hop chain to account administrator scores the same as a missed single hop to a low-value target. Weighting needs an impact model I don't have, and building one after seeing results is the failure the frozen rubric exists to prevent. It does mean the counts in section 4 flatten a real difference in severity.

**One rubric requirement I satisfied on a reading rather than to the letter.** I required at least three scenarios graded Missed by *all* tools to be validated, and wrote three: `privesc2`, `privesc13`, `fn3`. Under the final grades, no row is Missed in every column, because cloudfox's principal-bound permission dump earns Partial on all three. I validated them as *Missed on the escalation question*, which is what the requirement was for and how the files were written. Stating the choice rather than quietly satisfying the weaker version of it.

**No independent path oracle was run**, which is the load-bearing one. Without a `SimulatePrincipalPolicy` sweep, my scenario list enumerates declared grants and nothing systematically looked for paths the lab's author didn't place. Section 5 is what that cost when it went wrong in a direction I could detect. It says nothing about what it cost in the direction I couldn't.

---

## 8. Reproducing this

Everything is in the repository: the rubric, frozen in git before the lab was deployed and append-only afterwards, so `git log -p analysis/rubric.md` shows what I committed to before I saw any output; the scenario list; `grades.csv`, one row per `(scenario, tool, context, flagset)`, 344 of them, each carrying its evidence path and the exact search string used to reach the grade; the validation files with their commands and outcomes; and `matrix.md`, written by hand from `grades.csv` with no generator in between.

Raw tool output is committed unedited except for one published, one-way substitution. `redact.sh` replaces the account ID and access key IDs with fixed placeholders, in file contents and in path components, and the script is committed alongside the output it produced. "Unedited" means "unedited modulo one auditable rule." Any grade in the matrix can be checked against its source.

**Versions.** cloudfox `2.0.5` (release binary, commit `ba4ff47`, published SHA-1 verified against the release's own `sha1sum.txt`). PMapper `1.1.5` (tag `d5136ff`, wheel uploaded 2022-01-13; `master` HEAD `91d2e60`, dated 2022-02-03), on Python `3.9.25`. `iam-vulnerable` at `0f29866`. Terraform `1.14.8`, `hashicorp/aws` `6.62.0`.

**One reproduction hazard.** PMapper 1.1.5 doesn't import on Python 3.10 or later, and the Homebrew build of `python@3.9` I used is scheduled for disablement on 2026-10-15. Anyone repeating this after that date will have to source a 3.9 interpreter another way or patch the import, and a patched PMapper is a different artifact from the published one, which is why I didn't patch mine.

**Account hygiene, because the lab is exactly what it says it is.** Dedicated personal sandbox account, never an account connected to anything else I touch. A named CLI profile used explicitly on every call, with `sts get-caller-identity` confirmed before anything ran. `iam-vulnerable` creates users, roles and access keys that exist specifically to escalate to administrator, so it isn't something to point at a shared account.

**Teardown is containment, not tidying.** There are two Terraform roots and both need destroying:

```
cd lab-oidc && terraform destroy   # 13 resources, do this one first
cd ../lab   && terraform destroy   # 265 resources
```

The OIDC root goes first for the reason in section 6: those two chains are reachable by someone who holds no credentials in the account at all, and one of them depends on a GitHub organisation name staying unregistered. The main lab is the opposite risk and a larger one in volume. It creates 41 `aws_iam_access_key` resources, so `lab/terraform.tfstate` holds **41 live AWS secret access keys in plaintext**, one per lab user, every one attached to a principal built to reach administrator. The file is gitignored and won't be committed. It's still credential material sitting on a laptop, and those keys stay valid until they're deleted. Confirm with `terraform state list` returning empty.

Two things neither destroy removes, deliberately: the purpose-made `SecurityAudit` user, and the pre-existing `EC2-AutoRemediation` Lambda that's the only reachable target for one of the scenarios.

I have my own IAM tool. It isn't in this benchmark, its test fixtures were deleted from the account before grading, and the reason for both is that a baseline is only worth having if it was built before the thing it's meant to measure.