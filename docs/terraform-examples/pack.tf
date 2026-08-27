##################################################################################
# Pack lookup
#
# Palette must have finished its first sync before these resolve. wait_for_sync
# does not help here: the provider honours it only for provider_type helm or
# zarf, never pack, so terraform apply returns before the registry is indexed.
#
# If the pack data source errors on a first run, wait for the sync to complete
# and apply again.
##################################################################################

data "spectrocloud_registry_pack" "packs" {
  count = var.create_profile ? 1 : 0

  name = spectrocloud_registry_oci.packs.name

  depends_on = [spectrocloud_registry_oci.packs]
}

data "spectrocloud_pack" "pack" {
  count = var.create_profile ? 1 : 0

  name         = var.pack_name
  version      = var.pack_version
  registry_uid = data.spectrocloud_registry_pack.packs[0].id

  # Do not set type = "manifest" here. The provider short-circuits that case and
  # returns without performing any lookup, leaving every attribute null, which
  # surfaces later as a confusing "pack.0.name is required" error on the profile.
  # Name plus version plus registry_uid is enough to identify the pack.
}
