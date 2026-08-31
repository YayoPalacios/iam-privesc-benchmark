###############################################################################
# Phase 5 — GitHub Actions OIDC trust-chaining scenario
#
# Authored for this benchmark. NOT part of iam-vulnerable and NOT part of the
# graded matrix. Its own root, its own state; it never shares state with ../lab.
#
# The single defect is deliberate and is confined to one place: the trust policy
# of aws_iam_role.entry constrains `aud` but not `sub`. Everything else in this
# file is tight on purpose, so that the scenario has exactly one variable.
#
# See SCENARIO.md for the mechanism, the target, and what has and has not been
# confirmed.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_local_profile
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  oidc_host = "token.actions.githubusercontent.com"

  # Scenario A. Semantically "any repository on github.com". See the block
  # above aws_iam_role.entry for why this is not simply omitted.
  floor_sub_pattern = "repo:*"

  # Target role ARNs, constructed rather than referenced. IAM validates the
  # principal named in a trust policy and rejects one that does not yet exist,
  # but does not validate a resource ARN in a permission policy. Referencing
  # the role from the trust policy and constructing the ARN in the permission
  # policy therefore gives Terraform the correct create order in one direction
  # with no cycle -- and avoids a silent 2m10s CreateRole retry loop.
  role_arn_prefix          = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role"
  target_role_arn          = "${local.role_arn_prefix}/${var.name_prefix}-terraform-role"
  wildcard_target_role_arn = "${local.role_arn_prefix}/${var.name_prefix}-wildcard-terraform-role"

  tags = {
    purpose  = "iam-tool-benchmark"
    phase    = "5"
    scenario = "oidc-gha-loose-sub"
    authored = "not-iam-vulnerable"
  }
}

###############################################################################
# The identity provider
#
# thumbprint_list is deliberately omitted. AWS secures communication with
# token.actions.githubusercontent.com through its own library of trusted root
# CAs, so the thumbprint is neither required nor consulted for this IdP.
# Hardcoding one would put a value in this repo that looks load-bearing, rots,
# and is not.
###############################################################################

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]

  tags = merge(local.tags, { Name = "${var.name_prefix}-provider" })

  lifecycle {
    precondition {
      condition     = var.expected_account_id == "" || var.expected_account_id == data.aws_caller_identity.current.account_id
      error_message = "Refusing to apply: the credentials in scope resolve to a different AWS account than expected_account_id. Check AWS_PROFILE / var.aws_local_profile before retrying."
    }
  }
}

###############################################################################
# SCENARIO A — the floor case
#
# THE DEFECT. The trust policy pins `aud` to sts.amazonaws.com, which every
# copy-pasted GitHub OIDC example includes, and constrains `sub` to `repo:*`.
# `sub` is the only claim that carries the repository. Every GitHub Actions
# subject claim has the form `repo:<owner>/<repo>:<context>`, so `repo:*`
# matches all of them: this admits ANY workflow run in ANY repository on
# github.com, by any account, not merely any branch of the intended one.
#
# The intended condition, for reference, would have been:
#
#   "StringEquals": {
#     "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:ref:refs/heads/main"
#   }
#
# ---------------------------------------------------------------------------
# WHY `repo:*` AND NOT AN ABSENT `sub`
#
# This scenario was authored with NO `sub` condition at all. AWS refuses to
# create it. `CreateRole` returns, verbatim:
#
#   MalformedPolicyDocument: Trust policy with trusted principal
#   arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com must
#   evaluate, using StringEquals, StringLike or StringEqualsIgnoreCase,
#   token.actions.githubusercontent.com:sub or
#   token.actions.githubusercontent.com:job_workflow_ref which is not scoped to
#   all.
#
# The guardrail is syntactic. Probed 2026-08-30 against this account:
#
#   absent sub          -> REJECTED
#   StringLike sub "*"  -> REJECTED
#   StringLike sub "repo:*"   -> ACCEPTED
#   StringLike sub "repo:*/*" -> ACCEPTED
#
# `repo:*` is semantically identical to an absent condition and AWS accepts it.
# So the floor case survives intact; only its spelling changed, and the fact
# that AWS blocks the naive form while permitting an exact synonym is itself a
# result. See SCENARIO.md, "The guardrail is cosmetic".
# ---------------------------------------------------------------------------
#
# The role's own permissions are deliberately thin: one sts:AssumeRole grant on
# one named role. A reviewer reading this role's policy in isolation sees a
# narrowly scoped deploy role.
###############################################################################

resource "aws_iam_role" "entry" {
  name        = "${var.name_prefix}-deploy-role"
  description = "Phase 5 scenario A (floor). Entry point: GitHub Actions OIDC, aud pinned, sub StringLike repo:* which matches all of github.com."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubActionsWebIdentity"
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
          # Present only because AWS refuses to create the role without it.
          # `repo:*` matches every GitHub Actions subject claim in existence,
          # so this constrains nothing. That is the scenario.
          StringLike = {
            "${local.oidc_host}:sub" = local.floor_sub_pattern
          }
        }
      }
    ]
  })

  tags = merge(local.tags, { Name = "${var.name_prefix}-deploy-role", hop = "1" })
}

