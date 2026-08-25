# Terraform

Registers a manifest pack's OCI registry in Palette, wraps the pack in an add-on
cluster profile, and optionally deploys it to a running cluster.

Build and push the pack first with `manifestify.sh` — this configuration reads a
pack that already exists in the registry, it does not create one.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then fill in credentials
terraform init
```

Apply in two passes, because a pack registry has to sync before its packs can be
looked up and the provider will not wait for that.

**First pass — registry only.** With `create_profile = false` (the default),
apply builds just the registry:

```bash
terraform apply
```

Confirm the pack is indexed, in the Palette UI under Tenant Settings &rarr;
Registries, or with the CLI:

```bash
oras repo tags <push_target without the tag>
```

**Second pass — profile.** Set `create_profile = true` and apply again:

```bash
terraform apply -var create_profile=true
```

Leave `cluster_uid` unset to build the profile without deploying it. Set it to
deploy in the same pass.

## Scope

Three scopes are in play, and they are independent:

| Setting | Default | Meaning |
|---|---|---|
| `spectrocloud_registry_oci` | tenant | The registry is always tenant-scoped. |
| `profile_context` | `tenant` | Where the cluster profile lives. Tenant makes it visible in every project. |
| `cluster_context` | `project` | Where the target cluster lives. |

A tenant-scoped profile attaches to a cluster inside a project, so
`profile_context = "tenant"` with `cluster_context = "project"` is the normal
combination for a shared pack.

Tenant scope needs a tenant-level API key, which the registry resource requires
anyway.

## Files

| File | Contents |
|---|---|
| `versions.tf` | Provider requirements and provider block |
| `variables.tf` | All inputs, with demo defaults |
| `registry.tf` | `spectrocloud_registry_oci` — the OCI pack registry |
| `pack.tf` | Registry and pack lookups |
| `profile.tf` | `spectrocloud_cluster_profile` — the add-on profile |
| `deploy.tf` | `spectrocloud_addon_deployment` — attach to a cluster |
| `outputs.tf` | Registry, pack, and profile UIDs, plus the expected push target |

## Two addresses

The address you push to is not the endpoint Palette reads from. Both point at
the same artifact.

| Used by | Value |
|---|---|
| `oras push` | `artifactory.teams.spectrocloud.com/jarvis-pack-manifests/pavan-packs` |
| `endpoint` + `endpoint_suffix` | `https://artifactory.teams.spectrocloud.com` + `/artifactory/api/docker/jarvis-pack-manifests` |
| `base_content_path` | `pavan-packs` |

oras is a Docker V2 client and always requests `/v2/<repo>/…`. Artifactory's
`/artifactory/api/docker/<repo>/` path is a server-side endpoint that Palette
uses over plain HTTP.

The `push_target` output prints the address `manifestify.sh -R` should be given,
derived from the same variables, so the two cannot drift.

`spectro-packs` appears in the push path but in none of the Terraform fields —
Palette appends it when reading the registry.

## Constraints enforced by the provider

- `provider_type = "pack"` requires `is_synchronization = true`
- `is_synchronization = true` requires `base_content_path`
- Synchronization cannot be disabled after creation
- `wait_for_sync` is ignored for pack registries — it applies only to `helm` and
  `zarf`, so `apply` returns before the first sync finishes

That last one matters on a first run: `data.spectrocloud_pack` may not resolve
until the sync completes. Wait, then apply again.

## Immutability

Palette caches the manifest digest it saw at sync time. Re-pushing an existing
tag moves it to a new digest and leaves Palette requesting one that no longer
exists, which fails cluster reconciles with `not found` in a loop.

Bump `pack_version`, push that, and bump `profile_version` alongside it.
