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
