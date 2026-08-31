# Two AWS IAM privesc tools, one path finder

*A per-scenario detection matrix for PMapper and cloudfox, and the six rows where my own answer key was wrong.*

> I spent two weekends running two open-source AWS IAM privilege-escalation tools against a deliberately-broken practice account (Bishop Fox's `iam-vulnerable`) and grading every result by hand, against a rubric I locked in before I started. That's 344 graded cells, 19 scenarios I checked by hand, and all the raw output published so anyone can check my work. Here's what I found — including the part where the tools were right and I was wrong.

---

## 1. What this is

Over two weekends I deployed Bishop Fox's `iam-vulnerable` into a throwaway AWS account and ran two open-source IAM privilege-escalation tools against it: **cloudfox (2.0.5)** and **PMapper (1.1.5)**. I graded every scenario the lab creates by hand, against a rubric I froze in git before I deployed anything. That gave me a 344-row grade file, 19 validation files with the exact commands I ran and what came back, and a per-scenario matrix. It's all published, raw output included. The only edit is swapping my account ID for a placeholder, and that script is in the repo too.

This isn't a shootout and there's no winner. It's small: two tools, one account, one run each. Where I say anything broader than "here's what happened on 2026-08-31," I show the reasoning.

**What I graded.** The lab stands up 265 resources. From those I pulled 46 escalation mechanisms across 86 `(principal, mechanism)` rows — built from the live account (`iam get-account-authorization-details` plus per-service checks), not from the lab's README. Each row got a grade per tool:

- **Detected:** the output names the principal, the permission, and the target it can reach.
- **Partial:** it ties a risky permission to a principal but stops there.
- **Missed:** nothing in the output would point you at the path.

I ran each tool twice: once as an admin, once as a user with only the AWS-managed `SecurityAudit` policy — the kind of read-only access a real auditor or scanning tool would have.

**Three things to know before the numbers.**

The lab is built from Rhino Security Labs' list of AWS privesc methods, and both tools were largely written to catch that list. So high scores are expected and don't prove much. The interesting cells are the misses, the false alarms, and anything off the list.

The lab names whoever deploys it in the trust policy of all 45 roles it creates. So under admin the whole graph points at my one user, which inflates the reachability numbers. That's the lab, not the tools.

I have my own IAM tool, `iamwho`, and I left it out on purpose — I wanted a baseline I hadn't shaped around my own work. Eleven old `iamwho` test resources were still in the account, so I deleted them (and the CloudFormation stack behind them) before grading. That cost me one scenario: `privesc-CloudFormationUpdateStack` needs a stack to attack, and mine was the only one there. Grading it would have meant scoring the tools against my own leftovers.

**What I didn't test.** Runtime detection. Cross-account and org-level paths. SCPs and permission boundaries beyond what the lab sets up. Resource policies other than role trust. Anything needing write access.

One more gap, and it caused the most interesting mistake I made: I never ran an `iam:SimulatePrincipalPolicy` sweep as an independent check. My answer key is just a list of who was granted what — section 5 is what that cost me.

Grading is unweighted. A missed four-hop path to full admin counts the same as a missed one-hop to nothing much. Ranking them would need an impact model I don't have, and making one up after seeing the results is exactly what freezing the rubric was meant to stop.

---

## 2. The default run gives you nothing

PMapper builds a map of every identity in an account and the links between them, then answers questions over the map. It all starts with `pmapper graph create`, so I ran that as admin against the fresh lab:

```
$ pmapper --profile personal graph create
```

It ran for five minutes fifty-two seconds and exited with an error.

The first four minutes look fine. It pulls the users, roles, groups and policies, works out who's already an admin, then starts checking for links — beginning with EC2 Auto Scaling, which means checking every region. My account has 17 regions on and AWS has many more, so most of those calls hit regions I can't use. PMapper is written to shrug those off:

```
19:23:21 | Unable to search region af-south-1 for launch configs. The region may be
           disabled, or the error may be caused by an authorization issue. Continuing.
19:23:21 | Unable to search region ap-east-1 for launch configs. ... Continuing.
19:23:22 | Unable to search region ap-east-2 for launch configs. ... Continuing.
```

Fifteen regions, fifteen "Continuing." Then the sixteenth:

```
botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint URL:
"https://autoscaling.me-south-1.amazonaws.com/"
```

and the whole thing dies at `autoscaling_edges.py:60`.

It comes down to one line. The code that catches "region didn't work, keep going" only catches one kind of error — a region *refusing* you (`ClientError`). The other fifteen regions all refused, so they got caught and shrugged off. `me-south-1` didn't refuse; it just went silent and timed out. A timeout is a different kind of error (`ConnectTimeoutError`, which isn't a `ClientError`), so it sails straight past the catch and kills the program.

