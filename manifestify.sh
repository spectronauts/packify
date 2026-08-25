#!/bin/bash
################################################################################
# manifestify - build a manifest-based Palette pack from a list of manifests    #
#                                                                              #
# Ref: https://docs.spectrocloud.com/registries-and-packs/adding-add-on-packs/ #
################################################################################

Help()
{
   echo -e "\e[32m###############################################################################\e[0m"
   echo -e "\e[32m#########                       manifestify                          #########\e[0m"
   echo -e "\e[32m###############################################################################\e[0m"
   echo -e "\e[32m#########   build a manifest-based pack and push it to a registry    #########\e[0m"
   echo -e "\e[32m###############################################################################\e[0m"
   echo
   echo "A manifest-based pack needs 4 things, manifestify assembles them locally:"
   echo "1 - a manifests/ directory holding one or more Kubernetes manifest files"
   echo "2 - a values.yaml exposing per-manifest parameters"
   echo "3 - a pack.json with metadata, including the kubeManifests list"
   echo "4 - optionally a logo.png for the UI image, provided separately. Palette"
   echo "    shows a default icon when the pack has none"
   echo "    (a starter README.md is generated when -r is not given)"
   echo
   echo -e "\e[93mManifest sources\e[0m"
   echo "Manifests are collected from, in order, all of:"
   echo "  -m <path>     a file, or a directory (*.yaml / *.yml, non-recursive). Repeatable."
   echo "  -f <listfile> a text file with one manifest path per line (# comments allowed)"
   echo "  trailing arguments after the flags, e.g. manifestify.sh -n foo ./manifests/*.yaml"
   echo "Order is preserved and duplicates are dropped."
   echo
   echo -e "\e[93mExample Usage:\e[0m"
   echo -e "\e[3m   manifestify.sh -n permission-manager -v 1.1.0 -p addon -a authentication \\\\\e[0m"
   echo -e "\e[3m       -s permission-manager -m ./src/permission-manager.yaml\e[0m"
   echo
   echo -e "\e[3m   manifestify.sh -n my-pack -v 1.0.0 -p addon -a security -s my-ns \\\\\e[0m"
   echo -e "\e[3m       -m ./src -R my-registry.example.com -L -P\e[0m"
   echo
   echo -e "\e[93mOptions:\e[0m"
   echo "-h    help"
   echo "-n    required - Pack name. Also the directory and pack.json name"
   echo "-v    required - Pack version, e.g. 1.1.0"
   echo "-p    required - Pack layer, one of:"
   echo "                 |os|k8s|cni|csi|addon"
   echo "-a    required when -p is addon - Addon type, one of:"
   echo "                 |logging|monitoring|load balancer|authentication"
   echo "                 |ingress|security|app services|network|storage"
   echo "                 |registry|servicemesh|system app|ai"
   echo "-s    required - Namespace the pack will be installed in"
   echo "-m    manifest file or directory. Repeatable. See 'Manifest sources' above"
   echo "-f    file containing a list of manifest paths, one per line"
   echo "-d    optional - Display name for the UI. Defaults to the pack name"
   echo "-r    optional - Path to a README.md for the pack. When omitted a starter"
   echo "                 readme is generated. A README.md in the working directory"
   echo "                 is never picked up automatically"
   echo "-l    optional - Path to logo.png. Defaults to ./logo.png if present."
   echo "                 A logo is not required, but an explicit -l that does not"
   echo "                 exist is an error"
   echo "-D    optional - Output directory. Defaults to ./<name>-<version>"
   echo "-R    optional - OCI registry host and repository path, without the"
   echo "                 spectro-packs suffix. The script appends"
   echo "                 spectro-packs/archive/<name>:<version> for you."
   echo "                 e.g. artifactory.example.com/my-repo"
   echo "                 This is the registry address an OCI client uses, which"
   echo "                 is not the same as the endpoint Palette is configured"
   echo "                 with - Artifactory serves Palette on a"
   echo "                 /artifactory/api/docker/<repo> path instead."
   echo "                 Required for -L and -P"
   echo "-L    optional - Run 'oras login <registry-host>' before pushing"
   echo "-P    optional - Archive the pack and push it with oras after building."
   echo "                 Implies -z"
   echo "-z    optional - Archive the pack to <name>-<version>.tar.gz next to the"
   echo "                 pack directory, ready to push by hand. No registry needed"
   echo "-I    optional - Skip image extraction from the manifests"
   echo "-N    optional - Never emit a per-manifest namespace value. By default a"
   echo "                 namespace is emitted only for manifests that template"
   echo "                 {{ .Values.namespace }}, which cluster-scoped resources"
   echo "                 such as CRDs do not"
   echo "-F    optional - Overwrite the output directory if it already exists"
}

