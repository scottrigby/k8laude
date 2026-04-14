# k8laude Terraform Module

Deploy k8laude (Claude Code on Kubernetes) using Terraform.

## Prerequisites

- Kubernetes cluster (1.26+)
- Helm 3.x
- Replicated license

## Usage

```hcl
module "k8laude" {
  source = "github.com/scottrigby/k8laude//terraform"

  replicated_license_id = var.replicated_license_id
  claude_oauth_token    = var.claude_oauth_token

  cloudtty_enabled      = true
  code_server_enabled   = true
  debug_logging_enabled = true
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `namespace` | Kubernetes namespace | `string` | `"k8laude"` |
| `chart_version` | Helm chart version | `string` | `"latest"` |
| `replicated_license_id` | Replicated license ID | `string` | (required) |
| `claude_oauth_token` | Claude Code OAuth token | `string` | `""` |
| `claude_api_key` | Anthropic API key | `string` | `""` |
| `cloudtty_enabled` | Enable browser terminal | `bool` | `true` |
| `code_server_enabled` | Enable web IDE | `bool` | `true` |
| `debug_logging_enabled` | Enable debug logging | `bool` | `true` |
| `postgresql_external` | Use external PostgreSQL | `bool` | `false` |
| `external_database` | External DB connection | `object` | `{}` |
