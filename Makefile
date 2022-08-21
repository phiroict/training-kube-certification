SHELL := /bin/bash
.EXPORT_ALL_VARIABLES:
version=20220810.1
istio_version=1.14.3
istio_version_arm=1.14.3
nginx_ingress_controller_version=1.3.0
concourse_version=7.8.2
PHIRO_AKS_PUB_KEY=$(shell cat /Users/phiro/.ssh/id_rsa.pub)

# Archlinux setup
init_archlinux:
	sudo pacman -S istio kubectl make rustup minikube docker jmeter-qt socat wireshark-qt argocd k9s --needed
	yay -S docker-machine-driver-kvm2 libvirt qemu-headless ebtables google-cloud-sdk --needed
	sudo systemctl enable libvirtd.service
	sudo systemctl start libvirtd.service
	sudo usermod -a -G libvirt $(whoami)
	minikube config set driver kvm2
init_ansible:
	sudo pacman -S ansible --needed
	ansible-playbook --ask-become-pass -c local infra/ansible/dev-machine/playbook.yaml
# Kubernetes calls  --------------------------------------------------------------------------------------------------------------
create_user:
	bash ./create_certificate.sh "phiroict"
create_readonly_role_sa:
	kubectl apply -f set-role-for-serviceaccount.yaml
create_sa_token_dashboard_admin:
	kubectl apply -f sa_token_generation.yaml

## Deployment -------------------------------------------------------------------------------------------------------------------- 
### Create namespaces first as we need to associate istio with it
init_namespaces:
	kubectl apply -f stack/namespace_init/namespaces.yaml
### Deployments	
deploy_dev:
	cd stack/kustomize && kubectl apply -k overlays/dev
deploy_test:
	cd stack/kustomize && kubectl apply -k overlays/test
deploy_uat:
	cd stack/kustomize && kubectl apply -k overlays/uat
deploy_prod:
	cd stack/kustomize && kubectl apply -k overlays/prod
### Undeployments
undeploy_dev:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_test:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_uat:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_prod:
	cd stack/kustomize && kubectl delete -k overlays/dev


# App builders -------------------------------------------------------------------------------------------------------------------
## Initialize (run only once in a while)
app_init:
	rustup override set nightly
	cargo install cargo-release
	rustup component add clippy
	rustup component add rustfmt
## Dev build
app_build_gateway:
	cd apps/gateway && cargo build 
app_build_datasource:
	cd apps/datasource && cargo build 
app_build_all: app_build_gateway app_build_datasource
app_run_all:
	cd apps/gateway && nohup cargo run&
	cd apps/datasource && nohup cargo run&

## Release build
app_build_gateway_release:
	cd apps/gateway && cargo build --release
app_build_datasource_release:
	cd apps/datasource && cargo build --release
app_build_all_release: app_build_gateway_release app_build_datasource_release

## Container build
app_container_gateway:
	docker build --build-arg path=apps --build-arg app_name=gateway -t phiroict/training_k8s_rust_gateway:$(version) -f infra/docker/Dockerfile  .
	docker push phiroict/training_k8s_rust_gateway:$(version)
app_container_datasource:
	docker build --build-arg path=apps --build-arg app_name=datasource -t phiroict/training_k8s_rust_datasource:$(version) -f infra/docker/Dockerfile  .
	docker push phiroict/training_k8s_rust_datasource:$(version)
app_container_build_all: app_container_gateway app_container_datasource
docker_compose_run:
	cd infra/docker && docker-compose up -d
docker_compose_stop:
	cd infra/docker && docker-compose down

# Minikube ----------------------------------------------------------------------------------------------------------------------------------------------------------
## Minikube start commands with several drivers
minikube_podman:
	minikube config set rootless true
	minikube start --driver podman --container-runtime containerd  --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress
minikube_docker:
	minikube start --driver docker  --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress
minikube_virtualbox:
	minikube start --driver virtualbox --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress
minikube_kvm2:
	minikube start --driver kvm2 --nodes 1 --cpus 14 --memory 32000M --disk-size 50gb
	minikube addons enable ingress
minikube_delete:
	minikube delete

minikube_set_hosts:
	cd infra/ansible/hosts && ansible-playbook -c local --ask-become-pass --extra-vars "ip_address=$(shell minikube ip)" playbook.yaml
# Service mesh ----------------------------------------------------------------------------------------------------------------------------------------------------------
istio_init:
	istioctl install --set profile=demo -y