The catch isn't missing. Someone wrote it for exactly this situation — they just aimed it at the wrong kind of error.

And a small miss becomes a total one, because of how PMapper is built. Auto Scaling is the first of nine checks it runs, and it doesn't save anything until all nine finish. There's no save-as-you-go. So the four minutes of good data it already had — the whole map — was sitting in memory unsaved when it crashed, and it's gone. One far-off region I don't even use took the entire run down with it.

Everything after this needs that saved file. I ran the other seven commands anyway, to see what a user actually gets. Six died the same way:

```
ValueError: Did not find file at: /Users/.../com.nccgroup.principalmapper/000000000000
```

The seventh, `graph list`, exited cleanly and printed:

```
Account IDs:
---
```

The one command that worked is the one whose only job is to tell you there's nothing there.

By my rubric, a tool that crashes or skips a principal gets **Missed** on those scenarios — a reviewer got nothing, and why doesn't change that. So the default PMapper column is 86 Misses. I keep those separate from real detection misses all the way through, because "can't run" and "ran and missed" are different problems, and blending them would mislead in both directions. What PMapper does *when it runs* is section 4 — and it's not what this section makes it look like.

This is one observation, not a rate. I don't know how often that endpoint times out; I saw it once and I'm reporting it once. But the bug isn't about my setup — any unreachable endpoint in this loop triggers it, and this loop is the only thing that builds the map. And the line hasn't changed on the project's main branch since **2022-02-03**.

### The same problem, one level down

Getting to the crash took longer than the crash did.

`pip install principalmapper` installs fine on the Python this machine ships with. Then every run dies immediately at import:

```
File ".../principalmapper/util/case_insensitive_dict.py", line 34, in <module>
    from collections import Mapping, MutableMapping, OrderedDict
ImportError: cannot import name 'Mapping' from 'collections'
```

That import was deprecated in Python 3.3 and removed in **3.10**. It's near the top of a file every command loads, so the tool can't even start. And the setup says it supports "Python 3.5+", which isn't true above 3.9 — so pip installs it happily on 3.10 through 3.13 and you only find out when you run it.

For contrast — and the contrast is the point: cloudfox took under a minute. Download the binary, check the hash, run it. No interpreter, no fuss, worked first try.

The real ceiling is Python 3.9, which hit end of life in October 2025. I got it from Homebrew, which warned me it'll stop shipping it on **2026-10-15**. So six weeks after this run, the only Python that runs PMapper as published is one Homebrew won't hand out anymore.

I didn't patch it. Changing that one line (`from collections.abc import Mapping`) would've let it run on 3.13, but I left it alone on purpose — the point was to test the tool as it actually ships, not a fixed-up copy only I have. So I installed the old Python instead.

---

## 3. The other tool runs fine, finds no paths, and never tries to

cloudfox ran without a hitch. One command, `cloudfox aws all-checks -p personal -y`, spat out fifteen CSVs and their JSON versions: 94 principals, 6,008 permission grants, 43 active access keys, 44 trust edges, and so on. Nothing crashed, nothing needed a flag.

One of its columns is `CanPrivEscToAdmin?`. It shows up 140 times, and in this run every single one reads:

```
"CanPrivEscToAdmin?": "Skipping, no pmapper data",
```

