#!/bin/bash
################################################################################
# Help                                                                         #
################################################################################
Help()
{
   # Display Help                                                               
   echo -e "\e[0m\e[32m                                    #****#                                                \e[0m"                     
   echo -e "\e[0m\e[32m                                 #***********                                             \e[0m"
   echo -e "\e[0m\e[32m                              #*****************                                          \e[0m"
   echo -e "\e[0m\e[32m                           #***********************                                       \e[0m"
   echo -e "\e[0m\e[32m                        ******************************                                    \e[0m"
   echo -e "\e[0m\e[32m                     ************************************#                                \e[0m"
   echo -e "\e[0m\e[32m                  #*****************************************                              \e[0m"
   echo -e "\e[2m\e[92m                  #######################\e[0m\e[32m*****************#                    \e[0m"
   echo -e "\e[2m\e[92m                     #######################\e[0m\e[32m***********%                       \e[0m"
   echo -e "\e[2m\e[92m                       %#######################\e[0m\e[32m*****#                          \e[0m"
   echo -e "\e[2m\e[92m                          #######################%                                        \e[0m"
   echo -e "\e[0m\e[32m                       *******\e[2m\e[92m################\e[2m\e[32m%%%%%%%               \e[0m"    
   echo -e "\e[0m\e[32m                    #************\e[2m\e[92m#########\e[2m\e[32m%%%%%%%%%%%%%%            \e[0m"    
   echo -e "\e[0m\e[32m                 #******************\e[2m\e[92m####\e[2m\e[32m%%%%%%%%%%%%%%%%%%%         \e[0m"    
   echo -e "\e[0m\e[32m                 #****************************************#                               \e[0m" 
   echo -e "\e[0m\e[32m                    #**********************************#                                  \e[0m"
   echo -e "\e[0m\e[32m                       %****************************#                                     \e[0m"
   echo -e "\e[0m\e[32m                          #**********************#                                        \e[0m" 
   echo -e "\e[0m\e[32m                              ****************#                                           \e[0m"
   echo -e "\e[0m\e[32m                                 **********                                               \e[0m"
   echo -e "\e[0m\e[32m                                    #**#                                                  \e[0m"
                                                                              
   echo ""
   echo -e "\e[32m###############################################################################\e[0m"
   echo -e "\e[32m#########                        packify                            #########\e[0m"
   echo -e "\e[32m###############################################################################\e[0m"
   echo -e "\e[32m#########  packify is a utility for converting helm charts to packs #########\e[0m"
   echo -e "\e[32m###############################################################################\e[0m"
   echo "Packs require 5 things, that packify will pull together locally so packs are "
   echo "ready to be edited and pushed" 
   echo "1 - a zipped chart in the charts directory"
   echo "2 - a values.yaml for value overrides"
   echo "3 - a pack.json file with metadata about the pack"
   echo "4 - a README.md file about the pack, if available one will be copied from the chart"
   echo "5 - a logo.png picture for the UI image. This needs to be provided separately"
   echo 
   echo -e "\e[93mFirst add the repo to helm and confirm chart version number\e[0m"
   echo
   echo -e "\e[93mExample:\e[0m"
   echo -e "\e[3m    helm repo add opencost https://opencost.github.io/opencost-helm-chart/\e[0m"
   echo -e "\e[3m   helm search repo opencost --versions\e[0m"
   echo
   echo -e "\e[93mExample Usage:\e[0m" 
   echo -e "\e[3m   packify -c opencost -e opencost-charts -r opencost -v 2.1.3 -p addon -a monitoring -n opencost -s opencost\e[0m"
   echo 
   echo -e "\e[93mOptions:\e[0m"
   echo "-h    help"
   echo "-c    required - Name of the chart to pull and create"
   echo "-e    required - Name of the helm repo to pull from"
   echo "-r    required - Helm release name"
   echo "-v    required - Chart version to pull"
   echo "-p    required - The pack type from available options below"
   echo "                 |os|k8s|cni|csi|addon"
   echo "-a    required - Addon type if pack type is addon, available options below" 
   echo "                 |logging|monitoring|load balancer|authentication"
   echo "                 |ingress|security|app services|network|storage"
   echo "                 |registry|servicemesh|system app|ai"
   echo "-n    required - The pack name. This name will override the chart name in directories and final pack values"
   echo "-s    required - The namespace the pack will be installed in"
   echo -e "-o    optional - Overrides helm endpoint for pull command - ie \e[3m helm pull oci://my-custom-endpoint/chart\e[0m"
}
################################################################################
# Process the input options.                                                   #
################################################################################
# Get the options
while getopts "c:e:r:v:p:a:n:s:oh" option; do
   case $option in
      c) #Enter the Chart Name
         Chart=$OPTARG;;
      e) #Enter the helm repo
         HelmRepo=$OPTARG;;
      r) #Enter the Release Name
         Release=$OPTARG;;
      v) #Enter the versions
         ChartVersion=$OPTARG;;
      p) #Enter the pack type os|k8s|cni|csi|addon
         if [[ $OPTARG != "os" && $OPTARG != "k8s" && $OPTARG != "cni" && $OPTARG != "csi" && $OPTARG != "addon" ]]; then
            echo "Error: argument for -p (packtype) must be one of os, k8s, cni, csi, addon"
            exit 1
         fi
         PackType=$OPTARG;;
      a) #Enter the addon type |logging|monitoring|load balancer|authentication|ingress|security|app services|network|storage|registry|servicemesh|system app|ai
         if [[ $OPTARG != "logging" && $OPTARG != "monitoring" && $OPTARG != "load balancer" && $OPTARG != "authentication" && $OPTARG != "ingress" && $OPTARG != "security" && $OPTARG != "app services" && $OPTARG != "network" && $OPTARG != "storage" && $OPTARG != "registry" && $OPTARG != "servicemesh" && $OPTARG != "system app" && $OPTARG != "ai" ]]; then
            echo "Error: argument for -a (addontype) must be one of the following types: logging, monitoring, load balancer, authentication, ingress, security, app services, network, storage, registry, servicemesh, system app, ai"
            exit 1
         fi
         AddonType=$OPTARG;;
      n) #Enter the desired pack name
         PackName=$OPTARG;;
      s) #Enter the desired namespace for the pack to be deployed to
         PackNamespace=$OPTARG;;
      o) #Enter the custom helm endpoint override
         HelmEndpoint=$OPTARG;;
      h) # display Help
            Help
            exit;;
      ?) # incorrect option
         echo "Error: Invalid option"
         echo "Example Usage:" 
         echo "    packify -c opencost -e opencost-charts -r opencost -v 2.1.3 -p addon -a monitoring -n opencost -s opencost"
         exit 1;;

   esac