istio_init_arm:
	istioctl install --set profile=demo -y --set components.cni.enabled=true
istio_inject:
	kubectl label namespace dev-applications istio-injection=enabled --overwrite
	kubectl label namespace test-applications istio-injection=enabled --overwrite
	kubectl label namespace uat-applications istio-injection=enabled --overwrite
	kubectl label namespace prod-applications istio-injection=enabled --overwrite
istio_extras:
	rm -rf istio-$(istio_version)
	wget https://storage.googleapis.com/istio-release/releases/$(istio_version)/istio-$(istio_version)-linux-amd64.tar.gz
	tar xfv istio-$(istio_version)-linux-amd64.tar.gz
	kubectl apply -f istio-$(istio_version)/samples/addons/
	rm -f istio-$(istio_version)-linux-amd64.tar.gz
	# sudo cp -pf istio-$(istio_version)/bin/istioctl  /usr/bin/istioctl
	# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(nginx_ingress_controller_version)/deploy/static/provider/cloud/deploy.yaml
istio_extras_arm:
	wget https://github.com/istio/istio/releases/download/$(istio_version_arm)/istio-$(istio_version_arm)-osx-arm64.tar.gz
	tar xfv istio-$(istio_version_arm)-osx-arm64.tar.gz
	kubectl apply -f istio-$(istio_version_arm)/samples/addons/
	rm -f istio-$(istio_version_arm)-osx-arm64.tar.gz
istio_kiali_dashboard:
	nohup istioctl dashboard kiali &

# Dashboards -----------------------------------------------------------------------------------------------------------
minikube_dashboard:
	nohup minikube dashboard&
kiali_dashboard:
	nohup istioctl dashboard kiali&
	nohup istioctl dashboard grafana&
	nohup istioctl dashboard jaeger&
argocd_dashboard:
	-nohup sh -c "kubectl port-forward svc/argocd-server -n argocd 8082:443"&  < /dev/null > /dev/null 2>&1 \n
	nohup firefox http://localhost:8082&
concourse_web:
	-nohup sh -c "kubectl port-forward svc/concourse-web-service -n concourse-main 32080:8080"& < /dev/null > /dev/null 2>&1 \n
	nohup firefox http://concourse.info:32080 &
concourse_pipeline_deploy:
	fly --target main login --concourse-url http://concourse.info:32080/ --username phiro --password password
	cd ci/concourse/pipelines/apps && cat build-microservice-gateway-dev.yaml | fly -t main set-pipeline --pipeline ms-build-gateway --config -

# CI -------------------------------------------------------------------------------------------------------------------
concourse_init:
	rm -f concourse-*-linux-amd64.tgz*
	wget https://github.com/concourse/concourse/releases/download/v$(concourse_version)/concourse-$(concourse_version)-linux-amd64.tgz
	tar -xzvf concourse-$(concourse_version)-linux-amd64.tgz
	kubectl apply -f ci/concourse/infra/concourse-namespace.yaml
	mkdir -p ci/concourse/secrets
	sudo cp -p concourse/bin/concourse /usr/bin/concourse
	cd concourse/fly-assets && tar -xzvf fly-linux-amd64.tgz
	sudo cp -p concourse/fly-assets/fly /usr/bin/fly
concourse_keygen:	
	kubectl apply -f ci/concourse/infra/concourse-namespace.yaml
	cd concourse/bin && ./concourse generate-key -t rsa -f ../../ci/concourse/secrets/session_signing_key
	cd concourse/bin && ./concourse generate-key -t ssh -f ../../ci/concourse/secrets/tsa_host_key
	cd concourse/bin && ./concourse generate-key -t ssh -f ../../ci/concourse/secrets/worker_key
	-kubectl delete secret -n concourse-main session-signing
	-kubectl delete secret -n concourse-main tsa-host-private
	-kubectl delete secret -n concourse-main tsa-host-public
	-kubectl delete secret -n concourse-main worker-private
	-kubectl delete secret -n concourse-main worker-public
	kubectl create secret generic session-signing -n concourse-main --from-file=ci/concourse/secrets/session_signing_key
	kubectl create secret generic tsa-host-private -n concourse-main  --from-file=ci/concourse/secrets/tsa_host_key
	kubectl create secret generic tsa-host-public -n concourse-main  --from-file=ci/concourse/secrets/tsa_host_key.pub
	kubectl create secret generic worker-private -n concourse-main  --from-file=ci/concourse/secrets/worker_key
	kubectl create secret generic worker-public  -n concourse-main  --from-file=ci/concourse/secrets/worker_key.pub
	rm -f ci/concourse/secrets/session_signing_key ci/concourse/secrets/tsa_host_key ci/concourse/secrets/worker_key