################################################################################
# Defaults                                                                     #
################################################################################
set -euo pipefail

PackName=""
PackVersion=""
PackType=""
AddonType=""
PackNamespace=""
DisplayName=""
ReadmePath=""
ReadmePreserved="false"
LogoPath=""
LogoExplicit="false"
HaveLogo="false"
OutDir=""
RegistryServer=""
DoLogin="false"
DoPush="false"
DoArchive="false"
SkipImages="false"
Force="false"
NoNsValues="false"
declare -a ManifestArgs=()
ListFile=""

################################################################################
# Process the input options                                                    #
################################################################################
while getopts "n:v:p:a:s:m:f:d:l:r:D:R:LPzIFNh" option; do
   case $option in
      n) PackName=$OPTARG;;
      v) PackVersion=$OPTARG;;
      p) if [[ $OPTARG != "os" && $OPTARG != "k8s" && $OPTARG != "cni" && $OPTARG != "csi" && $OPTARG != "addon" ]]; then
            echo -e "\e[31mError: argument for -p (layer) must be one of os, k8s, cni, csi, addon\e[0m" >&2
            exit 1
         fi
         PackType=$OPTARG;;
      a) if [[ $OPTARG != "logging" && $OPTARG != "monitoring" && $OPTARG != "load balancer" && $OPTARG != "authentication" && $OPTARG != "ingress" && $OPTARG != "security" && $OPTARG != "app services" && $OPTARG != "network" && $OPTARG != "storage" && $OPTARG != "registry" && $OPTARG != "servicemesh" && $OPTARG != "system app" && $OPTARG != "ai" ]]; then
            echo -e "\e[31mError: argument for -a (addontype) must be one of the following types: logging, monitoring, load balancer, authentication, ingress, security, app services, network, storage, registry, servicemesh, system app, ai\e[0m" >&2
            exit 1
         fi
         AddonType=$OPTARG;;
      s) PackNamespace=$OPTARG;;
      m) ManifestArgs+=("$OPTARG");;
      f) ListFile=$OPTARG;;
      d) DisplayName=$OPTARG;;
      l) LogoPath=$OPTARG
         LogoExplicit="true";;
      r) ReadmePath=$OPTARG;;
      D) OutDir=$OPTARG;;
      R) RegistryServer=$OPTARG;;
      L) DoLogin="true";;
      P) DoPush="true";;
      z) DoArchive="true";;
      I) SkipImages="true";;
      F) Force="true";;
      N) NoNsValues="true";;
      h) Help
         exit 0;;
      ?) echo -e "\e[31mError: Invalid option\e[0m" >&2
         echo "Use -h for usage" >&2
         exit 1;;
   esac
done
#anything left over is treated as a manifest path, so globs work
shift $((OPTIND - 1))
if [ "$#" -gt 0 ]; then
    ManifestArgs+=("$@")
fi

################################################################################
# Validate arguments                                                           #
################################################################################
ExecDir=$(pwd)

UsageError() {
    echo -e "\e[31mError - $1\e[0m" >&2
    echo "" >&2
    echo -e "\e[93mExample Usage:\e[0m" >&2
    echo -e "\e[3m   manifestify.sh -n permission-manager -v 1.1.0 -p addon -a authentication -s permission-manager -m ./src\e[0m" >&2
    echo "" >&2
    echo "Use -h argument for more detail" >&2
    exit 1
}

