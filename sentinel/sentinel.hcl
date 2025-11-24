# Sentinel configuration file
policy "deny_open_sg" {
  source = "./policies/deny_open_sg.sentinel"
}

policy "require_tags" {
  source = "./policies/require_tags.sentinel"
}

policy "require_encryption" {
  source = "./policies/require_encryption.sentinel"
}

# Terraform plan JSON
import {
  source = "../terraform/plan.json"
  type   = "json"
  name   = "tfplan"
}