done


################################################################################
# Main Program                                                                 #
################################################################################
set -eo pipefail
IFS=$'\n\t'

ExecDir=$(pwd)


if [ -z "$Chart" ] || [ -z "$HelmRepo" ] || [ -z "$Release" ] || [ -z "$ChartVersion" ] || [ -z "$PackType" ] || [ -z "$AddonType" ] || [ -z "$PackName" ] || [ -z "$PackNamespace" ]; then
    echo -e "\e[31mError - missing required arguments\e[0m"
    echo ""
    echo -e "\e[93mExample Usage:\e[0m" 
    echo -e "\e[3m    packify -c opencost -e opencost-charts -r opencost -v 2.1.3 -p addon -a monitoring -n opencost -s opencost\e[0m"
    echo ""
    echo "Use -h argument for more detail"
    exit 1
else 
    echo -e "\e[32mBuilding pack for \e[1m$Chart\e[0m"
    echo ""

fi

#checking for dependencies
echo -e "\e[93mTesting helm is present.\e[0m"
echo ""
command -v helm >/dev/null 2>&1 || { echo >&2 -e "\e[31mpackify requires access to helm but it's not installed or can't be accessed.  Aborting.\e[0m"; exit 1; }

echo -e "\e[93mChecking for logo file.\e[0m"
echo ""
if test -f $ExecDir/logo.png || test -f $ExecDir/$PackName-$ChartVersion/logo.png ; then
    echo -e "\e[32m    Found logo file for pack.\e[0m"
    echo ""
else
    echo -e "\e[31mLogo file not found, please add a file called logo.png to the directory\e[0m" && exit 1
fi

echo -e "\e[93mTesting helm repo provided is searchable\e[0m"
echo ""
helm search repo $HelmRepo --version $ChartVersion --fail-on-no-result

