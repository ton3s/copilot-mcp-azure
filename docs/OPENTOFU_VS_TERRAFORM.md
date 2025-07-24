# OpenTofu vs Terraform

## Overview

This project uses **OpenTofu** for infrastructure as code. OpenTofu is the open-source fork of Terraform, created by the Linux Foundation in response to HashiCorp's license change for Terraform from MPL to BSL.

## Why OpenTofu?

### 1. **Open Source License**
- OpenTofu uses the **Mozilla Public License 2.0 (MPL-2.0)**
- Terraform switched to **Business Source License (BSL)** in version 1.6+
- OpenTofu remains truly open source and community-driven

### 2. **100% Compatibility**
- Drop-in replacement for Terraform 1.5.x
- Same HCL syntax
- Same provider ecosystem
- Same state file format
- Same workflow and commands

### 3. **Community Governance**
- Managed by the Linux Foundation
- Transparent development process
- Community-driven roadmap
- No vendor lock-in

## Migration Guide

### From Terraform to OpenTofu

1. **Install OpenTofu**
   ```bash
   # macOS
   brew install opentofu
   
   # Linux
   snap install --classic opentofu
   
   # Windows
   choco install opentofu
   ```

2. **Replace Commands**
   | Terraform Command | OpenTofu Command |
   |-------------------|------------------|
   | `terraform init` | `tofu init` |
   | `terraform plan` | `tofu plan` |
   | `terraform apply` | `tofu apply` |
   | `terraform destroy` | `tofu destroy` |
   | `terraform output` | `tofu output` |
   | `terraform state` | `tofu state` |

3. **State File Compatibility**
   - State files are 100% compatible
   - No conversion needed
   - Can switch between tools seamlessly

### Configuration Files

No changes needed! All `.tf` files work identically:

```hcl
# This works in both Terraform and OpenTofu
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
  }
}
```

## Feature Comparison

| Feature | OpenTofu | Terraform OSS | Terraform Cloud |
|---------|----------|---------------|-----------------|
| Core IaC functionality | ✅ | ✅ | ✅ |
| Open source | ✅ | ❌ (BSL) | ❌ |
| Provider ecosystem | ✅ | ✅ | ✅ |
| State management | ✅ | ✅ | ✅ |
| Remote backends | ✅ | ✅ | ✅ |
| Workspaces | ✅ | ✅ | ✅ |
| Module registry | ✅ | ✅ | ✅ |
| Cloud integration | Community | Limited | ✅ |
| Cost | Free | Free | Paid |

## Provider Compatibility

All Terraform providers work with OpenTofu:

- ✅ Azure Provider (`hashicorp/azurerm`)
- ✅ AWS Provider (`hashicorp/aws`)
- ✅ Google Cloud Provider (`hashicorp/google`)
- ✅ Kubernetes Provider (`hashicorp/kubernetes`)
- ✅ All community providers

## CI/CD Integration

### GitHub Actions

```yaml
- name: Setup OpenTofu
  uses: opentofu/setup-opentofu@v1
  with:
    tofu_version: 1.5.0

- name: OpenTofu Init
  run: tofu init

- name: OpenTofu Plan
  run: tofu plan
```

### Azure DevOps

```yaml
- task: Bash@3
  displayName: 'Install OpenTofu'
  inputs:
    targetType: 'inline'
    script: |
      curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sh

- task: Bash@3
  displayName: 'OpenTofu Init'
  inputs:
    targetType: 'inline'
    script: 'tofu init'
```

## Best Practices

### 1. Version Pinning
```hcl
terraform {
  required_version = ">= 1.5.0, < 2.0.0"
}
```

### 2. State Storage
Same as Terraform - use remote backends:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
```

### 3. Provider Versions
Always pin provider versions:
```hcl
required_providers {
  azurerm = {
    source  = "hashicorp/azurerm"
    version = "~> 3.85.0"
  }
}
```

## Common Questions

### Q: Can I use existing Terraform modules?
**A:** Yes! All Terraform modules work with OpenTofu without modification.

### Q: What about Terraform Cloud/Enterprise features?
**A:** OpenTofu focuses on the core IaC engine. For enterprise features, consider:
- Spacelift
- Env0
- Scalr
- Atlantis (open source)

### Q: Is OpenTofu production-ready?
**A:** Yes! Many organizations use OpenTofu in production, including:
- Major cloud providers
- Fortune 500 companies
- Government agencies

### Q: How do I contribute?
**A:** OpenTofu welcomes contributions:
- GitHub: https://github.com/opentofu/opentofu
- Slack: https://opentofu.org/slack
- Forums: https://github.com/opentofu/opentofu/discussions

## Resources

- [OpenTofu Documentation](https://opentofu.org/docs/)
- [OpenTofu Registry](https://registry.opentofu.org/)
- [Migration Guide](https://opentofu.org/docs/intro/migration/)
- [OpenTofu GitHub](https://github.com/opentofu/opentofu)
- [Community Slack](https://opentofu.org/slack)

## Summary

OpenTofu provides a truly open-source infrastructure as code solution that's 100% compatible with Terraform 1.5.x. For this project, we chose OpenTofu to:

1. Ensure long-term open-source availability
2. Avoid potential licensing issues
3. Support the open-source community
4. Maintain flexibility in our infrastructure choices

The migration is seamless - just replace `terraform` with `tofu` in your commands!