cloudfox has no path finder. It hands that job to PMapper, and it's upfront about it in three places.

Its own wiki, which it links to during the run:

> Cloudfox will not install or run `pmapper` for you, but because `pmapper` stores it's graph data in a predictable location, this CloudFox command will look to see if that data exists, and if it does, it give you a list of all of the principals that pmapper thinks can escalate to admin.

The console, mid-run:

> `[iam-simulator][personal] We suggest running the pmapper commands in the loot file to get the same information but taking privesc paths into account.`

And a file it writes for you, `loot/iam-simulator-pmapper-commands.txt` — sixteen lines, every one of them a `pmapper` command, none of them cloudfox:

```
pmapper --profile personal graph create
pmapper --profile personal query "who can do sts:AssumeRole with *" | tee ...
pmapper --profile personal query "who can do iam:PassRole with *" | tee ...
...
```

The tool that ran successfully wrote me a to-do list for the tool that didn't.

This is deliberate, and cloudfox says so. Without PMapper's data, its fallback tells you *who's an admin*, not *what paths exist* — and it calls that fallback "really just a wrapper around AWS's IAM simulate principal policy API call." The same page calls PMapper "the most accurate open source AWS policy simulator" for privesc. cloudfox 2.0.5 shipped in May 2026 and points you at a project whose last commit is from February 2022.

Two things follow, and I want to be careful about each.

**The narrow one, about my grading.** My rubric only grades something N/A if the tool's own docs say it doesn't do it. cloudfox clears that bar for path-finding, so its path column is N/A on all 86 rows — recorded, not counted as a miss. But that N/A is for that one column, not the whole tool. Everything cloudfox works out itself — permissions, principals, trust edges — is graded normally, and that's where its section 4 results come from.

**The broader one, about what I could actually measure.** I set out to compare two tools on path-finding and found I had one engine (PMapper) and one tool that just displays PMapper's output. If PMapper's map had been sitting on disk when cloudfox ran, that `CanPrivEscToAdmin?` column would have been PMapper's answer wearing cloudfox's name, and I'd have graded the same engine twice thinking I had two. That didn't happen only because I ran cloudfox first, on a machine where PMapper had never run and I'd confirmed its data folders were empty. It's noted in both run logs.

I'm not claiming to have surveyed the whole field — I ran two tools. But of those two, the maintained one doesn't find paths and points you at the other, and the other has been untouched for four and a half years and throws its whole map away on a timeout. If you're comparing open-source AWS IAM path finders, check whether your second tool is just reading the first one's output off disk before you treat them as two data points.

---

## 4. What the tools found

PMapper caught 20 of the 23 known escalation methods in this lab. Its default run gives you nothing. Both are true of the same tool on the same night, and this section is about holding those two facts together.

### Before the numbers: this is the tools' home turf

The lab is built from a known catalogue of AWS privesc methods, and both tools were largely built to catch that catalogue. So a high score here mostly proves the tool detects the list it was written for. The numbers below are a baseline, not a verdict — what actually matters is the misses despite the home advantage, the false alarms, and anything off the list. I'm publishing the baseline anyway, because without it none of the rest has context, and a benchmark that only shows its exciting bits isn't one.

### The three buckets

The 46 mechanisms don't all ask the same question, so I keep them in three buckets and never mix them:

**Detection — 31 mechanisms, 52 rows.** A real path with a real target. This is the headline.

**Target-absent — 8 mechanisms, 16 rows.** The permission is real but the thing it needs to attack isn't there: no EC2 instances, no stacks, no notebooks, and Glue dev endpoints that AWS has retired. Checked across all 17 regions. Left out of the detection count.

**No-path — 18 rows.** Nothing to detect. Five are the lab's on-purpose false-alarm traps, where staying quiet is the right answer. Six more moved into this bucket because of a mistake I made — that's section 5.