if [ -z "$HelmEndpoint" ]; then
    echo ""
    echo "pulling $HelmRepo/$Chart-$ChartVersion" && helm pull $HelmRepo/$Chart --version $ChartVersion 
else
    echo ""
    echo "pulling $HelmRepo/$Chart-$ChartVersion from $HelmEndpoint" && helm pull $HelmEndpoint --version $ChartVersion
fi
#make the directory
echo ""
echo ""
echo -e "\e[93mCreating directory and unpacking chart files\e[0m"
echo ""
mkdir -p ./$PackName-$ChartVersion/charts/ && cd $_
#place the tar file
mv $ExecDir/$Chart-$ChartVersion.tgz ./$PackName-$ChartVersion.tgz
#manually create the directory so the name is known
mkdir -p ./$PackName
#charts include a parent directory, strip that directory so it follows the known name
tar -xvf $PackName-$ChartVersion.tgz -C ./$PackName --strip-components=1
echo ""

#extract images to Images variable
echo -e "\e[93m Attempting to extract image references in chart to values file\e[0m"
echo ""
#create an empty list
declare -a ImageList=()
#get list of images from chart with grep, trim leading whitespace, replace with appropriate spacing and add a "-" for yaml list 
ImageList=$(helm template $HelmRepo/$Chart --dry-run=client --skip-schema-validation --debug | grep 'image:' | sed -e 's/.*[ \t]*image:/image:/' | awk '{print "      - " $0}' || true)

#determine if helm images were able to be extracted
if [ -n "$ImageList" ]; then
    echo ""
    echo -e "\e[32m  Image list extracted\e[0m"
    echo "$ImageList"
    echo ""
else
    echo ""
    echo -e "\e[31mImage list could not be extracted\e[0m"
    echo "   continuing with pack creation, images may need to be manually put into pack for edge use"
    echo ""
fi
################################################################################
# Pack.json contents template                                                  #
################################################################################
content=$(cat <<EOF
{
    "addonType": "$AddonType",
    "annotations": {
      "source": "community",
      "contributor" : "spectrocloud"
    },    
    "cloudTypes": [
      "all"
    ],
    "displayName": "$PackName",
    "charts": [
      "charts/$PackName-$ChartVersion.tgz"
    ],
    "layer":"$PackType",
    "name": "$PackName",
    "version": "$ChartVersion"
  }
EOF
)
################################################################################
# values.yaml header template                                                  #
################################################################################
header=$(cat << EOF
pack:
  spectrocloud.com/display-name: $PackName
  releaseNameOverride:
      $PackName: $Release
  namespace: $PackNamespace
  content:
    images:
$ImageList

charts:
  $PackName:

EOF
)
################################################################################


echo -e "\e[93m Creating values.yaml with template header and copying values from chart\e[0m"
echo ""
#use the template above to put the chart header together
echo "$header" > $ExecDir/$PackName-$ChartVersion/values.yaml
#copy out the values.yaml from the chart and append to the file
awk '{print "    " $0}' $PackName/values.yaml >> $ExecDir/$PackName-$ChartVersion/values.yaml
#copy out the README from the chart if it exists, otherwise create a blank one
if [ -f "$PackName/README.md" ]; then 
   echo -e "\e[93m Copying readme to pack path\e[0m" && cp $PackName/README.md $ExecDir/$PackName-$ChartVersion
else 
   echo -e "\e[93m Readme not found in chart\e[0m"
   echo -e "   Creating blank readme" && touch $ExecDir/$PackName-$ChartVersion/README.md
   echo ""
fi
#create the pack.json from the template provided
echo -e "\e[93m Creating pack.json metadata file\e[0m"
echo ""
echo "$content" > $ExecDir/$PackName-$ChartVersion/pack.json

echo -e "\e[93m Testing for logo.png file location\e[0m"
if test -f $ExecDir/logo.png; then
    mv $ExecDir/logo.png $ExecDir/$PackName-$ChartVersion/logo.png && echo "  Moved logo file to pack directory"
else
    echo "  Logo file present in pack directory"
fi

echo ""
echo ""
echo -e "\e[32mPack" "\e[1m$PackName-$ChartVersion\e[0m \e[32mready to edit and push\e[0m"
