# Threat Model (STRIDE)

## Scope

This threat model covers the shared platform infrastructure: the Workload Identity
federation used for keyless CI/CD, the shared event topics, the Terraform state,
and the ownership model. It does not cover the individual services' own threat
models (each has its own), network-level DDoS, or physical security of cloud
infrastructure.

## Assets

| Asset | Sensitivity | Location |
|-------|-------------|----------|
| Workload Identity pool + provider | Critical (the trust root for all deploys) | GCP IAM |
| Deploy service accounts | Critical (can deploy to Cloud Run) | GCP IAM |
| Terraform remote state | High (describes shared infra; may reveal resource names) | GCS bucket |
| Shared event topics | Medium (the ecosystem's event bus) | Pub/Sub |
| The "no long-lived key" property | High (the security posture itself) | verified state |

## Threat Analysis

### S: Spoofing

| Threat | Mitigation |
|--------|------------|
| A repository impersonating another service's deploy account | The provider's `attribute_condition` restricts federation to the owner's repositories, and each `workloadIdentityUser` binding names exactly one repository; a different repo cannot assume another's deploy account. |
| A forged OIDC token | Tokens are issued by GitHub's OIDC issuer and verified by GCP against the provider's issuer URI; a forged token is rejected at exchange. |

### T: Tampering

| Threat | Mitigation |
|--------|------------|
| Unreviewed change to shared infrastructure | Applies are manual and reviewed, not run by a CI credential; the config is code-reviewed and CI-validated. |
| Corrupting Terraform state | State is in a versioned GCS bucket (object versioning enabled), so a bad write can be rolled back. |

### R: Repudiation

| Threat | Mitigation |
|--------|------------|
| Denial of who changed infrastructure | Terraform state history in the versioned bucket, plus Git history of the configuration, record what changed. |

### I: Information Disclosure

| Threat | Mitigation |
|--------|------------|
| Leaked deploy credential | There is no long-lived credential to leak: deploys are keyless, and the one historical stored key (`github-deploy`) was revoked and its account deleted. |
| State exposing secrets | Shared infrastructure holds no secrets in state; service secrets live in each service's own Secret Manager, not here. |

### D: Denial of Service

| Threat | Mitigation |
|--------|------------|
| Deleting the shared pool or a topic breaks the ecosystem | One-owner-per-resource plus reviewed applies reduce accidental deletion; state versioning and Git allow recovery of the definition. |

### E: Elevation of Privilege

| Threat | Mitigation |
|--------|------------|
| A compromised repo escalating beyond its own deploy account | Deploy accounts are least-privilege and repository-scoped; a compromised repo can deploy its own service, not act as the platform. |
| A stolen deploy key granting persistent access | No deploy keys exist; a WIF token is short-lived and repository-bound, so there is no persistent stealable credential. |

## Requirement-to-Evidence

| Property | Evidence |
|----------|----------|
| Zero long-lived CI/CD credentials | `GCP_SA_KEY` in zero of five repos; the `github-deploy` key revoked and the account deleted |
| Repository-scoped federation | per-repo `workloadIdentityUser` bindings; the provider's owner condition |
| Reviewed, non-CI infrastructure changes | no CI apply; manual reviewed applies (ADR-006) |
| Recoverable shared state | versioned GCS state backend |
