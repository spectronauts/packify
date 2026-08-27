##################################################################################
# Add-on cluster profile
#
# Packs reach clusters through profiles. For something added to existing
# clusters, that means an add-on profile.
#
# Taking values straight from the data source uses the pack's own defaults.
# To override a parameter, replace the values argument with your own YAML,
# mirroring the structure of the pack's values.yaml:
#
#   values = <<-EOT
#     pack:
#       namespace: monitoring
#     manifests:
#       crd-prometheuses: {}
#   EOT
##################################################################################

resource "spectrocloud_cluster_profile" "pack" {
  count = var.create_profile ? 1 : 0

  name        = var.pack_name
  description = "${var.pack_name} ${var.pack_version}"
  type        = "add-on"
  cloud       = "all"
  version     = var.profile_version
  context     = var.profile_context

  pack {
    name   = data.spectrocloud_pack.pack[0].name
    tag    = data.spectrocloud_pack.pack[0].version
    uid    = data.spectrocloud_pack.pack[0].id
    values = data.spectrocloud_pack.pack[0].values
  }
}