**One note on every PMapper number below:** they come from a rerun with `--include-regions` set to my 17 live regions — the flag I used to get around the crash. It can't change what's detectable, since AWS won't let you build resources in a region you haven't turned on. But it's not the default run, so I keep it labelled. The default run is 86 Misses; every number here is the flagged run.

### Detection bucket

**31 mechanisms:**

| | D | P | M | N/A |
|---|---:|---:|---:|---:|
| PMapper, default | 0 | 0 | **31** | 0 |
| PMapper, region-scoped | **27** | 0 | 4 | 0 |
| cloudfox, own surfaces | 3 | **26** | 2 | 0 |
| cloudfox, path column | 0 | 0 | 0 | **31** |

**52 rows:** PMapper D 44 / M 8; cloudfox 3 D, 47 P, 2 M.

On just the known catalogue with a live target (23 mechanisms), PMapper gets 20. cloudfox gets none, and lands on Partial for 21 of them.

### The two tools have different shapes, and the grades mostly measure that

**PMapper never scored Partial. Not once.** It has no middle setting — a principal is on the escalation list with a named target, or it isn't. That's what a map gives you: the link is either there or it isn't.

**cloudfox scored Partial on 47 of 52, and that's not a bad grade.** Its `permissions.csv` has all 6,008 grants, every dangerous one tied to the principal that holds it. That's exactly what earns Partial in my rubric — a bare list of scary permissions with no principal would've been a Miss. cloudfox nails that and then stops one step short. It'll tell you `privesc10-PutUserPolicy-user` can call `iam:PutUserPolicy` on `*`. It won't tell you that makes them an admin.

The clearest example in the whole matrix is the lab's three-role chain. cloudfox's output has this row:

```
ending-role | Trusted Principal = intermediate-role | IsAdmin? = YES
```

and one row down:

```
intermediate-role | Trusted Principal = starting-role | IsAdmin? = No
```

