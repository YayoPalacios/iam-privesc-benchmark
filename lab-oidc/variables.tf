variable "aws_local_profile" {
  description = "Named CLI profile for the sandbox account. Every other profile on this machine is a work account."
  type        = string
  default     = "personal"
}

variable "aws_region" {
  description = "Region for the provider endpoint. IAM and the OIDC provider are global; this only picks where the API calls go."
  type        = string
  default     = "us-east-1"
}

variable "expected_account_id" {
  description = <<-EOT
    Optional safety rail. When set, apply refuses unless the credentials in
    scope resolve to this account. Leave it out of version control: set it in
    terraform.tfvars, which the root .gitignore excludes.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.expected_account_id == "" || can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID, or empty to disable the check."
  }
}

variable "name_prefix" {
  description = "Prefix for every resource in this scenario. Chosen so nothing collides with the 45 lab roles in ../lab."
  type        = string
  default     = "oidc-gha"
}

variable "github_org" {
  description = <<-EOT
    The GitHub organisation named in Chain B's `sub` wildcard, as
    `repo:<org>/*`. It must NOT be an organisation that exists on github.com
    and is controlled by someone else: the trust policy is real, so whoever
    controls the org can assume the role for real. The default is a name chosen
    because it is not registered. See SCENARIO.md, "Live exposure".
  EOT
  type        = string
  default     = "iam-tool-benchmark-lab"
}

variable "github_repo" {
  description = "The repository the wildcard was presumably meant to pin to. Documentation only; it appears in no policy."
  type        = string
  default     = "deploy"
}
