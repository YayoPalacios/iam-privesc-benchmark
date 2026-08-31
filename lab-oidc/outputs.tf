output "oidc_provider_arn" {
  description = "The GitHub Actions OIDC provider. Before this apply the account had zero OIDC and zero SAML providers."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "entry_role_arn" {
  description = "Hop 1. Assumable via sts:AssumeRoleWithWebIdentity by any GitHub Actions workflow, in any repository."
  value       = aws_iam_role.entry.arn
}

output "target_role_arn" {
  description = "Hop 2. Administrator-equivalent. Assumable only by the entry role."
  value       = aws_iam_role.target.arn
}

output "entry_role_trust_policy" {
  description = "The defect, rendered. Note the absence of any condition on the sub claim."
  value       = aws_iam_role.entry.assume_role_policy
}

output "wildcard_entry_role_arn" {
  description = "Chain B, hop 1. Assumable by any GitHub Actions workflow in any repository under the named org."
  value       = aws_iam_role.wildcard_entry.arn
}

output "wildcard_target_role_arn" {
  description = "Chain B, hop 2. Administrator-equivalent. Assumable only by the wildcard entry role."
  value       = aws_iam_role.wildcard_target.arn
}

output "wildcard_entry_role_trust_policy" {
  description = "The headline defect, rendered. The sub condition is present, StringLike, and matches the whole org."
  value       = aws_iam_role.wildcard_entry.assume_role_policy
}

output "sub_patterns" {
  description = "What Chain B enforces versus what it was presumably meant to enforce."
  value = {
    enforced = local.wildcard_sub_pattern
    intended = local.intended_sub_pattern
  }
}