Every step of the chain is in there. The chain isn't. Nothing connects those two rows, so I scored it Partial. PMapper prints both hops under one heading and I scored it Detected. That's the whole value of a path finder in two cells — not better data (cloudfox's is arguably richer), just the connecting of it.

The three rows where cloudfox does hit Detected are two roles it flat-out calls admins, plus one trust row where the principal, the trust, and the admin target happen to land on the same line. I flagged that third one as inferred, since the grade came from me joining two columns, not from cloudfox saying "escalation."

### The four PMapper misses

Three are real paths it missed. One I couldn't fully confirm.

**`privesc13-AddUserToGroup`.** I tested this one live — the role added a no-permission user to an admin group, and the user instantly had admin. Put it back after. PMapper tracks group membership for working out permissions, but doesn't flag "add someone to an admin group" as an escalation.

**`fn3-exploitableConditionConstraint`** is the pointed one. The lab wraps a permission in a condition (`DateGreaterThan aws:TokenIssueTime 2020-01-01`) that's always true. AWS's own simulator allows it. PMapper catches the two sibling traps next to it and misses only this one — the condition-wrapped one. Which is exactly what that trap was built to catch.

**`privesc17-EditExistingLambdaFunctionWithRole`** is a miss by design. PMapper only draws links toward principals it's already decided are admins, and this one's target — a leftover `EC2-AutoRemediation` function — isn't an admin. The path is real; the miss is genuine. But that same rule is why PMapper *didn't* overclaim it, which matters below.

**`privesc21-PassExistingRoleToNewDataPipeline`.** PMapper has no Data Pipeline check. But Data Pipeline is closed to new customers and I never tried to make one here, so whether the target even exists is unconfirmed. I flagged the cell rather than count it clean.

cloudfox misses none of these outright, because it lists every permission against every principal that holds it. It also connects none of them to a target.

### Four false alarms, all PMapper, all the same mistake

PMapper reported 32 paths and called 17 principals admins. cloudfox reported 0 paths. In a hand-checked sample of 22 rows: **PMapper 4 false alarms, cloudfox 0.** That's from a sample, not a rate — I didn't check all 86 and won't pretend I did.

All four are the same error. PMapper says, at High severity:

```
user/privesc-ssmSendCommand-user can call ssm:SendCommand to access an EC2
   instance with access to role/privesc-high-priv-service-role
```

There is no such instance. Zero EC2 instances, zero SSM nodes, across all 17 regions. PMapper's own note gives it away — *"The following IAM Roles are attached to at least one instance profile"* — it's reasoning from "there's an instance profile" to "there must be an instance." The profile is real. The instance isn't.

What makes it a false alarm and not just a modelling choice is the row right next to it. `privesc3` uses the *same* instance profile and *is* a real path, because that principal can `ec2:RunInstances` — it makes its own instance. The SSM ones can only describe instances, not create them, so they need one to already exist, and none does.

To be fair to PMapper: it's not wrong about the permission or the risk. In an account that *has* SSM-managed instances, this path works. It's a false alarm *about this account*, because PMapper reasons over the permissions on paper and doesn't check whether the machine in the middle of the path actually exists. That's a design boundary — and worth naming, because in section 5 I make the exact same mistake in my grading, just pointing the other way.

I checked three other suspicious ones and cleared them. The sharpest: `privesc17`'s target grants read-only, not admin — so a tool calling it a path to admin would've been wrong, and neither tool did.

And neither tool tripped any of the five on-purpose traps. Both stayed quiet where quiet was right — though that's worth discounting in the same breath, since a tool that says nothing anywhere passes every false-alarm test ever made. That's why the crashed PMapper column is scored Missed on those, not credited for a silence it didn't choose.

### Two things only the error log shows

cloudfox got rate-limited by AWS on three principals and gave up after three retries, which cost it two detection grades. The worse part: **you can't see it in the output.** Those three principals just show up as `IsAdminRole? = No`, same as a real "no." Only the error log knows the question never actually got answered.

The second: I reran both tools as a read-only `SecurityAudit` user instead of admin, expecting much thinner output. I was wrong, and not by a little. PMapper's result was **byte-for-byte identical** — same paths, same admins, same everything, down to the file size. cloudfox's was identical too. `SecurityAudit` gives you enough IAM read access that neither tool notices the drop. (That's about this one policy, not low privilege in general — a user missing `iam:ListRoles` would've looked very different.)

But the error logs *did* differ, and that's the finding. Under admin, a Glue call fails with `InternalFailure` — AWS's way of saying the feature's retired. Under `SecurityAudit`, the same call fails with `AccessDenied`. The report looks identical either way. So a read-only auditor **can't tell "this feature is gone" from "I wasn't allowed to look."** Both just show up as a blank section.

### Grading my own predictions

I wrote five predictions into the frozen rubric before I started. Four were wrong or unanswerable — I'm reporting that because a prediction I got wrong is worth more than a scorecard with no author in it.

I predicted both tools would catch 80% of the catalogue. PMapper did; cloudfox scored zero, because its path column is disclaimed. The prediction died on the word "both." I predicted the read-only run would weaken both tools — it didn't. I predicted PMapper would score more Partials than Detects on chains — it scored zero Partials ever. I predicted at least one false alarm — there were four. The fifth is about the OIDC test and is unanswered, which is section 6.

---

## 5. My answer key was wrong, and the tool was right

Six of the lab's mechanisms come in two flavours: one on a user, one on a role, same permission. On my first pass, PMapper reported one flavour of each and not the other, and I scored the missing six as misses. I wrote it down as "PMapper being inconsistent."

It isn't inconsistent. It's right, and I was wrong.

I checked all six by hand. In every case, the flavour PMapper skipped can't actually escalate itself:

- The permissions that edit *users* — a role holding one can hand a user admin, but a role can't log in as that user, so it can't use that to climb.
- The permissions that edit *groups* — a role can make a group admin, but a role can't be *in* a group (AWS doesn't allow it), so again, no way up for itself.
- The permissions that edit *roles* — a user holding one can make any role admin, but can't assume any of them, so it can't become the thing it just empowered.