concourse_create:
	cd ci/concourse/infra && kubectl apply -k .
	-bash ./read_secrets_into_k8s_cluster.sh
concourse_delete:
	cd ci/concourse/infra && kubectl delete -k .
concourse_install: concourse_keygen concourse_create
concourse_all: concourse_init concourse_keygen concourse_create
concourse_secrets:
	source ci/concourse/secrets/git.creds && kubectl create secret generic registry-username -n concourse-main --from-literal=registry-username=$(USERNAME) && kubectl create secret generic registry-password -n concourse-main --from-literal=registry-password=$(PASSWORD)
concourse_forward:
	-nohup sh -c "kubectl port-forward svc/concourse-web-service -n concourse-main 32080:8080"&  < /dev/null > /dev/null 2>&1 \n

## Manual CI deploys
concourse_login:
	fly --target main login --concourse-url http://concourse.info:32080/
concourse_pipeline_deploy_dev:
	cd ci/concourse/pipelines/apps && cat build-microservice-gateway-dev.yaml | fly -t main set-pipeline --pipeline ms-build-gateway-dev --config -
concourse_pipeline_deploy_test:
	cd ci/concourse/pipelines/apps && cat build-microservice-gateway-test.yaml | fly -t main set-pipeline --pipeline ms-build-gateway-test --config -
concourse_pipeline_deploy_uat:
	cd ci/concourse/pipelines/apps && cat build-microservice-gateway-uat.yaml | fly -t main set-pipeline --pipeline ms-build-gateway-uat --config -
concourse_pipeline_deploy_prod:
	cd ci/concourse/pipelines/apps && cat build-microservice-gateway-prod.yaml | fly -t main set-pipeline --pipeline ms-build-gateway-prod --config -

# CD -------------------------------------------------------------------------------------------------------------------
argocd_install:
	kubectl create ns argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	-nohup sh -c "kubectl port-forward svc/argocd-server -n argocd 8082:443"& < /dev/null > /dev/null 2>&1 \n
argocd_get_initial_password:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	echo ""
argocd_provision:
	argocd login localhost:8082 --insecure --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
	kubectl config get-contexts -o name
	argocd cluster add --insecure minikube
	argocd app create dev-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/dev --dest-server https://$(shell minikube ip):8443 --dest-namespace  dev-applications --sync-policy auto
	argocd app create test-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/test --dest-server https://$(shell minikube ip):8443 --dest-namespace  test-applications --sync-policy none
	argocd app create uat-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/uat --dest-server https://$(shell minikube ip):8443 --dest-namespace  uat-applications  --sync-policy none
	argocd app create prod-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/prod --dest-server https://$(shell minikube ip):8443 --dest-namespace   prod-applications --sync-policy none
argocd_provision_azure:
	argocd login localhost:8082 --insecure --username admin --password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
	kubectl config get-contexts -o name
	argocd cluster add PhiRo-Training-Cluster --yes
	argocd app create dev-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/dev --dest-server $(shell argocd cluster get PhiRo-Training-Cluster -o json | jq -r '.server') --dest-namespace  dev-applications --sync-policy auto
	#argocd app create test-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/test --dest-server $(shell argocd cluster get PhiRo-Training-Cluster -o json | jq -r '.server') --dest-namespace  test-applications --sync-policy none
	#argocd app create uat-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/uat --dest-server $(shell argocd cluster get PhiRo-Training-Cluster -o json | jq -r '.server') --dest-namespace  uat-applications  --sync-policy none
	#argocd app create prod-applications --repo https://github.com/phiroict/training-kube-certification.git --path stack/kustomize/overlays/prod --dest-server $(shell argocd cluster get PhiRo-Training-Cluster -o json | jq -r '.server') --dest-namespace   prod-applications --sync-policy none

sleep:
	sleep 30
sleep_long:
	sleep 120
