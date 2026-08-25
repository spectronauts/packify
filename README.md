# packify

#### packify is a shell utility for preparing a helm chart as a pack
packify will pull a helm chart and create the directory structure needed. It will then unpack the chart and use the values.yaml and Readme from the chart to populate the pack. 

A picture of the logo in a file called logo.png needs to be in the local directory.

### Arguments - 
-c    required - Name of the chart name to pull and create

-e    required - Name of the helm repo to pull from

-r    required - Helm release name

-v    required - Chart version to pull

-p    required - The pack type from available options 
    
    os | k8s | cni | csi | addon

-a    required - Addon type if pack type is addon, available options  

    logging | monitoring | load balancer | authentication | ingress | security | app services | network | storage | registry | servicemesh | system app

-n    required - The pack name. This name will override the chart name in directories and final pack values

-s    required - The namespace the pack will be installed in

-o    optional - Overrides helm endpoint for pull command - ie helm pull oci://my-custom-endpoint/chart

### Example use -
    ./packify.sh -c gitlab -e gitlab -r gitlab -v 9.0.1 -p addon -a "system app" -n gitlab -s gitlab

---

# manifestify

#### manifestify is a shell utility for preparing a list of Kubernetes manifests as a pack
manifestify takes one or more manifest files, copies them into a pack directory, and generates the `pack.json` (with the `kubeManifests` list) and `values.yaml` needed for a manifest-based add-on pack. It can then archive the pack and push it to an OCI registry with [oras](https://oras.land).

See [Adding Add-on Packs - Manifests](https://docs.spectrocloud.com/registries-and-packs/adding-add-on-packs/#manifests).

A logo is optional. If a `logo.png` is in the local directory, or a path is passed with `-l`, it is included in the pack; otherwise the pack is built without one and Palette shows a default icon. An explicit `-l` pointing at a file that does not exist is an error.

### Manifest sources -
Manifests are collected from all of the following, in order, preserving order and dropping duplicates:

    -m <path>       a file, or a directory (*.yaml / *.yml, non-recursive). Repeatable.
    -f <listfile>   a text file with one manifest path per line (# comments allowed)
    trailing args   e.g. ./manifestify.sh -n foo ... ./manifests/*.yaml

Each manifest becomes a key under `manifests:` in values.yaml, named after its file basename, so basenames must be unique. Values under that key are scoped to that manifest, so a manifest references them as `{{ .Values.namespace }}`.

### Arguments -
-n    required - Pack name. Also the directory and pack.json name

-v    required - Pack version, e.g. 1.1.0

-p    required - The pack layer from available options

    os | k8s | cni | csi | addon

-s    required - The namespace the pack will be installed in

-a    required when -p is addon - Addon type, available options

    logging | monitoring | load balancer | authentication | ingress | security | app services | network | storage | registry | servicemesh | system app | ai

-m    manifest file or directory. Repeatable

-f    file containing a list of manifest paths, one per line

-d    optional - Display name for the UI. Defaults to the pack name

-r    optional - Path to a README.md for the pack. When omitted a starter readme is generated. A README.md in the working directory is never picked up automatically. On a `-F` rebuild a README.md already inside the pack directory is preserved unless `-r` replaces it

-l    optional - Path to logo.png. Defaults to ./logo.png if present. A logo is not required

-D    optional - Output directory. Defaults to ./&lt;name&gt;-&lt;version&gt;

-R    optional - OCI registry base path, without the `spectro-packs` suffix, e.g. `artifactory.example.com/my-repo`. The script appends `spectro-packs/archive/<name>:<version>` for you. Required for -L and -P

-L    optional - Run `oras login <registry-host>` before pushing

-P    optional - Archive the pack to `<name>-<version>.tar.gz` and push it with oras after building. Implies `-z`

-z    optional - Archive the pack to `<name>-<version>.tar.gz` next to the pack directory, ready to push by hand. Needs no registry and no oras

-I    optional - Skip image extraction from the manifests

-N    optional - Never emit a per-manifest namespace value. By default a namespace is emitted only for manifests that template `{{ .Values.namespace }}`, which cluster-scoped resources such as CRDs do not

-F    optional - Overwrite the output directory if it already exists

### Example use -
    ./manifestify.sh -n permission-manager -v 1.1.0 -p addon -a authentication \
        -s permission-manager -m ./src/permission-manager.yaml

    ./manifestify.sh -n my-pack -v 1.0.0 -p addon -a security -s my-ns \
        -m ./src -R my-registry.example.com -L -P

Build a CRD pack and push it in one go:

    bash ./manifestify.sh -n prometheus-operator-crds -v 0.76.2 \
      -p addon -a monitoring -s monitoring \
      -m ./.manifests/crd -d "Prometheus Operator CRDs" -r README.md \
      -R artifactory.teams.jfrog.com/jarvis-pack-manifests/pavan-packs -L -P

`-R` takes the host and repository path only; the script appends `spectro-packs/archive/<name>:<version>`, so that pushes to:

    artifactory.teams.jfrog.com/jarvis-pack-manifests/pavan-packs/spectro-packs/archive/prometheus-operator-crds:0.76.2

### Manifest order -
`kubeManifests` is written in collection order, and Palette applies the manifests in that order. Directory collection is sorted by filename. When order matters, such as CRDs before the custom resources that use them, list the files explicitly with repeated `-m` flags or with `-f`:

    ./manifestify.sh -n my-pack -v 1.0.0 -p addon -a monitoring -s monitoring \
        -m ./crds/crd-foo.yaml -m ./deploy/operator.yaml

### Pushing to an OCI registry -
`spectro pack push` is deprecated; packs go to OCI registries with [oras](https://oras.land). Palette expects the pack as a gzipped tarball under `spectro-packs/archive`, tagged with the version. `-P` does this for you, or `-z` stops after the tarball so you can push it yourself:

    ./manifestify.sh -n my-pack -v 1.0.0 -p addon -a monitoring -s monitoring \
        -m ./manifests -R artifactory.example.com/my-repo -L -P

The equivalent by hand:

    oras login artifactory.example.com
    tar -czvf my-pack-1.0.0.tar.gz my-pack-1.0.0
    oras push --image-spec v1.0 \
        artifactory.example.com/my-repo/spectro-packs/archive/my-pack:1.0.0 \
        my-pack-1.0.0.tar.gz

The address you push to is the registry's OCI client address. It is not the endpoint you configure Palette with: for Artifactory those differ, as Palette reads over a `/artifactory/api/docker/<repo>` path while an OCI client uses `<host>/<repo>`.

`--image-spec v1.0` is required with oras 1.1 and later, which default to an OCI image-spec v1.1 manifest that Palette does not expect.

Treat a pushed version as immutable. Palette caches the manifest digest it saw when it synced the registry, so re-pushing the same tag leaves it requesting a digest that no longer exists and cluster reconciles fail with `not found`. Bump the version instead.