Every time, the flavour PMapper *did* report is the one that can turn the permission on *itself*. Its own data marks the difference — the six it reported are `is_admin: true`, the six it skipped are `is_admin: false`. The rule, once you see it: **PMapper reports a principal that can escalate itself, not one that can escalate someone else.**

My answer key didn't make that distinction, because it couldn't. I built it from a list of who-holds-what — principal, permission, resource. That's a fine inventory and it says nothing about whether a principal can actually reach what its permission empowers. Six of my 86 rows claimed a path that doesn't close.

My rubric had already planned for this — "a Miss that turns out not to be a real path is a mistake in my list, not the tool's" — so I moved those six out of the detection bucket. Here's what that did to the headline:

| | before | after |
|---|---|---|
| Detection, mechanisms | D 21 of 31 | **D 27 of 31** |
| Detection, rows | D 44 of 58 | **D 44 of 52** |
| Known catalogue | D 14 of 23 | **D 20 of 23** |

**PMapper's detections didn't move — the denominator did.** It found 44 rows before and 44 after. The same file got graded twice against two versions of my answer key. Reading this as PMapper getting better would be wrong: it cleared the 80% bar because I fixed my list, not because it found anything new.

Here's the part worth keeping. **A list of who-holds-what is not a list of who-can-reach-what.** Grade a path finder against the first and you invent misses — and you invent them against exactly the tools that get reachability *right*. A dumber tool that flagged all twelve flavours would've scored better on my broken list, for being more wrong.

The fix has a name and I didn't run it: an `iam:SimulatePrincipalPolicy` sweep, which asks AWS's own engine "would this actually be allowed" — a separate check that doesn't depend on either tool. My rubric names it and puts it out of scope to keep this round bounded. This section is what that skip cost: six rows I had to fix by hand after already scoring them.

There's a symmetry I didn't plan. In section 4, PMapper reasons off the permissions-on-paper and claims a path through a machine that doesn't exist — four false alarms. Here, I reason off the permissions-on-paper and claim six paths that don't close — six invented misses. Same blind spot, opposite directions. One in the tool, one in me grading it.

Three caveats, because this section flatters PMapper and I don't want it flattering past the evidence:

**The six principals aren't harmless.** Each *can* make someone else an admin, and two of them are users with live keys. What they can't do is escalate *themselves*, which is the specific thing my Detected grade measures. If your worry is "an attacker with these keys leaves a hidden admin behind for later," my matrix doesn't score that — and I say so in every one of those files.

**PMapper's rule isn't a law, and the lab proves it.** `privesc13` is the counterexample: there the group *is* reachable, because the user adds *itself* to it — a self-escalation by PMapper's own rule, and one of the four it missed. Right about these six rows, wrong there.

**I found no bonus paths.** I kept a slot for real paths turned up during checking that my list never had. Empty. But since I never ran the sweep that would go looking for them, that empty slot says something about my method, not the account. And 41 of the 344 cells are still marked "inferred" rather than confirmed — which is a column I publish, not a footnote I bury.

---

## 6. The edge I had to build myself, and what AWS does about it

The lab ships no federated-login scenario at all — no OIDC, no SAML — which is why cloudfox's federated-trust file came back empty. The tools can look for it; there was just nothing there to find.

So I built one, after the matrix was done and frozen. Thirteen resources in their own separate state, never mixed into any number above. **I did not run either tool against it.** What follows is a fact about AWS, a fact about reachability, and an argument — kept clearly apart, because the thing everyone will want me to claim here is the one thing I didn't test.

### The shape

Two chains, two hops each, identical except for one thing. Hop 1 is a GitHub Actions role you log into from outside AWS, allowed to do exactly one thing: become hop 2. Hop 2 is full admin (`Allow *:*`) and trusts only hop 1 — nothing else.

Hop 2 is airtight. Its trust is as narrow as it gets. The chain is wide open anyway, because hop 1's front door is open. That's the whole point: every lock on the valuable thing is perfect, and it doesn't matter, because the way in is one step back.

### Scenario A was meant to be the obvious-bad case — and AWS wouldn't let me build it