resource "aws_iam_policy" "entry" {
  name        = "${var.name_prefix}-deploy-policy"
  description = "Phase 5 scenario. Hop 1 -> hop 2: assume the Terraform execution role."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeTerraformExecutionRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.target_role_arn
      }
    ]
  })

  tags = merge(local.tags, { Name = "${var.name_prefix}-deploy-policy" })
}

resource "aws_iam_role_policy_attachment" "entry" {
  role       = aws_iam_role.entry.name
  policy_arn = aws_iam_policy.entry.arn
}

###############################################################################
# Hop 2 — the target
#
# The thing worth reaching: a Terraform execution role holding Allow *:*, i.e.
# account administrator. Its trust policy is TIGHT — it names exactly one
# principal, the entry role. Nothing else in the account can assume it.
#
# This asymmetry is the point. Every control on hop 2 is correct. The chain is
# open anyway, because hop 1's front door is open to the whole of github.com.
###############################################################################

resource "aws_iam_role" "target" {
  name        = "${var.name_prefix}-terraform-role"
  description = "Phase 5 scenario. Target: administrator-equivalent, assumable only by the entry role."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TrustEntryRoleOnly"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.entry.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${var.name_prefix}-terraform-role", hop = "2" })
}

resource "aws_iam_policy" "target" {
  name        = "${var.name_prefix}-terraform-policy"
  description = "Phase 5 scenario. Administrator-equivalent. This is what the chain reaches."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AdministratorEquivalent"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${var.name_prefix}-terraform-policy" })
}

resource "aws_iam_role_policy_attachment" "target" {
  role       = aws_iam_role.target.name
  policy_arn = aws_iam_policy.target.arn
}

###############################################################################
# SCENARIO B — the headline case: a `sub` condition that is present, and wrong
#
# Chain A above is the floor. Its trust policy has no `sub` condition at all,
# which is indefensible on sight and which any reviewer catches. It exists to be
# the strawman that Chain B is measured against.
#
# Chain B is the one that ships in real accounts. It HAS a `sub` condition. It
# is `StringLike`, and the value is `repo:<org>/*`. A skim review sees a trust
# policy that pins the audience, constrains the subject, and names the
# organisation, and moves on. What it actually admits is every repository under
# that organisation — including a repository created after the review, by anyone
# who can create one, containing a workflow the reviewer never saw.
#
# The structure is otherwise identical to Chain A, deliberately: same two hops,
# same thin entry permission, same tight hop-2 trust, same administrator
# terminus. The trust policy on hop 1 is the only variable between the two
# chains, which is what makes them comparable as a pair.
###############################################################################

locals {
  wildcard_prefix = "${var.name_prefix}-wildcard"

  # The subject pattern the trust policy actually enforces, and the one it was
  # presumably meant to enforce. The gap between them is the scenario.
  wildcard_sub_pattern = "repo:${var.github_org}/*"
  intended_sub_pattern = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main"
}

resource "aws_iam_role" "wildcard_entry" {
  name        = "${local.wildcard_prefix}-deploy-role"
  description = "Phase 5 scenario. Entry point: GitHub Actions OIDC, aud pinned, sub present but StringLike repo:<org>/*."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubActionsWebIdentityOrgWildcard"
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
          }
          # Present, and permissive. Matches every repo under the org, every
          # branch, every tag, every environment, every pull_request run.
          StringLike = {
            "${local.oidc_host}:sub" = local.wildcard_sub_pattern
          }
        }
      }
    ]
  })

  tags = merge(local.tags, {
    Name    = "${local.wildcard_prefix}-deploy-role"
    hop     = "1"
    variant = "sub-wildcard"
  })
}

resource "aws_iam_policy" "wildcard_entry" {
  name        = "${local.wildcard_prefix}-deploy-policy"
  description = "Phase 5 scenario. Hop 1 -> hop 2: assume the Terraform execution role."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeTerraformExecutionRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.wildcard_target_role_arn
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.wildcard_prefix}-deploy-policy", variant = "sub-wildcard" })
}

resource "aws_iam_role_policy_attachment" "wildcard_entry" {
  role       = aws_iam_role.wildcard_entry.name
  policy_arn = aws_iam_policy.wildcard_entry.arn
}

resource "aws_iam_role" "wildcard_target" {
  name        = "${local.wildcard_prefix}-terraform-role"
  description = "Phase 5 scenario. Target: administrator-equivalent, assumable only by the wildcard entry role."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TrustWildcardEntryRoleOnly"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.wildcard_entry.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.tags, {
    Name    = "${local.wildcard_prefix}-terraform-role"
    hop     = "2"
    variant = "sub-wildcard"
  })
}

resource "aws_iam_policy" "wildcard_target" {
  name        = "${local.wildcard_prefix}-terraform-policy"
  description = "Phase 5 scenario. Administrator-equivalent. This is what the wildcard chain reaches."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AdministratorEquivalent"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.tags, { Name = "${local.wildcard_prefix}-terraform-policy", variant = "sub-wildcard" })
}

resource "aws_iam_role_policy_attachment" "wildcard_target" {
  role       = aws_iam_role.wildcard_target.name
  policy_arn = aws_iam_policy.wildcard_target.arn
}
