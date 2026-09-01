# Two AWS IAM privesc tools, one path finder

*Four things that surprised me while grading PMapper and cloudfox against a deliberately broken AWS account.*

Over two weekends I deployed Bishop Fox's `iam-vulnerable` into a throwaway AWS account and ran two open-source IAM privilege-escalation tools against it: cloudfox 2.0.5 and PMapper 1.1.5. I graded every scenario by hand against a rubric I froze in git before I deployed anything.

I expected a scoreboard. I got four findings, none of them about which tool wins.

---

## 1. A region I don't use killed the run and took the map with it

PMapper builds a map of every identity in an account and then answers questions over it. Everything starts with `pmapper graph create`, so I ran that as admin against the fresh lab. It ran for five minutes fifty-two seconds and exited with an error.

The first four minutes look fine. It pulls users, roles, groups and policies, works out who's already an admin, then starts checking for links, starting with EC2 Auto Scaling, which means checking every region. My account has 17 regions on and AWS has many more, so most of those calls hit regions I can't use. PMapper is written to shrug those off:

```plaintext
19:23:21 | Unable to search region af-south-1 for launch configs. The region may be
           disabled, or the error may be caused by an authorization issue. Continuing.
```

Fifteen regions, fifteen "Continuing." Then the sixteenth:

```plaintext
botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint URL:
"https://autoscaling.me-south-1.amazonaws.com/"
```

and the whole thing dies at `autoscaling_edges.py:60`.

It comes down to one line. The code that catches "region didn't work, keep going" only catches a region *refusing* you (`ClientError`). The other fifteen refused, so they got caught. `me-south-1` didn't refuse, it went silent and timed out. That's a different kind of error, so the catch doesn't handle it and the program dies.

The catch isn't missing. Someone wrote it for exactly this situation. They just aimed it at the wrong kind of error.

A small miss becomes a total one because of how PMapper is built. Auto Scaling is the first of nine checks, and nothing is saved until all nine finish. The four minutes of good data it already had, the whole map, was in memory when it crashed. It's gone.

Everything after this needs that file. I ran the other seven commands anyway, six died the same way:

```plaintext
ValueError: Did not find file at: /Users/.../com.nccgroup.principalmapper/000000000000
```

The seventh, `graph list`, exited cleanly and printed `Account IDs:` and nothing under it. The one command that worked is the one whose only job is to tell you there's nothing there.

This is one sighting, not a rate. But the bug isn't about my setup: any unreachable endpoint in that loop triggers it, that loop is the only thing that builds the map, and the line hasn't changed on main since 2022-02-03.

Getting to the crash took longer than the crash did. PMapper won't import on Python 3.10+, `from collections import Mapping`, removed in 3.10, while its setup file claims "Python 3.5+," so pip installs it happily and you find out when you run it. The real ceiling is 3.9, end of life since October 2025. I didn't patch the import, a patched copy isn't the published tool. cloudfox, for contrast, took under a minute: download the binary, check the hash, run it.

---

## 2. There was only ever one path-finding engine

cloudfox ran without a hitch. One command produced fifteen CSVs and their JSON versions: 94 principals, 6,008 permission grants, 44 trust edges. Nothing crashed, nothing needed a flag.

One of its columns is `CanPrivEscToAdmin?`. It appears 140 times, and in this run every one reads:

```json
"CanPrivEscToAdmin?": "Skipping, no pmapper data",
```

cloudfox has no path finder. It hands that job to PMapper, and it's upfront about it in three places: its wiki, the console mid-run ("we suggest running the pmapper commands in the loot file"), and a file it writes for you, `loot/iam-simulator-pmapper-commands.txt`, sixteen lines, every one a `pmapper` command.

The tool that ran successfully wrote me a to-do list for the tool that didn't.

Because that's documented, I graded cloudfox N/A on path-finding rather than counting it as a miss, and graded everything it works out itself normally. It does that part well. In the lab's three-role chain, its output has one row saying `ending-role` trusts `intermediate-role` and is admin, and one row below it, `intermediate-role` trusts `starting-role`. Every step of the chain is there. The chain isn't.

The broader thing: I set out to compare two tools on path-finding and found one engine and one tool that displays that engine's output. If PMapper's map had been on disk when cloudfox ran, cloudfox would have displayed PMapper's answer, and I'd have graded the same engine twice thinking I had two data points. That only didn't happen because I ran cloudfox first, on a machine where PMapper had never run.

Two tools isn't a survey of the field. But of those two, the maintained one doesn't find paths and points you at the other, and the other hasn't been touched since February 2022 and throws its whole map away on a timeout.

---

## 3. My answer key was wrong and the tool was right