Scenario A was supposed to be the strawman: a rule that trusts *every* repo on GitHub. I first wrote it with no repo restriction at all, and AWS flat-out refused to create the role:

```
MalformedPolicyDocument: Trust policy with trusted principal
...token.actions.githubusercontent.com must evaluate, using StringEquals,
StringLike or StringEqualsIgnoreCase, ...:sub or ...:job_workflow_ref
which is not scoped to all.
```

I wasn't expecting that. AWS ships a guardrail against exactly the mistake I was trying to make. Good — except I poked at where the guardrail actually sits, with four quick attempts:

| repo restriction | result |
|---|---|
| *(none)* | **REJECTED** |
| `*` | **REJECTED** |
| `repo:*` | **ACCEPTED** |
| `repo:*/*` | **ACCEPTED** |

Every GitHub Actions login starts with `repo:`. So `repo:*` matches every repo on GitHub — the exact thing AWS just refused as `*`. Same meaning, different spelling, and AWS accepts it.

**The guardrail checks what the rule looks like, not what it actually allows.** (One honest exception: an org can customise its login format so it doesn't start with `repo:`, in which case `repo:*` matches nothing. That's not the default, so the accurate claim is "matches every default-format login," not "every login.")

Two things follow. If you — a reviewer, or an automated check — treat "there's a repo restriction, good" as the test, you're checking the same shallow thing AWS is, and you're wrong the same way. And because AWS's rejection message is so specific and helpful, the likely move for an engineer who hits it is to paste in the first thing that gets accepted — which is `repo:*`.

And this is the same trap that showed up back in section 4. cloudfox prints `Condition=Yes` for both the always-true condition and the never-true one — identical rows, one dangerous and one dead, because the column says a condition *exists*, not what it *does*. **Whether a rule is present is cheap to check and nearly useless. What the rule actually allows is the whole question — and it's the part that keeps getting skipped.**

### Scenario B is the realistic one

```
"sub": "repo:iam-tool-benchmark-lab/*"
```

There's a repo restriction. It names an org. It passes a quick review and looks like the documented pattern. And it allows *every* repo in that org — every branch, every environment, and every repo anyone creates in it later.

| | |
|---|---|
| what it enforces | `repo:iam-tool-benchmark-lab/*` |
| what was meant | `repo:iam-tool-benchmark-lab/deploy:ref:refs/heads/main` |

One asterisk apart. A gets caught by eye, and half-caught by AWS. B gets caught by neither.

### What I measured, and what I'm only arguing

The measured part: I confirmed nobody *inside* the account can reach these roles. As full admin I tried to assume all four and got `AccessDenied` on every one — meaning the only way in is a GitHub login from outside. So these thirteen resources add zero internal paths, and the matrix in section 4 stands untouched.

The argued part: a tool like PMapper maps what's *inside* the account. The first step of these chains starts *outside* it — at GitHub — and whether it's allowed comes down to matching text in a token the account never even sees while the map is being built. So nothing here shows up as a link to anything reasoning only over what's inside. That's an argument about where a map's edge falls, not a measurement — and I'm not dressing it up as one. cloudfox has a federated-trust feature; what it would've made of these roles is untested, because I didn't point it at them.

### What I did *not* prove

I did **not** prove the chain works end to end. What I confirmed: the policies exist as written, AWS accepted them, hop 2 is full admin, and nobody inside can reach either chain. What I did *not* confirm: that a real GitHub Actions token actually walks the whole chain to admin. That needs a live repo running a workflow, and I didn't run one. The reasoning is solid — it's based on GitHub's documented token format and AWS's own rules — but it's still reasoning, not a demo.

### This is a live door in a live account

Worth stating plainly, for anyone copying this. Scenario A can be walked in by anyone who runs a GitHub Action and knows the role's name — the only thing stopping them is that I didn't publish it. Scenario B can be walked in by anyone who controls a repo in the GitHub org `iam-tool-benchmark-lab` — a name I picked *because it was unregistered* (I checked, twice). **If someone registers it, they get admin in that account.** That's why I kept the account ID out of the repo, kept it private until now, and why tearing this down matters more than the main lab. The lab's roles need existing credentials to abuse. These two need none.

