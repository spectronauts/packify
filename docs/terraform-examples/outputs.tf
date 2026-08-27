output "registry_uid" {
  description = "UID of the OCI pack registry in Palette."
  value       = spectrocloud_registry_oci.packs.id
}

output "pack_uid" {
  description = "UID of the indexed pack. A value here means the registry sync found it."
  value       = one(data.spectrocloud_pack.pack[*].id)
}

output "profile_uid" {
  description = "UID of the add-on cluster profile."
  value       = one(spectrocloud_cluster_profile.pack[*].id)
}

output "push_target" {
  description = "Where manifestify.sh should push this pack version, for cross-checking against the registry configuration."
  value = join("/", compact([
    replace(replace(var.registry_endpoint, "https://", ""), "http://", ""),
    trim(var.registry_base_content_path, "/"),
    "spectro-packs/archive/${var.pack_name}:${var.pack_version}",
  ]))
}
