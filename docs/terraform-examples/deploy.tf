##################################################################################
# Attach the add-on profile to a running cluster
#
# Skipped unless cluster_uid is set, so the registry and profile can be created
# on their own first.
#
# On apply, Palette's cluster agent pulls the artifact from Artifactory by
# digest, unpacks the tarball, renders each manifest through the values, and
# applies them in kubeManifests order.
##################################################################################

resource "spectrocloud_addon_deployment" "pack" {
  count = var.create_profile && var.cluster_uid != "" ? 1 : 0

  cluster_uid = var.cluster_uid
  context     = var.cluster_context

  cluster_profile {
    id = spectrocloud_cluster_profile.pack[0].id
  }
}