---

## 7. What this doesn't show

The caveats on specific claims are next to those claims. These are the limits on the whole thing:

**It's n=1.** One account, one deployment, one run each. The timeout in section 2 is one sighting — I don't know how often it happens. The bug is real regardless; the frequency I can't speak to.

**Two tools isn't a survey.** Section 3 is about the two tools I ran, not the field. I didn't review the field.

**`SecurityAudit` is one setting, not "low privilege" in general.** The identical-output result is about that one policy. A more restricted user would've looked very different.

**I checked for missing targets, I didn't try to exploit them.** I confirmed there are no instances/stacks/notebooks to attack across all 17 regions. I didn't spin one up to prove the SSM paths would then work. So "this path doesn't work as things stand" is solid; "this mechanism never works" isn't a claim I'm making.

**I only hand-checked a sample** — 22 of 86 rows. Every false-alarm count is "found in a sample of 22," not a rate. And 41 of 344 cells are still marked inferred, including one of PMapper's four misses that rests on a target I never confirmed.

**Grading is unweighted** — a missed path to full admin counts the same as a missed path to nothing. Ranking severity needs a model I don't have, and I wasn't going to invent one after seeing the results.

**One rubric rule I met in spirit, not to the letter.** I was supposed to hand-check three rows that all tools missed. Under the final grades no row is missed by *everyone* (cloudfox's permission dump earns Partial), so I checked the three as missed *on the escalation question specifically*. Saying so, rather than quietly meeting the easier version.

**No independent check was run** — the big one. Without the `SimulatePrincipalPolicy` sweep, my list is who-holds-what and nothing went hunting for paths the lab's author didn't plant. Section 5 is what that cost in the direction I could see. It's silent on the direction I couldn't.

---

## 8. Reproducing this

It's all in the repo: the rubric (frozen in git before I deployed anything, so `git log` proves what I committed to before seeing any output); the scenario list; the 344-row grade file, each row carrying its evidence and the exact search I used; the 19 validation files with commands and results; and the matrix, written by hand from the grades with no script in between.

Raw output is unedited except for one published find-and-replace that swaps my account ID and keys for placeholders — the script is in the repo, so "unedited" means "unedited except one rule you can read." Every grade can be traced back to its source.

**Versions.** cloudfox 2.0.5 (binary, hash verified). PMapper 1.1.5 (2022 release), on Python 3.9.25. `iam-vulnerable` at commit `0f29866`. Terraform 1.14.8.

**One gotcha for anyone repeating it.** PMapper 1.1.5 won't import on Python 3.10+, and the Homebrew build of Python 3.9 I used gets pulled on 2026-10-15. After that you'll have to find a 3.9 another way or patch the import — and a patched copy isn't the published tool anymore, which is the whole reason I didn't patch mine.

**Account hygiene.** Do this in a throwaway account, never one tied to anything real, and confirm which account you're in before every command. `iam-vulnerable` creates real users and keys built to escalate to admin — it is not something to point at a shared account.

**Teardown is containment, not tidying.** Two things to destroy, OIDC first:

```
cd lab-oidc && terraform destroy   # 13 resources — first
cd ../lab   && terraform destroy   # 265 resources
```

The OIDC one goes first because it's reachable from outside with no credentials, and it leans on that GitHub org name staying unregistered. The main lab is the bigger cleanup: it creates 41 real access keys, so its state file holds **41 live AWS secret keys in plaintext** — gitignored, so never committed, but real credentials sitting on a laptop until they're deleted.

Two things I left standing on purpose: the read-only `SecurityAudit` user, and the leftover `EC2-AutoRemediation` function that's the only target for one of the scenarios.

My own tool isn't in here, and its test resources were cleared out before grading — because a baseline is only worth anything if it was built before the thing it's meant to measure.