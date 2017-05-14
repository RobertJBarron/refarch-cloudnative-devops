# Checking if bx is installed
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'
coffee=$'\xE2\x98\x95'
coffee3="${coffee} ${coffee} ${coffee}"

BLUEMIX_API_ENDPOINT="api.ng.bluemix.net"
CLUSTER_NAME=$1
SPACE=$2
API_KEY=$3

REGISTRY_NAMESPACE=""

function check_pvc {
    if [ -z "$1" ]; 
	then
			echo "No parameter passed to function check_pvc"
			exit 1 
	fi
	kubectl get pvc $1-home | grep Bound
}

function check_tiller {
	kubectl --namespace=kube-system get pods | grep tiller | grep Runnin
}

function bluemix_login {
	# Bluemix Login
	printf "${grn}Login into Bluemix${end}\n"
	if [[ -z "${API_KEY// }" && -z "${SPACE// }" ]]; then
		echo "${yel}API Key & SPACE NOT provided.${end}"
		bx login -a ${BLUEMIX_API_ENDPOINT}

	elif [[ -z "${SPACE// }" ]]; then
		echo "${yel}API Key provided but SPACE was NOT provided.${end}"
		export BLUEMIX_API_KEY=${API_KEY}
		bx login -a ${BLUEMIX_API_ENDPOINT}

	elif [[ -z "${API_KEY// }" ]]; then
		echo "${yel}API Key NOT provided but SPACE was provided.${end}"
		bx login -s ${SPACE} --sso -c 98010327e775907f2d1bf637b10d2625

	else
		echo "${yel}API Key and SPACE provided.${end}"
		export BLUEMIX_API_KEY=${API_KEY}
		bx login -a ${BLUEMIX_API_ENDPOINT} -s ${SPACE}
	fi

	status=$?

	if [ $status -ne 0 ]; then
		printf "\n\n${red}Bluemix Login Error... Exiting.${end}\n"
		exit 1
	fi
}

function get_cluster_name {
	printf "\n\n${grn}Login into Container Service${end}\n\n"
	bx cs init

	if [[ -z "${CLUSTER_NAME// }" ]]; then
		echo "${yel}No cluster name provided. Will try to get an existing cluster...${end}"
		CLUSTER_NAME=$(bx cs clusters | tail -1 | awk '{print $1}')
echo "XXXX $CLUSTER_NAME"
		if [[ "$CLUSTER_NAME" == "Name" ]]; then
			echo "No Kubernetes Clusters exist in your account. Please provision one and then run this script again."
			exit 1
		fi
	fi
}

function set_cluster_context {
	# Getting Cluster Configuration
	unset KUBECONFIG
	printf "\n${grn}Setting terminal context to \"${CLUSTER_NAME}\"...${end}\n"
	eval "$(bx cs cluster-config ${CLUSTER_NAME} | tail -1)"
	echo "KUBECONFIG is set to = $KUBECONFIG"

	if [[ -z "${KUBECONFIG// }" ]]; then
		echo "KUBECONFIG was not properly set. Exiting"
		exit 1
	fi
}

function initialize_helm {
	printf "\n\n${grn}Initializing Helm.${end}\n"
	helm init --upgrade
	echo "Waiting for Tiller (Helm's server component) to be ready..."

	TILLER_DEPLOYED=$(check_tiller)
	while [[ "${TILLER_DEPLOYED}" == "" ]]; do 
		sleep 1
		TILLER_DEPLOYED=$(check_tiller)
	done
}

function create_pvc {
	# Create PVC if it does not exist
	if [ -z "$1" ]; 
	then
			echo "No PVC name passed to function create_pvc"
			exit 1 
	fi
	printf "\n\n${grn}Checking if PVC $1 already exists...${end}\n"
	PVC_BOUND=$(check_pvc $1)

	if [[ "${PVC_BOUND}" == "" ]]; then
		printf "\n\n${grn}Creating Persistent Volume Claim (PVC) For $1. This will take a few minutes...${end}\n"
		kubectl create -f storage_$1.yaml
		echo "${yel}Waiting for PVC to be fully bound to cluster...${end} ${coffee3}"

		PVC_BOUND=$(check_pvc $1)

		# Polling Status
		while [ -z "${PVC_BOUND// }" ]; do
			sleep 1
			PVC_BOUND=$(check_pvc)
		done
		echo "Done!"
	else
		echo "PVC already exists!"
	fi
}