Six of the lab's mechanisms come in two flavours: one on a user, one on a role, same permission. PMapper reported one flavour of each and not the other. I scored the missing six as misses and wrote down "PMapper being inconsistent."

It isn't inconsistent. It's right, and I was wrong. I checked all six by hand, and in every case the flavour PMapper skipped can't escalate itself:

- The permissions that edit **users**: a role holding one can hand a user admin, but a role can't log in as that user.
- The permissions that edit **groups**: a role can make a group admin, but AWS doesn't let a role be *in* a group.
- The permissions that edit **roles**: a user holding one can make any role admin, but can't assume it.

Every time, the flavour PMapper *did* report is the one that can turn the permission on itself. Its own data marks the difference, the six it reported are `is_admin: true`, the six it skipped are `is_admin: false`. The rule, once you see it: PMapper reports a principal that can escalate *itself*, not one that can escalate someone else.

My answer key couldn't make that distinction, because I built it from a list of who-holds-what. That's a fine inventory, and it says nothing about whether the permission gives that principal a path it can actually use.

PMapper's detections didn't move when I fixed this. It found 44 rows before and 44 after, only my denominator changed. The part worth keeping is the rule: **a list of who-holds-what is not a list of who-can-reach-what.** Grade a path finder against the first and you invent misses, and you invent them against exactly the tools that get reachability right. A less precise tool that flagged all twelve flavours would have scored better on my broken list while being less accurate.

PMapper's four false alarms in this run are the same mistake in reverse. It reported, at High severity, that a user can call `ssm:SendCommand` to reach an EC2 instance with a privileged role attached. There are no EC2 instances in that account, in any of the 17 regions. It reasoned from "there's an instance profile" to "there must be an instance." Permissions on paper again, once in the tool, once in me grading it.

---

## 4. AWS's GitHub OIDC guardrail checks how a rule is written, not what it allows

The lab ships no federated-login scenario, so I built one after the matrix was frozen. Two chains, two hops each. Hop 1 is a GitHub Actions role you log into from outside AWS, allowed to do exactly one thing: become hop 2. Hop 2 is full admin and trusts only hop 1. Hop 2's trust is narrow, and it doesn't matter, because the way in is one step back.

Scenario A was meant to be the obvious bad case: a rule trusting every repo on GitHub. AWS refused to create the role:

```plaintext
MalformedPolicyDocument: Trust policy with trusted principal
...token.actions.githubusercontent.com must evaluate, using StringEquals,
StringLike or StringEqualsIgnoreCase, ...:sub or ...:job_workflow_ref
which is not scoped to all.
```

I wasn't expecting that. AWS ships a guardrail against exactly the mistake I was trying to make. So I poked at where it sits:

| repo restriction | result |
|---|---|
| *(none)* | REJECTED |
| `*` | REJECTED |
| `repo:*` | ACCEPTED |
| `repo:*/*` | ACCEPTED |

Every GitHub Actions login starts with `repo:`. So `repo:*` matches every repo on GitHub, the exact thing AWS just refused as `*`. Same meaning, different spelling. (An org can customise its login format so it doesn't start with `repo:`, in which case `repo:*` matches nothing, so the accurate claim is "every default-format login.")

The rejection message is specific and helpful, which makes the likely next move for an engineer who hits it pasting in the first thing that's accepted.

Scenario B is the realistic one:

```json
"sub": "repo:iam-tool-benchmark-lab/*"
```

There's a repo restriction. It names an org. It passes a quick review. And it allows every repo in that org, every branch, every environment, and every repo anyone creates in it later. What was meant was `repo:iam-tool-benchmark-lab/deploy:ref:refs/heads/main`. One asterisk apart. AWS catches the obvious version of A. B looks reasonable in a quick review.

Two limits, because this is the part people will want me to overclaim. As full admin I tried to assume all four roles and got `AccessDenied` on every one, so the only way in is a GitHub login from outside. And I did not prove the chain end to end, that needs a live repo running a workflow, and I didn't run one.

---

## What ties them together

PMapper's error handler checks *that* a region failed, not *how*. cloudfox's column reports that a privesc verdict exists without an engine behind it, and elsewhere prints `Condition=Yes` for both an always-true condition and a never-true one, because the column says a condition is present, not what it does. My answer key checked that a permission was granted, not what it actually let the principal reach. AWS checks that a `sub` restriction is present and doesn't look like a wildcard, not what it matches.

Checking whether a safeguard exists is easy, but it isn't enough. What it actually allows is the part that matters, and that's what tools, reviewers, and even the cloud provider writing the guardrail keep missing.

*The frozen rubric, the full grade file, the hand-validations with exact commands, and all raw tool output are in the repo, unedited apart from one published script that swaps the account ID and access keys for placeholders.*
