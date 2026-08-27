##################################################################################
# Palette credentials
##################################################################################

variable "sc_host" {
  description = "Palette API host, e.g. api.spectrocloud.com for SaaS."
  type        = string
  default     = "api.spectrocloud.com"
}

variable "sc_api_key" {
  description = "Palette API key. Tenant-level, since the OCI registry is a tenant-scoped resource."
  type        = string
  sensitive   = true
}

variable "sc_project_name" {
  description = "Palette project the provider targets."
  type        = string
  default     = "Default"
}

##################################################################################
# Artifactory registry
##################################################################################

variable "registry_name" {
  description = "Name the registry will appear under in Palette."
  type        = string
  default     = "jarvis-pack-registry"
}

variable "registry_endpoint" {
  description = "Artifactory base URL, scheme included, with no API path."
  type        = string
  default     = "https://artifactory.teams.jfrog.com"
}

variable "registry_endpoint_suffix" {
  description = <<-EOT
    Docker V2 API path for the repository. JFrog serves its registry API under
    /artifactory/api/docker/<repo-key>, unlike Harbor which needs only a hostname.
    Do not include spectro-packs - Palette appends that itself.
  EOT
  type        = string
  default     = "/artifactory/api/docker/jarvis-pack-manifests"
}

variable "registry_base_content_path" {
  description = <<-EOT
    Directory inside the repository holding the packs. Palette syncs only at this
    exact level: not the repository root, not nested children. Empty means the root.
  EOT
  type        = string
  default     = "pavan-packs"
}

variable "registry_username" {
  description = "Artifactory username."
  type        = string
}

variable "registry_token" {
  description = "Artifactory identity token. Use a token, not an account password - Artifactory rejects passwords when SSO is enabled."
  type        = string
  sensitive   = true
}

##################################################################################
# Pack
##################################################################################

variable "create_profile" {
  description = <<-EOT
    Look up the pack and build the cluster profile. Leave false on a first apply:
    the registry must finish syncing before the pack can be found, and the
    provider will not wait for a pack registry to sync. Create the registry,
    confirm the pack is indexed, then set this true and apply again.
  EOT
  type        = bool
  default     = false
}

variable "pack_name" {
  description = "Pack name, matching the -n passed to manifestify.sh."
  type        = string
  default     = "prometheus-operator-crds"
}

variable "pack_version" {
  description = "Pack version, matching the -v passed to manifestify.sh and the pushed tag."
  type        = string
  default     = "0.76.2"
}

variable "profile_context" {
  description = <<-EOT
    Scope the cluster profile is created in: project or tenant. A tenant-scoped
    profile is visible across every project, which suits a shared pack like a set
    of CRDs. It can still be attached to clusters that live in a project.
  EOT
  type        = string
  default     = "tenant"

  validation {
    condition     = contains(["project", "tenant"], var.profile_context)
    error_message = "profile_context must be either project or tenant."
  }
}

variable "profile_version" {
  description = "Version of the cluster profile itself. Bump alongside pack_version to keep a rollback point."
  type        = string
  default     = "1.0.0"
}

##################################################################################
# Deployment
##################################################################################

variable "cluster_uid" {
  description = "UID of the cluster to attach the add-on profile to. Leave empty to skip deployment."
  type        = string
  default     = ""
}

variable "cluster_context" {
  description = "Scope of the target *cluster*, which is independent of profile_context. A tenant profile can attach to a cluster in a project."
  type        = string
  default     = "project"

  validation {
    condition     = contains(["project", "tenant"], var.cluster_context)
    error_message = "cluster_context must be either project or tenant."
  }
}
