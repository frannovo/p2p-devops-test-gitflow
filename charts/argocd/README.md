# ArgoCD Helm Chart

This helm chart defines ArgoCD server configuration and CRD resources (projects, repositories).

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://argoproj.github.io/argo-helm | argo-cd | 9.1.3 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| argo-cd.server.extraArgs[0] | string | `"--insecure"` |  |
| environments[0] | string | `"dev"` |  |
| environments[1] | string | `"staging"` |  |
| environments[2] | string | `"prod"` |  |

