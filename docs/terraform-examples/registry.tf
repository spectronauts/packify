##################################################################################
# OCI pack registry
#
# Two provider validations to be aware of:
#   - provider_type "pack" requires is_synchronization = true
#   - is_synchronization = true requires base_content_path
#
# Synchronization also cannot be turned off later. The provider blocks changing
# is_synchronization from true to false as a day-2 operation.
##################################################################################

resource "spectrocloud_registry_oci" "packs" {
  name       = var.registry_name
  type       = "basic"
  endpoint   = var.registry_endpoint
  is_private = true

  # JFrog serves its Docker V2 API under a per-repository path
  endpoint_suffix = var.registry_endpoint_suffix

  # Palette appends spectro-packs itself, so it belongs in neither of these
  base_content_path = var.registry_base_content_path

  provider_type      = "pack"
  is_synchronization = true

  credentials {
    credential_type = "basic"
    username        = var.registry_username
    password        = var.registry_token
  }
}