function install_chart {
	# Install  Chart
	if [ -z "$1" ]; 
	then
			echo "${red}No chart name passed to function install_chart${end}"
			exit 1 
	fi
	if [ -z "$2" ]; 
	then
			echo "${red}No chart location passed to function install_chart${end}"
			exit 1 
	fi

	if [ -n "$3" ]; 
	then
			EXTRA_SET_1="--set $3"
	fi
	if [ -n "$4" ]; 
	then
			EXTRA_SET_2="--set $4" 
	fi
	
	CHART_EXISTS=$(kubectl get services | grep $1)

	if [[ "${CHART_EXISTS}" == "" ]]; then
		printf "\n\n${grn}Installing $1 Chart...${end} ${coffee3}\n"
		#PVC_NAME=$(yaml read storage_$1.yaml metadata.name)
		#echo helm install --name $1 --set Persistence.ExistingClaim=${PVC_NAME} --set server.image.tag=latest $EXTRA_SET_1 $EXTRA_SET_2 $2 --wait
		#helm install --name $1 --set Persistence.ExistingClaim=${PVC_NAME} --set server.image.tag=latest $EXTRA_SET_1 $EXTRA_SET_2  $2 --wait &>> helm_install_$1.log
		echo helm install --name $1 $EXTRA_SET_1 $EXTRA_SET_2 $2 
		helm      install --name $1 $EXTRA_SET_1 $EXTRA_SET_2 $2 &>> helm_install_$1.log
		echo "${grn}Success!${end}"
	else
		printf "\n\n${grn}$1 is already installed! Not installing chart.${end}\n"
	fi
}
function create_config_map {
	printf "\n\n${grn}Creating CI/CD Config Map...${end}\n"
	ORG=$(cat ~/.bluemix/.cf/config.json | jq .OrganizationFields.Name | sed 's/"//g')
	SPACE=$(cat ~/.bluemix/.cf/config.json | jq .SpaceFields.Name | sed 's/"//g')

	# Installing Config Map
	# Replace Bluemix Org
	string_to_replace=$(yaml read config.yaml data.bluemix-org)
	sed -i.bak s%${string_to_replace}%${ORG}%g config.yaml

	# Replace Bluemix Space
	string_to_replace=$(yaml read config.yaml data.bluemix-space)
	sed -i.bak s%${string_to_replace}%${SPACE}%g config.yaml

	string_to_replace=$(yaml read config.yaml data.bluemix-registry-namespace)
	sed -i.bak s%${string_to_replace}%${REGISTRY_NAMESPACE}%g config.yaml

	# Replace Kubernetes Cluster Name
	string_to_replace=$(yaml read config.yaml data.kube-cluster-name)
	sed -i.bak s%${string_to_replace}%${CLUSTER_NAME}%g config.yaml

	config=$(kubectl get configmaps | grep bluemix-target | awk '{print $1}' | head -1)

	if [[ -z "${config// }" ]]; then
	    echo "Creating configmap"
		kubectl create -f config.yaml
	else
	    echo "Updating configmap"
		kubectl apply -f config.yaml
	fi
}

function create_secret {
	# Replace API Key
	printf "\n\n${grn}Creating API KEY Secret...${end}\n"
	# Creating for API KEY
	if [[ -z "${API_KEY// }" ]]; then
		printf "${grn}Creating API KEY...${end}\n"
		API_KEY=$(bx iam api-key-create kubekey | tail -1 | awk '{print $3}')
		echo "${yel}API key 'kubekey' was created.${end}"
		echo "${mag}Please preserve the API key! It cannot be retrieved after it's created.${end}"
		echo "${cyn}Name${end}	kubekey"
		echo "${cyn}API Key${end}	${API_KEY}"
	fi

	string_to_replace=$(yaml read secret.yaml data.api-key)
	sed -i.bak s%${string_to_replace}%$(echo $API_KEY | base64)%g secret.yaml

	secret=$(kubectl get secrets | grep bluemix-api-key | awk '{print $1}' | head -1)

	if [[ -z "${secret// }" ]]; then
	    echo "Creating secret"
		kubectl create -f secret.yaml
	else
	    echo "Updating secret"
		kubectl apply -f secret.yaml
	fi
}

# Setup Stuff
bluemix_login
#create_registry_namespace
get_cluster_name
set_cluster_context
initialize_helm

# Create CICD Configuration
#create_config_map
#create_secret

# Create Jenkins Resources
create_pvc prometheus
create_pvc alertmanager
create_pvc grafana
install_chart prometheus stable/prometheus server.persistentVolume.existingClaim=prometheus-home alertmanager.persistentVolume.existingClaim=alertmanager-home
#install_chart  grafana https://github.com/RobertJBarron/charts/raw/master/stable/grafana/grafana-bc-0.3.1.tgz setDatasource.datasource.url=http://prometheus-prometheus-server.default.svc.cluster.local server.persistentVolume.existingClaim=grafana-home
install_chart grafana ./grafana-bc                                                                           setDatasource.datasource.url=http://prometheus-prometheus-server.default.svc.cluster.local server.persistentVolume.existingClaim=grafana-home
  
# Completion Messages
printf "\n\nTo see Kubernetes Dashboard, paste the following in your terminal:\n"
echo "${cyn}export KUBECONFIG=${KUBECONFIG}${end}"

#printf "\nThen run this command to connect to Kubernetes Dashboard:\n"
#echo "${cyn}kubectl proxy${end}"

#printf "\n$To see Jenkins service and its web URL, open a browser window and enter the following URL:\n"
#echo "${cyn}http://127.0.0.1:8001/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard/#/service/default/jenkins-jenkins?namespace=default${end}"

#printf "\nNote that it may take a few minutes for the LoadBalancer IP to be available. You can watch the status of it by running:\n"
#echo "${cyn}kubectl get svc --namespace default -w jenkins-jenkins${end}"
printf "\n$To find the Grafana URL run the following command:\n"
printf "echo export SERVICE_IP=$(kubectl get svc --namespace default grafana-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')\n"
printf "export SERVICE_IP=$(kubectl get svc --namespace default grafana-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')\n"
printf "echo http://\$SERVICE_IP:80\n"

printf "\nFinally, run the following command to get the password for \"admin\" user:\n"
printf "${cyn}printf \$(kubectl get secret --namespace default grafana-grafana -o jsonpath=\"{.data.grafana-admin-password}\" | base64 --decode);echo${end}\n"

