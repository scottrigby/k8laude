terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
  }
}

variable "namespace" {
  description = "Kubernetes namespace for k8laude deployment"
  type        = string
  default     = "k8laude"
}

variable "chart_version" {
  description = "k8laude Helm chart version"
  type        = string
  default     = "latest"
}

variable "replicated_license_id" {
  description = "Replicated license ID for image proxy authentication"
  type        = string
  sensitive   = true
}

variable "claude_oauth_token" {
  description = "Claude Code OAuth token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "claude_api_key" {
  description = "Anthropic API key (alternative to OAuth token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudtty_enabled" {
  description = "Enable browser-based terminal (CloudTTY)"
  type        = bool
  default     = true
}

variable "code_server_enabled" {
  description = "Enable browser-based VS Code IDE"
  type        = bool
  default     = true
}

variable "debug_logging_enabled" {
  description = "Enable Claude Code debug log collection"
  type        = bool
  default     = true
}

variable "postgresql_external" {
  description = "Use external PostgreSQL instead of embedded"
  type        = bool
  default     = false
}

variable "external_database" {
  description = "External PostgreSQL connection details"
  type = object({
    host     = string
    port     = number
    username = string
    password = string
    database = string
  })
  default = {
    host     = ""
    port     = 5432
    username = "k8laude"
    password = ""
    database = "k8laude"
  }
  sensitive = true
}

resource "kubernetes_namespace" "k8laude" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "k8laude" {
  name       = "k8laude"
  namespace  = kubernetes_namespace.k8laude.metadata[0].name
  repository = "oci://registry.replicated.com/k8laude/stable"
  chart      = "k8laude"
  version    = var.chart_version
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      replicated = {
        enabled      = true
        nameOverride = "k8laude-sdk"
      }
      claude = {
        oauthToken = var.claude_oauth_token
        apiKey     = var.claude_api_key
        debug = {
          enabled = var.debug_logging_enabled
        }
      }
      cloudtty = {
        enabled = var.cloudtty_enabled
      }
      "code-server" = {
        enabled = var.code_server_enabled
      }
      postgresql = {
        enabled = !var.postgresql_external
      }
      externalDatabase = var.postgresql_external ? var.external_database : {}
      ingress = {
        enabled = false
      }
      "cert-manager" = {
        enabled = false
      }
      traefik = {
        enabled = false
      }
    })
  ]
}

output "namespace" {
  description = "Kubernetes namespace where k8laude is deployed"
  value       = kubernetes_namespace.k8laude.metadata[0].name
}

output "landing_page_command" {
  description = "Command to access the k8laude landing page"
  value       = "kubectl port-forward -n ${var.namespace} svc/k8laude 3000"
}

output "terminal_command" {
  description = "Command to access Claude Code terminal (when CloudTTY is disabled)"
  value       = var.cloudtty_enabled ? "kubectl port-forward -n ${var.namespace} svc/k8laude-cloudtty 7681" : "kubectl -n ${var.namespace} exec -it statefulset/k8laude -- claude --dangerously-skip-permissions"
}