# ############################################################################################################################################################################################################################################
# Main runners  ----------------------------------------------------------------------------------------------------------------------------------------------------------
# ######################################################################################################################
# Minikube ##############
provision_minikube: minikube_kvm2 istio_init init_namespaces istio_inject istio_extras deploy_dev concourse_install minikube_set_hosts argocd_install sleep argocd_provision minikube_dashboard concourse_web istio_kiali_dashboard argocd_dashboard
provision_mac_arm_minikube: istio_init_arm init_namespaces istio_inject istio_extras_arm deploy_dev minikube_set_hosts minikube_dashboard concourse_web istio_kiali_dashboard
# Azure ##############
provision_cloud_aks: az_cdk_deploy az_cdk_get_credentials istio_init init_namespaces istio_inject istio_extras deploy_dev concourse_install argocd_install
provision_cloud_aks_continuation:  argocd_provision_azure concourse_web istio_kiali_dashboard argocd_dashboard
az_provision: provision_cloud_aks sleep_long provision_cloud_aks_continuation

# AWS ##############
provision_cloud_aws: aws_build

# Google ###########

# ## END ###########
# REBUILD ALL ################################################################################################################################################################################################################################
bounce_minikube: minikube_delete provision_minikube
# ############################################################################################################################################################################################################################################

# ############################################################################################################################################################################################################################################
# Cloud
# ############################################################################################################################################################################################################################################

# ###############
# Azure
# ###############
az_login:
	az login
az_cdk_init:
	npm install -g cdktf-cli
	mkdir -p stack/cloud/azure && cd stack/cloud/azure && cdktf init --template="typescript" --local
az_cdk_get:
	cd stack/cloud/azure && cdktf get
az_cdk_deploy:
	cd stack/cloud/azure && cdktf synth && cdktf deploy --auto-approve
az_cdk_get_credentials:
	# Assumes the names are set un the CDK scripts, change these when different, todo is to pass these as a parameter to the script.
	# Interactive login, get the credentials from the portal -> MTFContainerRegistry->[Access Keys]
	# docker login phiroicttrainingdemo.azurecr.io
	# Get the certificates and install these in the `.kube/config`
	az aks get-credentials --overwrite-existing --resource-group training_k8s_rs --name PhiRo-Training-Cluster
az_cdk_destroy:
	cd stack/cloud/azure && cdktf destroy --auto-approve

# ###############
# Google
# ###############
create_project:
	gcloud projects create demo1234 --folder 1234 --name demo --project demo-0001 --enable-cloud-apis --set-as-default
# ###############
# AWS
# ###############
aws_init:
	-cd stack/cloud/aws && rm -rf .gen node_modules package-lock.json
	cd stack/cloud/aws && npm install
	cd stack/cloud/aws && npm install @cdktf/provider-aws

	cd stack/cloud/aws && cdktf provider add "aws@4.27.0"
	cd stack/cloud/aws && cdktf provider add "kubernetes@2.12.1"
aws_bootstrap:
	cd stack/cloud/aws/bootstrap && aws-vault exec home -- terraform init && aws-vault exec home -- terraform plan -out state.plan && aws-vault exec home -- terraform apply -auto-approve state.plan
aws_get:
	cd stack/cloud/aws && cdktf get
aws_synth:
	cd stack/cloud/aws && aws-vault exec home --region ap-southeast-2 -- cdktf synth aws_instance
aws_build:
	cd stack/cloud/aws && aws-vault exec home --no-session -- cdktf deploy aws_instance --auto-approve
aws_destroy:
	cd stack/cloud/aws && aws-vault exec home --region ap-southeast-2 --no-session -- cdktf destroy --auto-approve
aws_eks_kubectl_config:
	aws-vault exec home -- aws eks update-kubeconfig --region ap-southeast-2 --name $(shell aws-vault exec home -- aws eks list-clusters | jq -r '.clusters[0]')
aws_wa_init:
	cd stack/cloud/aws/cdktf.out/stacks/aws_instance && aws-vault exec home -- terraform init
aws_wa_plan:
	cd stack/cloud/aws/cdktf.out/stacks/aws_instance && aws-vault exec home --no-session -- terraform plan -out plan.plan
aws_wa_apply:
	cd stack/cloud/aws/cdktf.out/stacks/aws_instance && aws-vault exec home --no-session -- terraform apply plan.plan
aws_wa_destroy:
	cd stack/cloud/aws/cdktf.out/stacks/aws_instance && aws-vault exec home --no-session -- terraform destroy -auto-apprive