[ -n "$PackName" ]      || UsageError "missing required argument -n (pack name)"
[ -n "$PackVersion" ]   || UsageError "missing required argument -v (version)"
[ -n "$PackType" ]      || UsageError "missing required argument -p (layer)"
[ -n "$PackNamespace" ] || UsageError "missing required argument -s (namespace)"
#addonType only carries meaning for the addon layer
if [ "$PackType" = "addon" ] && [ -z "$AddonType" ]; then
    UsageError "-a (addontype) is required when -p is addon"
fi
if [ "$PackType" != "addon" ] && [ -n "$AddonType" ]; then
    echo -e "\e[93mWarning: -a is ignored for layer '$PackType', addonType only applies to addon packs\e[0m"
    AddonType=""
fi
if [ "$DoPush" = "true" ] || [ "$DoLogin" = "true" ]; then
    [ -n "$RegistryServer" ] || UsageError "-R (registry server) is required with -L or -P"
fi

#an explicit -r pointing at nothing is a mistake worth stopping for
if [ -n "$ReadmePath" ] && [ ! -f "$ReadmePath" ]; then
    UsageError "readme file '$ReadmePath' not found"
fi

[ -n "$DisplayName" ] || DisplayName=$PackName
[ -n "$LogoPath" ]    || LogoPath="$ExecDir/logo.png"
[ -n "$OutDir" ]      || OutDir="$ExecDir/$PackName-$PackVersion"
#normalise a relative -D against the invocation directory
case "$OutDir" in
    /*) ;;
     *) OutDir="$ExecDir/$OutDir";;
esac

echo -e "\e[32mBuilding manifest pack \e[1m$PackName-$PackVersion\e[0m"
echo ""

################################################################################
# Collect the manifest list                                                    #
################################################################################
declare -a Manifests=()

AddManifest() {
    local file=$1
    #drop duplicates so overlapping -m and glob arguments are harmless
    local existing
    for existing in ${Manifests+"${Manifests[@]}"}; do
        if [ "$existing" = "$file" ]; then
            return 0
        fi
    done
    Manifests+=("$file")
}

CollectPath() {
    local path=$1
    if [ -d "$path" ]; then
        local found="false"
        local file
        #non-recursive, sorted for a stable kubeManifests order
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            AddManifest "$file"
            found="true"
        done < <(find "$path" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) | sort)
        if [ "$found" = "false" ]; then
            echo -e "\e[31mError: no .yaml or .yml files found in directory '$path'\e[0m" >&2
            exit 1
        fi
    elif [ -f "$path" ]; then
        AddManifest "$path"
    else
        echo -e "\e[31mError: manifest path '$path' not found\e[0m" >&2
        exit 1
    fi
}

if [ -n "$ListFile" ]; then
    [ -f "$ListFile" ] || UsageError "list file '$ListFile' not found"
    while IFS= read -r line || [ -n "$line" ]; do
        #strip comments and surrounding whitespace, skip blanks
        line=${line%%#*}
        line=$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [ -n "$line" ] || continue
        CollectPath "$line"
    done < "$ListFile"
fi

for arg in ${ManifestArgs+"${ManifestArgs[@]}"}; do
    CollectPath "$arg"
done

if [ "${#Manifests[@]}" -eq 0 ]; then
    UsageError "no manifests provided, use -m, -f, or trailing arguments"
fi

echo -e "\e[93mCollected ${#Manifests[@]} manifest file(s)\e[0m"
for file in "${Manifests[@]}"; do
    if [ ! -s "$file" ]; then
        echo -e "\e[31mError: manifest '$file' is empty\e[0m" >&2
        exit 1
    fi
    echo "    $file"
done
echo ""

#manifest names are the basenames without extension, and must be unique because
#they become the keys under the values.yaml manifests: block
declare -a ManifestNames=()
declare -a ManifestTargets=()
for file in "${Manifests[@]}"; do
    base=$(basename "$file")
    name=${base%.*}
    for existing in ${ManifestNames+"${ManifestNames[@]}"}; do
        if [ "$existing" = "$name" ]; then
            echo -e "\e[31mError: duplicate manifest name '$name'\e[0m" >&2
            echo "   manifest names come from the file name, so two files cannot share a basename" >&2
            exit 1
        fi
    done
    ManifestNames+=("$name")
    ManifestTargets+=("$name.yaml")
done

################################################################################
# Check for the logo                                                           #
################################################################################
echo -e "\e[93mChecking for logo file.\e[0m"
if [ -f "$LogoPath" ]; then
    echo -e "\e[32m    Found logo file for pack.\e[0m"
    HaveLogo="true"
elif [ -f "$OutDir/logo.png" ]; then
    echo -e "\e[32m    Found logo file in pack directory.\e[0m"
    LogoPath="$OutDir/logo.png"
    HaveLogo="true"
elif [ "$LogoExplicit" = "true" ]; then
    #an explicit -l pointing at nothing is a mistake worth stopping for
    echo -e "\e[31mError: logo file '$LogoPath' not found\e[0m" >&2
    exit 1
else
    #a logo is not one of the files Palette requires, so carry on without one
    echo -e "\e[93m    No logo.png found, building pack without one\e[0m"
    echo "    Palette will show a default icon. Add logo.png to the pack directory"
    echo "    later, or pass a path with -l, to give the pack its own image"
fi
echo ""

################################################################################
# Create the pack directory                                                    #
################################################################################
if [ -e "$OutDir" ]; then
    if [ "$Force" = "true" ]; then
        echo -e "\e[93mOutput directory exists, -F given, replacing contents of $OutDir\e[0m"
        #keep a logo that already lives in the target from being deleted underneath us
        if [ "$HaveLogo" = "true" ] && [ "$LogoPath" = "$OutDir/logo.png" ]; then
            TmpLogo=$(mktemp -t manifestify-logo)
            cp "$LogoPath" "$TmpLogo"
            LogoPath="$TmpLogo"
        fi
        #same for a readme edited in place, unless -r is replacing it anyway
        if [ -z "$ReadmePath" ] && [ -f "$OutDir/README.md" ]; then
            TmpReadme=$(mktemp -t manifestify-readme)
            cp "$OutDir/README.md" "$TmpReadme"
            ReadmePath="$TmpReadme"
            ReadmePreserved="true"
        fi
        rm -rf "$OutDir"
    else
        echo -e "\e[31mError: output directory '$OutDir' already exists, use -F to overwrite\e[0m" >&2
        exit 1
    fi
fi

echo -e "\e[93mCreating pack directory and copying manifests\e[0m"
mkdir -p "$OutDir/manifests"
index=0
while [ "$index" -lt "${#Manifests[@]}" ]; do
    cp "${Manifests[$index]}" "$OutDir/manifests/${ManifestTargets[$index]}"
    echo "    manifests/${ManifestTargets[$index]}"
    index=$((index + 1))
done
echo ""

################################################################################
# Extract image references from the manifests                                  #
################################################################################
ImageList=""
if [ "$SkipImages" = "true" ]; then
    echo -e "\e[93mImage extraction skipped (-I)\e[0m"
    echo ""
else
    echo -e "\e[93mAttempting to extract image references from the manifests\e[0m"
    #pull image: values, strip quotes, drop templated values we cannot resolve,
    #then format as a yaml list under pack.content.images
    ImageList=$(grep -hE '^[[:space:]]*-?[[:space:]]*image:[[:space:]]*[^[:space:]]' "$OutDir/manifests"/*.yaml 2>/dev/null \
        | sed -e 's/.*image:[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'"'"']//' -e 's/["'"'"']$//' \
        | grep -v '{{' \
        | sed -e '/^$/d' \
        | sort -u \
        | awk '{print "      - image: " $0}' || true)

    if [ -n "$ImageList" ]; then
        echo -e "\e[32m  Image list extracted\e[0m"
        echo "$ImageList"
    else
        echo -e "\e[31mImage list could not be extracted\e[0m"
        echo "   continuing with pack creation, images may need to be manually put into pack for edge use"
    fi
    echo ""
fi

################################################################################
# pack.json contents template                                                  #
################################################################################
#build the kubeManifests json array from the copied manifest files
KubeManifests=""
for target in "${ManifestTargets[@]}"; do
    if [ -n "$KubeManifests" ]; then
        KubeManifests="$KubeManifests,
"
    fi
    KubeManifests="$KubeManifests    \"manifests/$target\""
done

#addonType is only emitted for addon packs
AddonField=""
if [ -n "$AddonType" ]; then
    AddonField="  \"addonType\": \"$AddonType\",
"
fi

content=$(cat <<EOF
{
$AddonField  "annotations": {
    "source": "community",
    "contributor": "spectrocloud"
  },
  "cloudTypes": [
    "all"
  ],
  "displayName": "$DisplayName",
  "kubeManifests": [
$KubeManifests
  ],
  "layer": "$PackType",
  "name": "$PackName",
  "version": "$PackVersion"
}
EOF
)

################################################################################
# values.yaml template                                                         #
################################################################################
#pack.content.images is only emitted when images were found, an empty list is
#rejected by the pack validator
PackContent=""
if [ -n "$ImageList" ]; then
    PackContent="  content:
    images:
$ImageList
"
fi

#one block per manifest, keyed by name. Values here are scoped to that manifest,
#so a manifest refers to them as {{ .Values.namespace }}. Only emit a namespace
#for manifests that actually template one - cluster-scoped resources such as CRDs
#do not, and a stray value there is misleading
ManifestValues=""
index=0
while [ "$index" -lt "${#ManifestNames[@]}" ]; do
    name=${ManifestNames[$index]}
    target=${ManifestTargets[$index]}
    if [ "$NoNsValues" = "false" ] && grep -q '\.Values\.namespace' "$OutDir/manifests/$target"; then
        ManifestValues="$ManifestValues  $name:
    namespace: \"$PackNamespace\"
"
    else
        #key must still be present so the manifest is rendered, with no values to override
        ManifestValues="$ManifestValues  $name: {}
"
    fi
    index=$((index + 1))
done

values=$(cat <<EOF
pack:
  spectrocloud.com/display-name: $DisplayName
  namespace: $PackNamespace
$PackContent
manifests:
$ManifestValues
EOF
)

echo -e "\e[93mCreating values.yaml\e[0m"
printf '%s\n' "$values" > "$OutDir/values.yaml"
echo ""

echo -e "\e[93mCreating pack.json metadata file\e[0m"
printf '%s\n' "$content" > "$OutDir/pack.json"
echo ""

################################################################################
# README and logo                                                              #
################################################################################
if [ "$ReadmePreserved" = "true" ]; then
    echo -e "\e[93mKeeping the README.md already in the pack directory\e[0m"
    cp "$ReadmePath" "$OutDir/README.md"
elif [ -n "$ReadmePath" ]; then
    echo -e "\e[93mCopying $ReadmePath to pack path\e[0m"
    cp "$ReadmePath" "$OutDir/README.md"
else
    #only a -r readme is copied in, so a stray README.md in the working
    #directory is never mistaken for the pack's own
    echo -e "\e[93mNo readme supplied\e[0m"
    echo "   Creating starter readme, pass one with -r to use your own"
    printf '# %s\n\nVersion %s\n' "$DisplayName" "$PackVersion" > "$OutDir/README.md"
fi
echo ""

if [ "$HaveLogo" = "true" ]; then
    echo -e "\e[93mPlacing logo.png in pack directory\e[0m"
    if [ "$LogoPath" != "$OutDir/logo.png" ]; then
        cp "$LogoPath" "$OutDir/logo.png"
    fi
    echo "  Logo file present in pack directory"
else
    echo -e "\e[93mNo logo.png included in the pack\e[0m"
fi
echo ""

################################################################################
# Validate the generated yaml where a parser is available                       #
################################################################################
if command -v python3 >/dev/null 2>&1; then
    echo -e "\e[93mValidating generated values.yaml and pack.json\e[0m"
    python3 - "$OutDir" <<'PY' || { echo -e "\e[31mGenerated files failed validation\e[0m" >&2; exit 1; }
import json, sys, os
out = sys.argv[1]
with open(os.path.join(out, "pack.json")) as fh:
    json.load(fh)
try:
    import yaml
except ImportError:
    print("  pack.json is valid json (pyyaml missing, skipping values.yaml parse)")
    sys.exit(0)
with open(os.path.join(out, "values.yaml")) as fh:
    yaml.safe_load(fh)
print("  pack.json and values.yaml parsed cleanly")
PY
    echo ""
fi

echo -e "\e[32mPack \e[1m$PackName-$PackVersion\e[0m \e[32mbuilt at $OutDir\e[0m"
echo ""

################################################################################
# Push to the registry                                                         #
################################################################################
#Palette expects packs under the spectro-packs/archive path, tagged with the
#version, and appends spectro-packs itself when it reads the registry
Archive="$(dirname "$OutDir")/$PackName-$PackVersion.tar.gz"
PushTarget="$RegistryServer/spectro-packs/archive/$PackName:$PackVersion"
#oras logs in against the host, not the full repository path
RegistryHost=${RegistryServer%%/*}

if [ "$DoLogin" = "true" ] || [ "$DoPush" = "true" ]; then
    echo -e "\e[93mTesting oras is present.\e[0m"
    command -v oras >/dev/null 2>&1 || {
        echo >&2 -e "\e[31mmanifestify requires oras to push but it's not installed or can't be accessed.  Aborting.\e[0m"
        echo >&2 "   The pack was built successfully at $OutDir, it can be pushed later with:"
        echo >&2 "     tar -czvf $PackName-$PackVersion.tar.gz $PackName-$PackVersion"
        echo >&2 "     oras push --image-spec v1.0 $PushTarget $PackName-$PackVersion.tar.gz"
        exit 1
    }
    echo ""
fi

if [ "$DoLogin" = "true" ]; then
    echo -e "\e[93mLogging in to $RegistryHost\e[0m"
    oras login "$RegistryHost"
    echo ""
fi

#pushing needs the tarball, so -P implies -z
if [ "$DoArchive" = "true" ] || [ "$DoPush" = "true" ]; then
    #archive from the parent so the pack directory is the root of the tarball
    echo -e "\e[93mArchiving pack\e[0m"
    tar -czf "$Archive" -C "$(dirname "$OutDir")" "$(basename "$OutDir")"
    echo "  $Archive"
    echo "  $(du -h "$Archive" | awk '{print $1}') compressed"
    echo ""
fi

if [ "$DoPush" = "true" ]; then
    echo -e "\e[93mPushing pack to $PushTarget\e[0m"
    #oras refuses absolute file paths, and the file name it records becomes the
    #name Palette pulls back, so push from the archive directory by bare name.
    #--image-spec v1.0 keeps the manifest in the shape Palette expects, which
    #newer oras releases no longer produce by default
    (
        cd "$(dirname "$Archive")"
        oras push --image-spec v1.0 "$PushTarget" "$(basename "$Archive")"
    )
    echo ""
    echo -e "\e[32mPack \e[1m$PackName-$PackVersion\e[0m \e[32mpushed to $PushTarget\e[0m"
else
    echo -e "\e[32mReady to edit and push:\e[0m"
    echo -e "\e[3m    oras login ${RegistryHost:-<registry-host>}\e[0m"
    #the tar step is already done when -z was given
    if [ "$DoArchive" = "false" ]; then
        echo -e "\e[3m    tar -czvf $PackName-$PackVersion.tar.gz $PackName-$PackVersion\e[0m"
    fi
    if [ -n "$RegistryServer" ]; then
        echo -e "\e[3m    oras push --image-spec v1.0 $PushTarget $PackName-$PackVersion.tar.gz\e[0m"
    else
        echo -e "\e[3m    oras push --image-spec v1.0 <registry>/spectro-packs/archive/$PackName:$PackVersion $PackName-$PackVersion.tar.gz\e[0m"
    fi
fi
